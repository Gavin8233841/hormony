// POST /api/safety-review — 内容安全审核

import { runSafetyAgent } from "@/lib/agents/safety-agent";
import type { Citation } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  let body: { content?: string; userId?: string; citations?: Citation[] };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const content = String(body.content ?? "").trim();
  if (!content) {
    return Response.json({ error: "缺少 content 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (content.length > 10000) {
    return Response.json({ error: "内容过长（上限 10000 字符）", code: "CONTENT_TOO_LONG" }, { status: 400 });
  }

  try {
    const result = await runSafetyAgent(content, body.citations ?? []);
    return Response.json(result);
  } catch (err) {
    console.error("[safety-review] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "安全审核服务异常", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
