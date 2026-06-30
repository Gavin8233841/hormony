// Profile Agent：加载与维护用户学习画像

import type { LearningProfileSnapshot, AgentResult } from "@/lib/types";

const DEFAULT_PROFILE: LearningProfileSnapshot = {
  stage: "本科二年级",
  weakTopics: [],
  strongTopics: [],
  learningStyle: "结构化学习",
  stats: { totalQuestions: 0, accuracy: 0, studyDays: 1 },
};

export async function runProfileAgent(
  profile?: LearningProfileSnapshot
): Promise<AgentResult> {
  const resolved = profile ?? DEFAULT_PROFILE;
  return {
    agent: "Profile",
    content: `学习阶段：${resolved.stage}，学习风格：${resolved.learningStyle}。薄弱知识点：${resolved.weakTopics.join("、") || "暂无"}。已答题 ${resolved.stats.totalQuestions} 道，正确率 ${(resolved.stats.accuracy * 100).toFixed(0)}%。`,
    metadata: { profile: resolved },
  };
}

export function getProfileContext(
  profile?: LearningProfileSnapshot
): LearningProfileSnapshot {
  return profile ?? DEFAULT_PROFILE;
}
