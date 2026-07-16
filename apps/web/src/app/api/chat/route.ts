// POST /api/chat — 多 Agent 对话（SSE 流式输出）
//
// 流式错误处理策略：
// - 已知请求错误（JSON 解析失败、消息过长等）在建立流之前返回 4xx；
// - 若 orchestrateStream 在产出首个事件前抛出异常，则返回 HTTP 500；
// - 若流已建立（首个事件已产出）后才出错，HTTP 状态已固化为 200，
//   此时通过 SSE 错误事件通知客户端，并记录日志。

import { NextRequest } from "next/server";
import { orchestrateStream } from "@/lib/agents/orchestrator";
import { sanitizeUserId } from "@/lib/utils";
import type { ChatMessage, ChatRequest, StreamEvent } from "@/lib/types";
import { getModelRuntimeInfo } from "@/lib/agents/model";
import { validateUserInput } from "@/lib/agents/safety-agent";
import { modelErrorResponse } from "@/lib/api-errors";
import { isJsonObject, readJsonObject } from "@/lib/request-json";
import { readDateKey, sanitizeLearningProfile, validationError } from "@/lib/api-validation";
import { isCourseId } from "@/lib/data";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 120;

export async function POST(req: NextRequest) {
  const parsed = await readJsonObject<Record<string, unknown>>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  if (body.message === undefined) {
    return Response.json({ error: "缺少 message 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (typeof body.message !== "string") {
    return Response.json({ error: "message 必须是字符串", code: "INVALID_MESSAGE" }, { status: 400 });
  }

  const message = body.message.trim();
  if (message.length === 0) {
    return Response.json({ error: "message 不能为空", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (message.length > 2000) {
    return Response.json({ error: "消息过长（上限 2000 字符）", code: "MESSAGE_TOO_LONG" }, { status: 400 });
  }

  const inputFlags = validateUserInput(message);
  if (inputFlags.length > 0) {
    return Response.json(
      { error: "输入内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  const userId = sanitizeUserId(body.userId);
  const startDate = readDateKey(
    body.startDate,
    new Date().toISOString().slice(0, 10),
    "INVALID_START_DATE",
    "startDate"
  );
  if (!startDate.ok) return startDate.response;
  const profile = sanitizeLearningProfile(body.profile);
  if (!profile.ok) return profile.response;
  const profileSafetyFlags = profile.value ? validateUserInput(profileSafetyText(profile.value)) : [];
  if (profileSafetyFlags.length > 0) {
    return Response.json(
      { error: "画像内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  const context = sanitizeContext(body.context);
  if (!context.ok) return context.response;

  const history = sanitizeHistory(body.history);
  if (!history.ok) return history.response;
  const historySafetyFlags = validateUserInput(
    (history.value ?? []).map((item) => item.content).join("\n")
  );
  if (historySafetyFlags.length > 0) {
    return Response.json(
      { error: "历史消息不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  if (!getModelRuntimeInfo().configured) {
    return Response.json(
      { error: "云端学伴暂不可用，请稍后重试", code: "MODEL_UNAVAILABLE" },
      { status: 503 }
    );
  }

  const chatRequest: ChatRequest = {
    userId,
    message,
    startDate: startDate.value,
    profile: profile.value,
    context: context.value,
    history: history.value,
  };

  const encoder = new TextEncoder();
  const sse = (event: StreamEvent) =>
    encoder.encode(`data: ${JSON.stringify(event)}\n\n`);
  const abortController = new AbortController();

  // 在建立 SSE 流之前，先探测编排是否能够正常产出首个事件：
  // - 首个事件到来：建立 200 流并回放已缓冲事件，后续事件实时推送；
  // - 首个事件前出错：直接返回 HTTP 500，避免错误请求被负载均衡器/监控误报为 200。
  const buffered: Uint8Array[] = [];
  let controllerRef: ReadableStreamDefaultController<Uint8Array> | null = null;
  let primed = false;
  let orchestrateError: unknown = null;

  // definite assignment：在 new Promise 构造器内同步赋值
  let resolveFirst!: (chunk: Uint8Array) => void;
  let rejectFirst!: (err: unknown) => void;
  const firstChunkPromise = new Promise<Uint8Array>((resolve, reject) => {
    resolveFirst = resolve;
    rejectFirst = reject;
  });

  const emit = (event: StreamEvent) => {
    if (orchestrateError) return;
    const chunk = sse(event);
    if (!primed) {
      // 首个事件：解除对响应的等待，随后由流回放
      primed = true;
      resolveFirst(chunk);
    } else if (controllerRef) {
      controllerRef.enqueue(chunk);
    } else {
      // 首个事件已产出但流尚未就绪，先缓冲
      buffered.push(chunk);
    }
  };

  // 后台启动编排（不阻塞当前函数；错误在 catch 中捕获并触发 500 或流中错误事件）
  const orchestratePromise = (async () => {
    try {
      await orchestrateStream(chatRequest, emit, abortController.signal);
    } catch (err) {
      orchestrateError = err;
      if (!primed) {
        // 流尚未建立即出错：触发 500 分支
        rejectFirst(err);
      }
    }
  })();

  // 等待首个事件，或在首个事件前出错
  let firstChunk: Uint8Array;
  try {
    firstChunk = await firstChunkPromise;
  } catch {
    // 编排在产出任何事件前失败 → 返回 HTTP 500
    console.error(
      "[chat] orchestrate error (pre-stream):",
      orchestrateError instanceof Error ? orchestrateError.message : String(orchestrateError)
    );
    return modelErrorResponse(orchestrateError);
  }

  // 首个事件已就绪，建立 SSE 流（HTTP 200）
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      controllerRef = controller;
      try {
        // 先回放首个事件
        controller.enqueue(firstChunk);
        // 回放在建立流之前缓冲的事件（与首个事件保持顺序）
        for (const chunk of buffered) {
          controller.enqueue(chunk);
        }
        buffered.length = 0;

        // 等待编排完成，期间 emit 会直接写入 controller
        await orchestratePromise;

        if (orchestrateError) {
          // 流中错误：HTTP 状态已固化为 200，通过 SSE 事件通知客户端
          const errDetail = orchestrateError instanceof Error
            ? orchestrateError.message
            : String(orchestrateError);
          const errCode = streamErrorCode(orchestrateError);
          // 对用户展示安全摘要，完整错误仅入日志
          const userMessage = errCode === "MODEL_UNAVAILABLE"
            ? "云端学伴暂不可用，请稍后重试"
            : errCode === "MODEL_TIMEOUT"
              ? "模型请求超时，请稍后重试"
            : errCode === "MODEL_INVALID_RESPONSE"
              ? "模型返回内容无效，请重新生成"
              : errCode === "KNOWLEDGE_UNAVAILABLE"
                ? "当前主题缺少课程资料，请换一个主题重试"
              : "服务处理异常，请稍后重试";
          controller.enqueue(
            sse({ type: "error", code: errCode, message: userMessage })
          );
          controller.enqueue(sse({ type: "done", sessionId: "error" }));
          console.error(
            "[chat] orchestrate error (mid-stream):",
            errDetail
          );
        }
      } catch (err) {
        // 流被取消或写入失败：记录日志，不向客户端泄露细节
        console.error("[chat] stream write error:", err instanceof Error ? err.message : String(err));
      } finally {
        controllerRef = null;
        try {
          controller.close();
        } catch {
          /* 控制器已关闭/取消，忽略 */
        }
      }
    },
    cancel() {
      // 客户端断开连接：停止向 controller 写入，避免在已取消的流上抛错
      abortController.abort();
      controllerRef = null;
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}

function profileSafetyText(profile: NonNullable<ChatRequest["profile"]>): string {
  return [
    profile.stage,
    profile.learningStyle,
    ...profile.weakTopics,
    ...profile.strongTopics,
  ].join("\n");
}

function sanitizeContext(value: unknown): ReturnType<typeof validationError> | {
  ok: true;
  value: ChatRequest["context"];
} {
  if (value === undefined) return { ok: true, value: undefined };
  if (!isJsonObject(value)) {
    return validationError("context 必须是对象", "INVALID_CONTEXT");
  }

  let courseId: string | undefined;
  if (value.courseId !== undefined) {
    if (typeof value.courseId !== "string" || !isCourseId(value.courseId)) {
      return validationError("context.courseId 不受支持", "INVALID_COURSE");
    }
    courseId = value.courseId;
  }

  let sessionId: string | undefined;
  if (value.sessionId !== undefined) {
    if (typeof value.sessionId !== "string") {
      return validationError("context.sessionId 必须是字符串", "INVALID_CONTEXT");
    }
    const trimmed = value.sessionId.trim().slice(0, 100);
    sessionId = trimmed.length > 0 ? trimmed : undefined;
  }

  return { ok: true, value: { courseId, sessionId } };
}

function sanitizeHistory(value: unknown): ReturnType<typeof validationError> | {
  ok: true;
  value: ChatMessage[] | undefined;
} {
  if (value === undefined) return { ok: true, value: undefined };
  if (!Array.isArray(value) || !value.every(isJsonObject)) {
    return validationError("history 必须是消息对象数组", "INVALID_HISTORY");
  }
  const messages: ChatMessage[] = [];
  for (const item of value) {
    if (item.role !== "user" && item.role !== "assistant") {
      return validationError("history.role 仅支持 user 或 assistant", "INVALID_HISTORY");
    }
    if (typeof item.content !== "string") {
      return validationError("history.content 必须是字符串", "INVALID_HISTORY");
    }
    if (item.content.trim().length > 0) {
      messages.push({
        role: item.role,
        content: item.content.slice(0, 1000),
      });
    }
  }
  return { ok: true, value: messages.slice(-12) };
}

function streamErrorCode(error: unknown): string {
  if (
    error !== null &&
    typeof error === "object" &&
    "code" in error &&
    typeof (error as { code?: unknown }).code === "string"
  ) {
    return (error as { code: string }).code;
  }
  if (error instanceof Error && error.message.startsWith("MODEL_INVALID_RESPONSE:")) {
    return "MODEL_INVALID_RESPONSE";
  }
  if (error instanceof Error && error.message.startsWith("KNOWLEDGE_UNAVAILABLE:")) {
    return "KNOWLEDGE_UNAVAILABLE";
  }
  return "INTERNAL_ERROR";
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
