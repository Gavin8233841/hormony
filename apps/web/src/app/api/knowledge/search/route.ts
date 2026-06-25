// POST /api/knowledge/search - RAG knowledge retrieval

import { retrieve } from "@/lib/rag";

interface KnowledgeSearchRequest {
  query?: string;
  courseId?: string;
  topK?: number;
}

export async function POST(req: Request) {
  let body: KnowledgeSearchRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const query = body.query?.trim();
  if (!query) {
    return Response.json({ error: "缺少 query 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  const topK = Math.min(Math.max(body.topK ?? 5, 1), 20);
  const chunks = retrieve(query, body.courseId, topK);

  return Response.json({ chunks });
}
