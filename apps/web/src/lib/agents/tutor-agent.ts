// Tutor Agent：课程问答与作业思路辅导
// 支持多轮对话上下文

import { callModel, callModelWithHistory } from "./model";
import { getProfileContext } from "./profile-agent";
import type { AgentResult, Citation, ChatMessage, LearningProfileSnapshot } from "@/lib/types";

export async function runTutorAgent(
  userId: string,
  question: string,
  ragContext: string,
  citations: Citation[],
  history?: ChatMessage[],
  profileSnapshot?: LearningProfileSnapshot
): Promise<AgentResult> {
  const profile = getProfileContext(profileSnapshot);

  const systemPrompt = `你是一位耐心的大学课程辅导老师。根据学生画像和检索到的课程资料回答问题。
要求：
1. 优先依据提供的课程资料作答，并在回答末尾标注资料来源
2. 如资料不足，明确说明并基于通用知识补充
3. 针对学生的薄弱知识点给予针对性讲解
4. 语言清晰、结构化，适合大学生理解
5. 结合对话历史，保持上下文连贯，避免重复已解答的内容`;

  const userPrompt = `学生画像：${JSON.stringify(profile)}
课程资料：
${ragContext || "（无相关资料）"}

学生问题：${question}`;

  // 有对话历史时使用带上下文的调用
  const recentHistory = (history ?? [])
    .filter((m) => m.role === "user" || m.role === "assistant")
    .slice(-12)
    .map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content.slice(0, 500), // 截断过长的历史消息
    }));

  const content = recentHistory.length > 0
    ? await callModelWithHistory(systemPrompt, userPrompt, recentHistory, {
        temperature: 0.3,
        maxTokens: 1024,
      })
    : await callModel(systemPrompt, userPrompt, {
        temperature: 0.3,
        maxTokens: 1024,
      });

  return {
    agent: "Tutor",
    content,
    citations,
  };
}
