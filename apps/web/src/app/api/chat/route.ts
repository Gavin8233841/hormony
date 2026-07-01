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
import type { ChatRequest, StreamEvent } from "@/lib/types";
import { getModelRuntimeInfo } from "@/lib/agents/model";
import { validateUserInput } from "@/lib/agents/safety-agent";
import type { LearningProfileSnapshot } from "@/lib/types";
import { modelErrorResponse } from "@/lib/api-errors";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 120;

export async function POST(req: NextRequest) {
  let body: ChatRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON 请求体", code: "BAD_REQUEST" }, { status: 400 });
  }

  if (!body.message) {
    return Response.json({ error: "缺少 message 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  const message = String(body.message).trim();
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
  body.profile = sanitizeProfile(body.profile);
  if (body.context) {
    const courseId = String(body.context.courseId ?? "");
    body.context.courseId = ["cs101", "cs102", "cs103"].includes(courseId)
      ? courseId
      : undefined;
    body.context.sessionId = String(body.context.sessionId ?? "").slice(0, 100) || undefined;
  }

  if (!getModelRuntimeInfo().configured) {
    return Response.json(
      { error: "云端学伴暂不可用，请稍后重试", code: "MODEL_UNAVAILABLE" },
      { status: 503 }
    );
  }

  // 限制对话历史大小（最多 12 条消息，每条最多 1000 字符，仅允许 user/assistant 角色）
  if (body.history && Array.isArray(body.history)) {
    body.history = body.history
      .filter((m) => m.role === "user" || m.role === "assistant")
      .slice(-12)
      .map((m) => ({
        role: m.role,
        content: String(m.content ?? "").slice(0, 1000),
      }));
  }

  const encoder = new TextEncoder();
  const sse = (event: StreamEvent) =>
    encoder.encode(`data: ${JSON.stringify(event)}\n\n`);

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
      await orchestrateStream({ ...body, userId }, emit);
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
          const errCode = (orchestrateError as { code?: string })?.code ?? "INTERNAL_ERROR";
          // 对用户展示安全摘要，完整错误仅入日志
          const userMessage = errCode === "MODEL_UNAVAILABLE"
            ? "云端学伴暂不可用，请稍后重试"
            : errCode === "MODEL_INVALID_RESPONSE"
              ? "模型返回内容无效，请重新生成"
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

function sanitizeProfile(profile?: LearningProfileSnapshot): LearningProfileSnapshot | undefined {
  if (!profile) return undefined;
  return {
    stage: String(profile.stage ?? "").slice(0, 40),
    weakTopics: Array.isArray(profile.weakTopics)
      ? profile.weakTopics.slice(0, 10).map((item) => String(item).slice(0, 40))
      : [],
    strongTopics: Array.isArray(profile.strongTopics)
      ? profile.strongTopics.slice(0, 10).map((item) => String(item).slice(0, 40))
      : [],
    learningStyle: String(profile.learningStyle ?? "").slice(0, 40),
    stats: {
      totalQuestions: Math.max(0, Number(profile.stats?.totalQuestions) || 0),
      accuracy: Math.min(Math.max(Number(profile.stats?.accuracy) || 0, 0), 1),
      studyDays: Math.max(0, Number(profile.stats?.studyDays) || 0),
    },
  };
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
