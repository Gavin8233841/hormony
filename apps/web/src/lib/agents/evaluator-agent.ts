// Evaluator Agent：错题与薄弱点分析

import { callModel } from "./model";
import type { AgentResult } from "@/lib/types";

export async function runEvaluatorAgent(
  userId: string,
  answers: { question: string; userAnswer: string; correctAnswer: string }[]
): Promise<AgentResult> {
  const correct = answers.filter((a) => a.userAnswer === a.correctAnswer).length;
  const accuracy = answers.length > 0 ? correct / answers.length : 0;

  const systemPrompt = `你是一位学习诊断专家。根据学生答题情况分析薄弱点并给出改进建议。
输出结构化文字，包含：1.正确率分析 2.薄弱知识点 3.针对性复习建议`;

  const userPrompt = `学生ID：${userId}
答题记录：
${answers.map((a, i) => `第${i + 1}题：${a.question}\n  学生答案：${a.userAnswer} | 正确答案：${a.correctAnswer} | ${a.userAnswer === a.correctAnswer ? "✓" : "✗"}`).join("\n\n")}`;

  const content = await callModel(systemPrompt, userPrompt, { temperature: 0.3 });

  return {
    agent: "Evaluator",
    content: `正确率：${(accuracy * 100).toFixed(0)}%（${correct}/${answers.length}）\n\n${content}`,
    metadata: { accuracy, correct, total: answers.length },
  };
}
