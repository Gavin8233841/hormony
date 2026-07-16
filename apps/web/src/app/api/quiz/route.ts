// GET /api/quiz?userId=... — 获取测验历史
// GET /api/quiz?courseId=... — 获取课程题库
// POST /api/quiz — 生成测验

import { runQuizAgent } from "@/lib/agents/quiz-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { Quiz, QuizCatalogItem } from "@/lib/types";
import {
  getQuizzesByCourse as getSeedQuizzesByCourse,
  isCourseId,
  isCourseTopic,
} from "@/lib/data";
import { getModelRuntimeInfo, ModelUnavailableError } from "@/lib/agents/model";
import { modelErrorResponse, SafetyBlockedError } from "@/lib/api-errors";
import type { QuizPackage } from "@/lib/types";
import { runSafetyAgent, validateUserInput } from "@/lib/agents/safety-agent";
import { readJsonObject } from "@/lib/request-json";
import { readBoundedInteger } from "@/lib/api-validation";

export const dynamic = "force-dynamic";
export const maxDuration = 120;

type QuizDifficulty = "easy" | "medium" | "hard";
const QUIZ_DIFFICULTIES: QuizDifficulty[] = ["easy", "medium", "hard"];

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const courseId = searchParams.get("courseId");

    // 按课程获取题库
    if (courseId) {
      if (!isCourseId(courseId)) {
        return Response.json({ error: "不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
      }
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
  const parsed = await readJsonObject<Record<string, unknown>>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);
  const courseId = body.courseId ?? "cs101";
  if (typeof courseId !== "string" || !isCourseId(courseId)) {
    return Response.json({ error: "不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
  }
  if (typeof body.topic !== "string") {
    return Response.json({ error: "主题必须是字符串", code: "INVALID_TOPIC" }, { status: 400 });
  }
  const topic = body.topic.trim();
  const count = readBoundedInteger(body.count, 5, 1, 20, "INVALID_COUNT", "count");
  if (!count.ok) return count.response;
  const difficulty = body.difficulty ?? "medium";
  if (typeof difficulty !== "string") {
    return Response.json({ error: "不支持的难度", code: "INVALID_DIFFICULTY" }, { status: 400 });
  }
  if (body.focusTag !== undefined && typeof body.focusTag !== "string") {
    return Response.json({ error: "重点标签必须是字符串", code: "INVALID_FOCUS_TAG" }, { status: 400 });
  }
  const focusTag = typeof body.focusTag === "string" ? body.focusTag.trim() : "";

  if (topic.length === 0 || topic.length > 100) {
    return Response.json({ error: "主题长度必须为 1-100 字符", code: "INVALID_TOPIC" }, { status: 400 });
  }
  if (!isCourseTopic(courseId, topic)) {
    return Response.json({ error: "主题不属于所选课程", code: "INVALID_TOPIC" }, { status: 400 });
  }
  if (focusTag.length > 12) {
    return Response.json({ error: "重点标签长度必须为 1-12 字符", code: "INVALID_FOCUS_TAG" }, { status: 400 });
  }
  if (!isQuizDifficulty(difficulty)) {
    return Response.json({ error: "不支持的难度", code: "INVALID_DIFFICULTY" }, { status: 400 });
  }
  if (validateUserInput(topic).length > 0) {
    return Response.json(
      { error: "主题内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }
  if (focusTag.length > 0 && validateUserInput(focusTag).length > 0) {
    return Response.json(
      { error: "重点标签内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  if (!getModelRuntimeInfo().configured) {
    return modelErrorResponse(new ModelUnavailableError());
  }

  try {
    const quiz = await runQuizAgent(
      userId,
      courseId,
      topic,
      count.value,
      difficulty,
      focusTag.length > 0 ? focusTag : undefined
    );
    await assertSafeQuiz(quiz);
    store.saveQuiz(quiz);
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
    focusTag: quiz.focusTag,
    questions: quiz.questions.map((question) => ({
      id: question.id,
      type: question.type,
      stem: question.stem,
      options: question.options,
      difficulty: question.difficulty,
      tags: questionTags(question.tags, quiz.topic),
    })),
    grading: quiz.questions.map((question) => ({
      questionId: question.id,
      answer: question.answer,
      explanation: question.explanation,
      difficulty: question.difficulty,
      tags: questionTags(question.tags, quiz.topic),
    })),
  };
}

function questionTags(tags: string[] | undefined, topic: string): string[] {
  return tags && tags.length > 0 ? tags : [topic.slice(0, 12)];
}

function isQuizDifficulty(value: string): value is QuizDifficulty {
  return QUIZ_DIFFICULTIES.some((difficulty) => difficulty === value);
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}

async function assertSafeQuiz(quiz: Quiz): Promise<void> {
  const outputText = [
    quiz.focusTag ?? "",
    ...quiz.questions.flatMap((question) => [
      question.stem,
      ...(question.options ?? []),
      question.explanation,
      ...(question.tags ?? []),
    ]),
  ].join("\n");
  const safety = await runSafetyAgent(outputText, []);
  if (!safety.passed) {
    throw new SafetyBlockedError();
  }
}
