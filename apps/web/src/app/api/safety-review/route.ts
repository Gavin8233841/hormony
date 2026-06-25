// POST /api/safety-review — 内容安全审核

import { runSafetyAgent } from "@/lib/agents/safety-agent";
import type { Citation } from "@/lib/types";

export async function POST(req: Request) {
  let body: { content?: string; userId?: string; citations?: Citation[] };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  if (!body.content) {
    return Response.json({ error: "缺少 content 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  const result = await runSafetyAgent(body.content, body.citations ?? []);
  return Response.json(result);
}
