// POST /api/chat — 多 Agent 对话（SSE 流式输出）

import { NextRequest } from "next/server";
import { orchestrateStream } from "@/lib/agents/orchestrator";
import type { ChatRequest, StreamEvent } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

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
  if (message.length > 2000) {
    return Response.json({ error: "消息过长（上限 2000 字符）", code: "MESSAGE_TOO_LONG" }, { status: 400 });
  }

  const userId = body.userId ?? "demo";

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const emit = (event: StreamEvent) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
      };
      try {
        await orchestrateStream({ ...body, userId }, emit);
      } catch (err) {
        emit({
          type: "trace",
          agent: "Safety",
          content: "服务处理异常，请稍后重试",
        });
        emit({ type: "done", sessionId: "error" });
        // 内部错误仅记录日志，不向客户端泄露细节
        console.error("[chat] orchestrate error:", err instanceof Error ? err.message : String(err));
      } finally {
        controller.close();
      }
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

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
