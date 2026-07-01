// POST /api/knowledge/search - RAG knowledge retrieval

import { retrieve } from "@/lib/rag";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import { readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";

interface KnowledgeSearchRequest {
  userId?: string;
  query?: string;
  courseId?: string;
  topK?: number;
}

export async function POST(req: Request) {
  const parsed = await readJsonObject<KnowledgeSearchRequest>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const query = body.query?.trim();
  if (!query) {
    return Response.json({ error: "缺少 query 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  if (query.length > 500) {
    return Response.json({ error: "查询过长（上限 500 字符）", code: "QUERY_TOO_LONG" }, { status: 400 });
  }

  const topK = Math.min(Math.max(body.topK ?? 5, 1), 20);

  try {
    const chunks = retrieve(query, body.courseId, topK);
    const userId = sanitizeUserId(body.userId);
    store.logActivity({
      userId,
      type: "study",
      description: `检索知识：${query.slice(0, 40)}`,
      timestamp: new Date().toISOString(),
    });
    return Response.json({ chunks });
  } catch (err) {
    console.error("[knowledge/search] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "检索失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
