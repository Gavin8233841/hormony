// GET /api/quiz?userId=... — 获取测验历史
// GET /api/quiz?courseId=... — 获取课程题库
// POST /api/quiz — 生成测验

import { runQuizAgent } from "@/lib/agents/quiz-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { Quiz, QuizCatalogItem, QuizView } from "@/lib/types";
import { getQuizzesByCourse as getSeedQuizzesByCourse } from "@/lib/data";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const courseId = searchParams.get("courseId");

    // 按课程获取题库
    if (courseId) {
      const quizzes = getSeedQuizzesByCourse(courseId);
      const catalog: QuizCatalogItem[] = quizzes.map((quiz) => ({
        quizId: quiz.quizId,
        courseId: quiz.courseId,
        topic: quiz.topic,
        questionCount: quiz.questions.length,
      }));
      return Response.json({ quizzes: catalog });
    }

    // 默认返回用户的测验结果
    const userId = sanitizeUserId(searchParams.get("userId"));
    const results = store.getQuizResults(userId);
    return Response.json({ results });
  } catch (err) {
    console.error("[quiz/GET] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "获取测验数据失败", code: "INTERNAL_ERROR" }, { status: 500 });
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
    return Response.json(toQuizView(quiz));
  } catch (err) {
    console.error("[quiz] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "生成测验失败，请稍后重试", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

function toQuizView(quiz: Quiz): QuizView {
  return {
    quizId: quiz.quizId,
    courseId: quiz.courseId,
    topic: quiz.topic,
    questions: quiz.questions.map((question) => ({
      id: question.id,
      type: question.type,
      stem: question.stem,
      options: question.options,
    })),
  };
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
