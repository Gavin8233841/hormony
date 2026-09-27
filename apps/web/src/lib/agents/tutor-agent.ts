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
  profileSnapshot?: LearningProfileSnapshot,
  signal?: AbortSignal,
  scope: "general" | "concept" = "general"
): Promise<AgentResult> {
  const profile = getProfileContext(profileSnapshot);

  const systemPrompt = `你是大学课程学伴。先回答学生当前的问题，像面对面讲题一样说清关键一步。
优先依据课程资料和题目条件；资料不足时说明无法确认，不编造来源。题目尚未提交时只给一个思考提示，不直接说出答案。
学生要求“再给提示”时，在上一轮基础上只增加一个更具体的线索；要求“换个例子”时，换一道同概念的简短例子并指出可迁移的关键一步。不要把提示写成完整答案，也不要重复上一轮解释。
通常用两到四个短句，不写标题、报告或建议清单，不复述画像与对话历史。资料来源会由界面另行展示，正文不用重复列出。` +
    (scope === "concept" ? "\n当前入口仅解释课程概念。即使学生提及计划、出题或成绩，也不要生成计划、题目或评价个人表现；只解释其相关概念。需要举软件例子时，只用明确标为“假设”的无品牌程序，不提真实产品名称；不要把界面操作直接断言为产品内部的一一对应的进程或线程。具体实现未知时直说未知。" : "");

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
        maxTokens: 512,
        signal,
      })
    : await callModel(systemPrompt, userPrompt, {
        temperature: 0.3,
        maxTokens: 512,
        signal,
      });

  return {
    agent: "Tutor",
    content,
    citations,
  };
}
