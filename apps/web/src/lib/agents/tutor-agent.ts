// Tutor Agent：课程问答与作业思路辅导

import { callModel } from "./model";
import { getProfileContext } from "./profile-agent";
import type { AgentResult, Citation } from "@/lib/types";

export async function runTutorAgent(
  userId: string,
  question: string,
  ragContext: string,
  citations: Citation[]
): Promise<AgentResult> {
  const profile = getProfileContext(userId);

  const systemPrompt = `你是一位耐心的大学课程辅导老师。根据学生画像和检索到的课程资料回答问题。
要求：
1. 优先依据提供的课程资料作答，并在回答末尾标注资料来源
2. 如资料不足，明确说明并基于通用知识补充
3. 针对学生的薄弱知识点给予针对性讲解
4. 语言清晰、结构化，适合大学生理解`;

  const userPrompt = `学生画像：${JSON.stringify(profile)}
课程资料：
${ragContext || "（无相关资料）"}

学生问题：${question}`;

  const content = await callModel(systemPrompt, userPrompt, {
    temperature: 0.3,
    maxTokens: 1024,
  });

  return {
    agent: "Tutor",
    content,
    citations,
  };
}
