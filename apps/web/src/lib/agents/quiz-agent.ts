// Quiz Agent：测验题生成

import { callModel, extractJsonPayload } from "./model";
import { generateId } from "@/lib/utils";
import { store } from "@/lib/store/db";
import type { AgentResult, Quiz, QuizQuestion } from "@/lib/types";

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

  const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.5 });

  const questions = parseQuestions(raw, count, topic);

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
      return arr.slice(0, count).map((q: Record<string, unknown>, i: number) => ({
        id: generateId("q"),
        type: "choice" as const,
        stem: String(q.stem ?? `${topic} 第 ${i + 1} 题`),
        options: Array.isArray(q.options) ? q.options.map(String) : ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
        answer: String(q.answer ?? "A"),
        explanation: String(q.explanation ?? "暂无解析"),
      }));
    }
  } catch {
    // 回退演示题
  }
  return demoQuestions(count, topic);
}

function demoQuestions(count: number, topic: string): QuizQuestion[] {
  const bank: QuizQuestion[] = [
    {
      id: generateId("q"),
      type: "choice",
      stem: `关于${topic}，下列说法正确的是？`,
      options: ["A. 中序遍历得到升序序列", "B. 只能存储整数", "C. 不支持插入操作", "D. 查找复杂度恒为 O(1)"],
      answer: "A",
      explanation: "二叉搜索树中序遍历得到升序序列，这是其核心特性。",
    },
    {
      id: generateId("q"),
      type: "choice",
      stem: `${topic}的最坏时间复杂度是？`,
      options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
      answer: "C",
      explanation: "当树退化为链表时，查找复杂度为 O(n)。",
    },
    {
      id: generateId("q"),
      type: "choice",
      stem: `学习${topic}时，最有效的实践方式是？`,
      options: ["A. 只看课本", "B. 结合代码实现与习题练习", "C. 死记硬背", "D. 跳过练习"],
      answer: "B",
      explanation: "结合代码实现与习题练习能加深对数据结构的理解。",
    },
  ];
  return bank.slice(0, count);
}
