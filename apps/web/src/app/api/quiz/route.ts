// GET /api/quiz?userId=... — 获取测验历史
// GET /api/quiz?courseId=... — 获取课程题库
// POST /api/quiz — 生成测验

import { runQuizAgent } from "@/lib/agents/quiz-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { Quiz, QuizCatalogItem } from "@/lib/types";
import { getQuizzesByCourse as getSeedQuizzesByCourse } from "@/lib/data";
import { getModelRuntimeInfo, ModelUnavailableError } from "@/lib/agents/model";
import { modelErrorResponse } from "@/lib/api-errors";
import type { QuizPackage } from "@/lib/types";
import { validateUserInput } from "@/lib/agents/safety-agent";

export const dynamic = "force-dynamic";
export const maxDuration = 120;

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

    if (process.env.DEPLOYMENT_MODE === "stateless") {
      return Response.json(
        { error: "答题结果仅保存在 HarmonyOS 设备", code: "ENDPOINT_DISABLED" },
        { status: 404 }
      );
    }

    // 本地开发模式可返回进程内测验结果
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

  if (!["cs101", "cs102", "cs103"].includes(courseId)) {
    return Response.json({ error: "不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
  }
  if (topic.length === 0 || topic.length > 100) {
    return Response.json({ error: "主题长度必须为 1-100 字符", code: "INVALID_TOPIC" }, { status: 400 });
  }
  if (!(["easy", "medium", "hard"] as const).includes(difficulty)) {
    return Response.json({ error: "不支持的难度", code: "INVALID_DIFFICULTY" }, { status: 400 });
  }
  if (validateUserInput(topic).length > 0) {
    return Response.json(
      { error: "主题内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  if (!getModelRuntimeInfo().configured) {
    return modelErrorResponse(new ModelUnavailableError());
  }

  try {
    const quiz = await runQuizAgent(userId, courseId, topic, count, difficulty);
    return Response.json(toQuizPackage(quiz));
  } catch (err) {
    console.error("[quiz] error:", err instanceof Error ? err.message : String(err));
    return modelErrorResponse(err);
  }
}

function toQuizPackage(quiz: Quiz): QuizPackage {
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
    grading: quiz.questions.map((question) => ({
      questionId: question.id,
      answer: question.answer,
      explanation: question.explanation,
    })),
  };
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
