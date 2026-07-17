// POST /api/knowledge/search - RAG knowledge retrieval

import { retrieve } from "@/lib/rag";
import { selectRetrievedChunks } from "@/lib/rag/course-boundary";
import { store } from "@/lib/store/db";
import { readJsonObject } from "@/lib/request-json";
import { isStatelessDeployment } from "@/lib/deployment";
import { readBoundedInteger, readUserId } from "@/lib/api-validation";
import { isCourseId } from "@/lib/data";
import { runSafetyAgent, validateUserInput } from "@/lib/agents/safety-agent";

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

  if (body.query === undefined) {
    return Response.json({ error: "缺少 query 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (typeof body.query !== "string") {
    return Response.json({ error: "query 必须是字符串", code: "INVALID_QUERY" }, { status: 400 });
  }
  const query = body.query.trim();
  if (!query) {
    return Response.json({ error: "缺少 query 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  if (query.length > 500) {
    return Response.json({ error: "查询过长（上限 500 字符）", code: "QUERY_TOO_LONG" }, { status: 400 });
  }

  if (
    body.courseId !== undefined &&
    (typeof body.courseId !== "string" || !isCourseId(body.courseId))
  ) {
    return Response.json({ error: "不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
  }
  const topK = readBoundedInteger(body.topK, 5, 1, 20, "INVALID_TOP_K", "topK");
  if (!topK.ok) return topK.response;
  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;
  if (validateUserInput(query).length > 0) {
    return Response.json(
      { error: "查询内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  try {
    const chunks = selectRetrievedChunks(
      retrieve(query, body.courseId, topK.value),
      body.courseId,
      topK.value
    );
    const outputSafety = await runSafetyAgent(
      chunks.map((chunk) => chunk.text).join("\n"),
      chunks.map((chunk) => ({
        doc: chunk.source,
        snippet: chunk.text,
      }))
    );
    if (!outputSafety.passed) {
      return Response.json(
        { error: "检索结果未通过安全审核", code: "SAFETY_BLOCKED" },
        { status: 502 }
      );
    }
    if (!isStatelessDeployment()) {
      store.logActivity({
        userId: userId.value,
        type: "study",
        description: `检索知识：${query.slice(0, 40)}`,
        timestamp: new Date().toISOString(),
      });
    }
    return Response.json({ chunks });
  } catch (err) {
    console.error("[knowledge/search] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "检索失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
