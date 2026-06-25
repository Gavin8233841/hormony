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
          content: `编排过程出错：${err instanceof Error ? err.message : String(err)}`,
        });
        emit({ type: "done", sessionId: "error" });
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
