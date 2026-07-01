// POST /api/safety-review — 内容安全审核

import { runSafetyAgent } from "@/lib/agents/safety-agent";
import type { Citation } from "@/lib/types";
import { isJsonObject, readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  const parsed = await readJsonObject<{
    content?: string;
    userId?: string;
    citations?: Citation[];
  }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const content = String(body.content ?? "").trim();
  if (!content) {
    return Response.json({ error: "缺少 content 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (content.length > 10000) {
    return Response.json({ error: "内容过长（上限 10000 字符）", code: "CONTENT_TOO_LONG" }, { status: 400 });
  }
  if (
    body.citations !== undefined &&
    (!Array.isArray(body.citations) || !body.citations.every(isJsonObject))
  ) {
    return Response.json(
      { error: "citations 必须是引用对象数组", code: "INVALID_CITATIONS" },
      { status: 400 }
    );
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
