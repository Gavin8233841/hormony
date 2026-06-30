// Quiz Agent：测验题生成
// 优先使用 LLM 动态生成；LLM 不可用时回退到静态题库（70道题目，覆盖3门课程）

import { callModel, extractJsonPayload } from "./model";
import { generateId } from "@/lib/utils";
import { store } from "@/lib/store/db";
import { getQuizzesByCourse as getSeedQuizzesByCourse } from "@/lib/data";
import type { Quiz, QuizQuestion } from "@/lib/types";

export async function runQuizAgent(
  userId: string,
  courseId: string,
  topic: string,
  count: number,
  difficulty: "easy" | "medium" | "hard"
): Promise<Quiz> {
  const systemPrompt = `你是一位出题专家。根据指定主题生成选择题。
输出 JSON 数组，每个元素：{"type":"choice","stem":"","options":["A. ","B. ","C. ","D. "],"answer":"A","explanation":""}
只输出 JSON。`;

  const userPrompt = `课程ID：${courseId}
主题：${topic}
难度：${difficulty}
数量：${count}`;

  let questions: QuizQuestion[] = [];

  try {
    const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.5 });
    questions = parseQuestions(raw, count, topic);
  } catch {
    // LLM 不可用时，从静态题库取题
  }

  // LLM 题量不足时，用静态题库补齐，并避免重复题干。
  if (questions.length < count) {
    const existingStems = new Set(questions.map((question) => question.stem));
    const fallback = staticQuizBank(courseId, topic, count).filter(
      (question) => !existingStems.has(question.stem)
    );
    questions = [...questions, ...fallback].slice(0, count);
  }

  const quiz: Quiz = {
    quizId: generateId("quiz"),
    courseId,
    topic,
    questions,
  };
  store.saveQuiz(quiz);
  return quiz;
}

function parseQuestions(raw: string, count: number, topic: string): QuizQuestion[] {
  try {
    const arr = JSON.parse(extractJsonPayload(raw));
    if (Array.isArray(arr)) {
      const parsed: QuizQuestion[] = [];
      for (const item of arr.slice(0, count)) {
        if (!item || typeof item !== "object") continue;
        const q = item as Record<string, unknown>;
        const stem = typeof q.stem === "string" ? q.stem.trim() : "";
        const options = Array.isArray(q.options)
          ? q.options.map(String).map((option) => option.trim()).filter(Boolean)
          : [];
        const answer = typeof q.answer === "string" ? q.answer.trim() : "";
        const explanation =
          typeof q.explanation === "string" ? q.explanation.trim() : "";
        if (!stem || options.length < 2 || !answer || !explanation) continue;
        parsed.push({
          id: generateId("q"),
          type: "choice",
          stem,
          options,
          answer,
          explanation,
        });
      }
      return parsed;
    }
  } catch {
    // JSON 解析失败，返回空数组触发静态题库回退
  }
  return [];
}

// 从静态题库中按课程和主题取题
function staticQuizBank(courseId: string, topic: string, count: number): QuizQuestion[] {
  const quizzes = getSeedQuizzesByCourse(courseId);
  const normalizedTopic = topic.trim();
  const topicMatches = normalizedTopic && normalizedTopic !== "综合"
    ? quizzes.filter(
        (quiz) =>
          quiz.topic.includes(normalizedTopic) || normalizedTopic.includes(quiz.topic)
      )
    : [];
  const remaining = quizzes.filter((quiz) => !topicMatches.includes(quiz));
  const seenQuestionIds = new Set<string>();
  const pool = [...topicMatches, ...remaining]
    .flatMap((quiz) => quiz.questions)
    .filter((question) => question.type === "choice")
    .filter((question) => {
      if (seenQuestionIds.has(question.id)) return false;
      seenQuestionIds.add(question.id);
      return true;
    });

  return pool.slice(0, count).map((question) => ({
    ...question,
    id: generateId("q"),
  }));
}
