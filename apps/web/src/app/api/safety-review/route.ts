// POST /api/safety-review — 内容安全审核

import { runSafetyAgent } from "@/lib/agents/safety-agent";
import type { Citation } from "@/lib/types";
import { isJsonObject, readJsonObject } from "@/lib/request-json";
import { readUserId, validationError } from "@/lib/api-validation";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  const parsed = await readJsonObject<{
    content?: string;
    userId?: string;
    citations?: Citation[];
  }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  if (body.content === undefined) {
    return Response.json({ error: "缺少 content 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (typeof body.content !== "string") {
    return Response.json({ error: "content 必须是字符串", code: "INVALID_CONTENT" }, { status: 400 });
  }
  const content = body.content.trim();
  if (!content) {
    return Response.json({ error: "缺少 content 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (content.length > 10000) {
    return Response.json({ error: "内容过长（上限 10000 字符）", code: "CONTENT_TOO_LONG" }, { status: 400 });
  }
  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;
  const citations = readCitations(body.citations);
  if (!citations.ok) return citations.response;

  try {
    const result = await runSafetyAgent(content, citations.value);
    return Response.json(result);
  } catch (err) {
    console.error("[safety-review] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "安全审核服务异常", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}

function readCitations(value: unknown): ReturnType<typeof validationError> | {
  ok: true;
  value: Citation[];
} {
  if (value === undefined) return { ok: true, value: [] };
  if (!Array.isArray(value) || !value.every(isJsonObject)) {
    return validationError("citations 必须是引用对象数组", "INVALID_CITATIONS");
  }
  if (value.length > 20) {
    return validationError("citations 最多包含 20 项", "INVALID_CITATIONS");
  }

  const citations: Citation[] = [];
  for (const item of value) {
    if (typeof item.doc !== "string") {
      return validationError("citation.doc 必须是字符串", "INVALID_CITATIONS");
    }
    const doc = item.doc.trim();
    if (doc.length < 1 || doc.length > 200) {
      return validationError(
        "citation.doc 长度必须为 1-200 字符",
        "INVALID_CITATIONS"
      );
    }
    if (
      item.page !== undefined &&
      (
        typeof item.page !== "number" ||
        !Number.isInteger(item.page) ||
        item.page < 0
      )
    ) {
      return validationError("citation.page 必须是非负整数", "INVALID_CITATIONS");
    }
    if (item.snippet !== undefined && typeof item.snippet !== "string") {
      return validationError("citation.snippet 必须是字符串", "INVALID_CITATIONS");
    }
    const snippet = item.snippet?.trim();
    if (snippet && snippet.length > 1000) {
      return validationError(
        "citation.snippet 长度不能超过 1000 字符",
        "INVALID_CITATIONS"
      );
    }

    citations.push({
      doc,
      page: item.page,
      snippet: snippet || undefined,
    });
  }
  return { ok: true, value: citations };
}
