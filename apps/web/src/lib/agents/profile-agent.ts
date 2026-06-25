// Profile Agent：加载与维护用户学习画像

import { store } from "@/lib/store/db";
import type { UserProfile, AgentResult } from "@/lib/types";

export async function runProfileAgent(userId: string): Promise<AgentResult> {
  const profile = store.getProfile(userId) ?? store.getProfile("demo")!;
  return {
    agent: "Profile",
    content: `用户：${profile.name}（${profile.stage}），学习风格：${profile.learningStyle}。薄弱知识点：${profile.weakTopics.join("、")}。已答题 ${profile.stats.totalQuestions} 道，正确率 ${(profile.stats.accuracy * 100).toFixed(0)}%。`,
    metadata: { profile },
  };
}

export function getProfileContext(userId: string): Partial<UserProfile> {
  const p = store.getProfile(userId) ?? store.getProfile("demo")!;
  return {
    stage: p.stage,
    weakTopics: p.weakTopics,
    learningStyle: p.learningStyle,
  };
}
