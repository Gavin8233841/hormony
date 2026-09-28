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
import { store } from "@/lib/store/db";
import type { Quiz, QuizQuestion } from "@/lib/types";

const MAX_QUESTIONS_PER_MODEL_BATCH = 5;
const MAX_RAW_OUTPUT_FOR_REPAIR = 3600;
const MAX_QUESTION_STEM_LENGTH = 500;
const MAX_QUESTION_OPTION_LENGTH = 200;
const MAX_QUESTION_EXPLANATION_LENGTH = 1000;
const MAX_QUESTION_TAGS = 3;
const MAX_QUESTION_TAG_LENGTH = 12;

export async function runQuizAgent(
  userId: string,
  courseId: string,
  topic: string,
  count: number,
  difficulty: "easy" | "medium" | "hard",
  focusTag?: string,
  signal?: AbortSignal
): Promise<Quiz> {
  // The dedicated Quiz API passes an exact topic; Chat may pass a free-form
  // request. Scope exact topics to their own lesson and retain Chat retrieval.
  const topicChunks = store.getKnowledge(courseId).filter((chunk) => chunk.topic === topic);
  const courseContext = formatContext(
    topicChunks.length > 0 ? topicChunks : retrieve(topic, courseId, 5)
  );
  if (!courseContext) {
    throw new KnowledgeUnavailableError();
  }

  const questions = await generateQuizQuestions({
    courseId,
    topic,
    count,
    difficulty,
    focusTag,
    courseContext,
    signal,
  });
  if (questions.length !== count) {
    throw new ModelInvalidResponseError("题目数量或结构不符合要求");
  }

  const quizId = generateId("quiz");
  const quiz: Quiz = {
    quizId,
    courseId,
    topic,
    focusTag: focusTag && focusTag.length > 0 ? focusTag : undefined,
    questions: balanceGeneratedChoiceOptions(questions, quizId),
  };
  return quiz;
}

// Models can copy the answer position from the JSON example. Rotate complete
// A-D option sets after validation, keeping the correct option body unchanged.
function balanceGeneratedChoiceOptions(questions: QuizQuestion[], quizId: string): QuizQuestion[] {
  return questions.map((question, index) => {
    const correctIndex = question.answer.charCodeAt(0) - 65;
    if (question.type !== "choice" || question.options?.length !== 4 ||
        correctIndex < 0 || correctIndex > 3) return question;
    const block = Math.floor(index / 4);
    const position = index % 4;
    const targets = shuffledPositions(`${quizId}:${block}`);
    const targetIndex = targets[position];
    const shift = (targetIndex - correctIndex + 4) % 4;
    const bodies = question.options.map((option) => option.slice(3));
    return {
      ...question,
      options: bodies.map((_, optionIndex) =>
        `${String.fromCharCode(65 + optionIndex)}. ${bodies[(optionIndex - shift + 4) % 4].trimStart()}`
      ),
      answer: String.fromCharCode(65 + targetIndex),
    };
  });
}

function shuffledPositions(seed: string): number[] {
  let hash = 2166136261;
  for (const char of seed) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  const positions = [0, 1, 2, 3];
  for (let index = positions.length - 1; index > 0; index -= 1) {
    hash = (Math.imul(hash, 1664525) + 1013904223) >>> 0;
    const other = hash % (index + 1);
    [positions[index], positions[other]] = [positions[other], positions[index]];
  }
  return positions;
}

interface GenerateQuizQuestionsInput {
  courseId: string;
  topic: string;
  count: number;
  difficulty: "easy" | "medium" | "hard";
  focusTag?: string;
  courseContext: string;
  signal?: AbortSignal;
}

async function generateQuizQuestions(input: GenerateQuizQuestionsInput): Promise<QuizQuestion[]> {
  const questions: QuizQuestion[] = [];
  const usedStems = new Set<string>();
  while (questions.length < input.count) {
    const remaining = input.count - questions.length;
    const batchSize = Math.min(remaining, MAX_QUESTIONS_PER_MODEL_BATCH);
    const raw = await callModel(
      quizSystemPrompt(),
      quizUserPrompt(input, batchSize, questions),
      {
        temperature: 0.5,
        maxTokens: 2048,
        signal: input.signal,
      }
    );
    let batch = parseQuestions(
      raw,
      batchSize,
      batchSize,
      input.difficulty,
      input.focusTag,
      usedStems
    );
    if (batch.length < batchSize) {
      const repairedRaw = await repairQuizJson(raw, batchSize, input, questions);
      batch = parseQuestions(
        repairedRaw,
        batchSize,
        batchSize,
        input.difficulty,
        input.focusTag,
        usedStems
      );
    }
    if (batch.length !== batchSize) {
      throw new ModelInvalidResponseError("题目批次数量或结构不符合要求");
    }
    const beforeCount = questions.length;
    for (const question of batch) {
      if (questions.length >= input.count) break;
      const normalizedStem = normalizeStem(question.stem);
      if (usedStems.has(normalizedStem)) continue;
      usedStems.add(normalizedStem);
      questions.push(question);
    }
    if (questions.length === beforeCount) break;
  }
  return questions;
}

function quizSystemPrompt(): string {
  const systemPrompt = `你是一位出题专家。根据指定主题生成选择题。
输出 JSON 数组，每个元素：{"type":"choice","stem":"","options":["A. ","B. ","C. ","D. "],"answer":"A","explanation":"","tags":["概念理解","边界条件"]}
题干、答案和解析必须与提供的课程资料一致，禁止引入资料外的事实。
所有题目只考查指定主题；不要借用同一课程中其他主题的知识点。每题必须只有一个明确正确选项，写清影响答案的实现方式和前提条件。
难度规则：
- easy：考查定义、术语、直接性质或一步识别，适合刚学完概念的学生。
- medium：给出简短场景或对比，需要应用概念完成一步推理。
- hard：必须包含边界条件、运行过程、故障诊断或多步判断，不能只问定义。
题干不超过 ${MAX_QUESTION_STEM_LENGTH} 字符，每个带标号选项不超过 ${MAX_QUESTION_OPTION_LENGTH} 字符。
tags 必须是 1-${MAX_QUESTION_TAGS} 个不超过 ${MAX_QUESTION_TAG_LENGTH} 字符的中文短标签，用于学习画像量化，优先使用知识点、能力类型或错误类型，例如：概念理解、代码推演、复杂度分析、边界条件、协议状态、调度策略。
如果提供重点标签，每道题的 tags 必须包含该重点标签，并围绕它设计考查点。
每题必须有 4 个选项，答案只能是 A、B、C、D，解析 50-90 字说明正确理由。
只输出 JSON，不要 Markdown 代码块，不要输出额外说明。`;
  return systemPrompt;
}

function quizUserPrompt(
  input: GenerateQuizQuestionsInput,
  batchSize: number,
  existingQuestions: QuizQuestion[]
): string {
  const existingStems = existingQuestions.length > 0
    ? existingQuestions.map((question, index) => `${index + 1}. ${question.stem}`).join("\n")
    : "无";
  const userPrompt = `课程ID：${input.courseId}
主题：${input.topic}
难度：${input.difficulty}
本批数量：${batchSize}
总题量：${input.count}
重点标签：${input.focusTag && input.focusTag.length > 0 ? input.focusTag : "无"}
已生成题干，禁止重复：
${existingStems}
课程资料：
${input.courseContext}`;
  return userPrompt;
}

async function repairQuizJson(
  raw: string,
  batchSize: number,
  input: GenerateQuizQuestionsInput,
  existingQuestions: QuizQuestion[]
): Promise<string> {
  const repairPrompt = `请把下面的模型输出修复成严格 JSON 数组。
要求：
- 只保留与课程资料一致的选择题，不要新增资料外事实。
- 输出 ${batchSize} 道题；如果原输出中没有足够题目，也只能基于同一课程资料补齐。
- 每题必须包含 stem、options、answer、explanation、tags。
- options 必须是 A-D 四个选项，answer 只能是 A、B、C、D。
- 如果有重点标签，每题 tags 必须包含重点标签。
- 只输出 JSON，不要 Markdown，不要额外说明。

课程ID：${input.courseId}
主题：${input.topic}
难度：${input.difficulty}
重点标签：${input.focusTag && input.focusTag.length > 0 ? input.focusTag : "无"}
已生成题干，禁止重复：
${existingQuestions.length > 0 ? existingQuestions.map((question, index) => `${index + 1}. ${question.stem}`).join("\n") : "无"}
课程资料：
${input.courseContext}

待修复输出：
${raw.slice(0, MAX_RAW_OUTPUT_FOR_REPAIR)}`;

  return callModel(quizSystemPrompt(), repairPrompt, {
    temperature: 0.1,
    maxTokens: 2048,
    signal: input.signal,
  });
}

function parseQuestions(
  raw: string,
  count: number,
  maxOutputCount: number,
  difficulty: "easy" | "medium" | "hard",
  focusTag?: string,
  usedStems?: Set<string>
): QuizQuestion[] {
  try {
    const payload: unknown = JSON.parse(extractJsonPayload(raw));
    const arr = readQuestionArray(payload);
    if (arr.length > 0) {
      const parsed: QuizQuestion[] = [];
      const parsedStems = new Set<string>();
      for (const item of arr) {
        if (!item || typeof item !== "object") continue;
        const q = item as Record<string, unknown>;
        if (q.type !== "choice") continue;
        const stem = typeof q.stem === "string" ? q.stem.trim() : "";
        const options = normalizeOptions(q.options);
        const answer = normalizeAnswer(q.answer, options);
        const explanation =
          typeof q.explanation === "string" ? q.explanation.trim() : "";
        const tags = parseTags(q.tags, focusTag);
        const normalizedStem = normalizeStem(stem);
        if (usedStems?.has(normalizedStem) || parsedStems.has(normalizedStem)) continue;
        const validOptions = options.length === 4 && options.every((option, index) =>
          option.length <= MAX_QUESTION_OPTION_LENGTH &&
          option.toUpperCase().startsWith(`${String.fromCharCode(65 + index)}.`)
        );
        if (
          stem.length < 1 ||
          stem.length > MAX_QUESTION_STEM_LENGTH ||
          !validOptions ||
          !/^[A-D]$/i.test(answer) ||
          explanation.length < 1 ||
          explanation.length > MAX_QUESTION_EXPLANATION_LENGTH ||
          tags === null
        ) continue;
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
        parsedStems.add(normalizedStem);
        if (parsed.length > maxOutputCount) return [];
      }
      return parsed.slice(0, count);
    }
  } catch {
    return [];
  }
  return [];
}

function normalizeStem(stem: string): string {
  return stem.trim().replace(/\s+/g, " ").toLowerCase();
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

function parseTags(value: unknown, focusTag?: string): string[] | null {
  if (!Array.isArray(value) || value.length < 1 || value.length > MAX_QUESTION_TAGS) {
    return null;
  }
  const tags: string[] = [];
  for (const valueItem of value) {
    if (typeof valueItem !== "string") return null;
    const tag = valueItem.trim();
    if (tag.length < 1 || tag.length > MAX_QUESTION_TAG_LENGTH) return null;
    if (!tags.includes(tag)) tags.push(tag);
  }
  if (tags.length === 0) return null;
  const normalizedFocusTag = typeof focusTag === "string" ? focusTag.trim() : "";
  if (
    normalizedFocusTag.length > 0 &&
    normalizedFocusTag.length <= MAX_QUESTION_TAG_LENGTH &&
    !tags.includes(normalizedFocusTag)
  ) {
    tags.unshift(normalizedFocusTag);
  }
  return tags.slice(0, MAX_QUESTION_TAGS);
}
