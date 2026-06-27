// POST /api/quiz — 生成测验题

// GET /api/quiz?userId=... — 获取测验历史
// POST /api/quiz — 生成测验

import { runQuizAgent } from "@/lib/agents/quiz-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = sanitizeUserId(searchParams.get("userId"));
    const results = store.getQuizResults(userId);
    return Response.json({ results });
  } catch (err) {
    console.error("[quiz/GET] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "获取测验历史失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  let body: {
    userId?: string;
    courseId?: string;
    topic?: string;
    count?: number;
    difficulty?: "easy" | "medium" | "hard";
  };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = sanitizeUserId(body.userId);
  const courseId = body.courseId ?? "cs101";
  const topic = String(body.topic ?? "综合").trim();
  const count = Math.min(Math.max(Number(body.count) || 5, 1), 20);
  const difficulty = body.difficulty ?? "medium";

  try {
    const quiz = await runQuizAgent(userId, courseId, topic, count, difficulty);
    return Response.json(quiz);
  } catch (err) {
    console.error("[quiz] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "生成测验失败，请稍后重试", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
