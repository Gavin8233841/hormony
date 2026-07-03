// Quiz Agent：测验题生成
// 仅使用真实模型动态生成。精选题库通过独立 GET 接口提供，不冒充 AI。

import {
  callModel,
  extractJsonPayload,
  KnowledgeUnavailableError,
  ModelInvalidResponseError,
} from "./model";
import { generateId } from "@/lib/utils";
import { formatContext, retrieve } from "@/lib/rag";
import type { Quiz, QuizQuestion } from "@/lib/types";

export async function runQuizAgent(
  userId: string,
  courseId: string,
  topic: string,
  count: number,
  difficulty: "easy" | "medium" | "hard",
  focusTag?: string,
  signal?: AbortSignal
): Promise<Quiz> {
  const courseContext = formatContext(retrieve(topic, courseId, 5));
  if (!courseContext) {
    throw new KnowledgeUnavailableError();
  }

  const systemPrompt = `你是一位出题专家。根据指定主题生成选择题。
输出 JSON 数组，每个元素：{"type":"choice","stem":"","options":["A. ","B. ","C. ","D. "],"answer":"A","explanation":"","tags":["概念理解","边界条件"]}
题干、答案和解析必须与提供的课程资料一致，禁止引入资料外的事实。
难度规则：
- easy：考查定义、术语、直接性质或一步识别，适合刚学完概念的学生。
- medium：给出简短场景或对比，需要应用概念完成一步推理。
- hard：必须包含边界条件、运行过程、故障诊断或多步判断，不能只问定义。
tags 必须是 1-3 个中文短标签，用于学习画像量化，优先使用知识点、能力类型或错误类型，例如：概念理解、代码推演、复杂度分析、边界条件、协议状态、调度策略。
如果提供重点标签，每道题的 tags 必须包含该重点标签，并围绕它设计考查点。
每题必须有 4 个选项，答案只能是 A、B、C、D，解析 50-90 字说明正确理由。
只输出 JSON，不要 Markdown 代码块，不要输出额外说明。`;

  const userPrompt = `课程ID：${courseId}
主题：${topic}
难度：${difficulty}
数量：${count}
重点标签：${focusTag && focusTag.length > 0 ? focusTag : "无"}
课程资料：
${courseContext}`;

  const raw = await callModel(systemPrompt, userPrompt, {
    temperature: 0.5,
    maxTokens: 2048,
    signal,
  });
  const questions = parseQuestions(raw, count, topic, difficulty, focusTag);
  if (questions.length !== count) {
    throw new ModelInvalidResponseError("题目数量或结构不符合要求");
  }

  const quiz: Quiz = {
    quizId: generateId("quiz"),
    courseId,
    topic,
    focusTag: focusTag && focusTag.length > 0 ? focusTag : undefined,
    questions,
  };
  return quiz;
}

function parseQuestions(
  raw: string,
  count: number,
  topic: string,
  difficulty: "easy" | "medium" | "hard",
  focusTag?: string
): QuizQuestion[] {
  try {
    const payload: unknown = JSON.parse(extractJsonPayload(raw));
    const arr = readQuestionArray(payload);
    if (arr.length > 0) {
      const parsed: QuizQuestion[] = [];
      for (const item of arr) {
        if (parsed.length >= count) break;
        if (!item || typeof item !== "object") continue;
        const q = item as Record<string, unknown>;
        const stem = typeof q.stem === "string" ? q.stem.trim() : "";
        const options = normalizeOptions(q.options);
        const answer = normalizeAnswer(q.answer, options);
        const explanation =
          typeof q.explanation === "string" ? q.explanation.trim() : "";
        const tags = parseTags(q.tags, topic, focusTag);
        const validOptions = options.length === 4 && options.every((option, index) =>
          option.toUpperCase().startsWith(`${String.fromCharCode(65 + index)}.`)
        );
        if (!stem || !validOptions || !/^[A-D]$/i.test(answer) || !explanation) continue;
        parsed.push({
          id: generateId("q"),
          type: "choice",
          stem,
          options,
          answer,
          explanation,
          difficulty,
          tags,
        });
      }
      return parsed;
    }
  } catch {
    return [];
  }
  return [];
}

function readQuestionArray(payload: unknown): unknown[] {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];
  const value = payload as Record<string, unknown>;
  return Array.isArray(value.questions) ? value.questions : [];
}

function normalizeOptions(value: unknown): string[] {
  if (!Array.isArray(value) || value.length !== 4) return [];
  const normalized: string[] = [];
  for (let index = 0; index < value.length; index += 1) {
    const option = normalizeOption(value[index], index);
    if (!option) return [];
    normalized.push(option);
  }
  return normalized;
}

function normalizeOption(value: unknown, index: number): string {
  if (typeof value !== "string") return "";
  const label = String.fromCharCode(65 + index);
  const match = new RegExp(`^${label}[\\s.。．、:：)）-]+(.+)$`, "i").exec(value.trim());
  if (!match) return "";
  const text = match[1].trim();
  return text.length > 0 ? `${label}. ${text}` : "";
}

function normalizeAnswer(value: unknown, options: string[]): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim().toUpperCase();
  if (/^[A-D]$/.test(trimmed)) return trimmed;
  const match = /^([A-D])[\s.。．、:：]/.exec(trimmed);
  if (match) return match[1];

  for (let index = 0; index < options.length; index += 1) {
    const optionText = options[index].slice(3).trim().toUpperCase();
    if (optionText.length > 0 && trimmed === optionText) {
      return String.fromCharCode(65 + index);
    }
  }
  return "";
}

function parseTags(value: unknown, topic: string, focusTag?: string): string[] {
  const source = Array.isArray(value) ? value : [];
  const tags = source
    .map(String)
    .map((tag) => tag.trim())
    .filter((tag) => tag.length > 0 && tag.length <= 12)
    .filter((tag, index, values) => values.indexOf(tag) === index)
    .slice(0, 3);
  const normalizedFocusTag = typeof focusTag === "string" ? focusTag.trim() : "";
  if (normalizedFocusTag.length > 0 && normalizedFocusTag.length <= 12 && !tags.includes(normalizedFocusTag)) {
    tags.unshift(normalizedFocusTag);
  }
  const normalizedTags = tags.slice(0, 3);
  return normalizedTags.length > 0 ? normalizedTags : [topic.slice(0, 12)];
}
