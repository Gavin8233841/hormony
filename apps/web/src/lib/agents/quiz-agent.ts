// Quiz Agent：测验题生成
// 仅使用真实模型动态生成。精选题库通过独立 GET 接口提供，不冒充 AI。

import { callModel, extractJsonPayload } from "./model";
import { generateId } from "@/lib/utils";
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

  const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.5, maxTokens: 1500 });
  const questions = parseQuestions(raw, count);
  if (questions.length !== count) {
    throw new Error("MODEL_INVALID_RESPONSE: 题目数量或结构不符合要求");
  }

  const quiz: Quiz = {
    quizId: generateId("quiz"),
    courseId,
    topic,
    questions,
  };
  return quiz;
}

function parseQuestions(raw: string, count: number): QuizQuestion[] {
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
    return [];
  }
  return [];
}
