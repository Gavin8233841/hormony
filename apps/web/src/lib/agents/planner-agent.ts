// Planner Agent：学习计划生成与任务拆解

import { callModel, extractJsonPayload } from "./model";
import { getProfileContext } from "./profile-agent";
import { generateId } from "@/lib/utils";
import type { LearningProfileSnapshot, PlanTask, StudyPlan } from "@/lib/types";

export async function runPlannerAgent(
  userId: string,
  goal: string,
  durationDays: number,
  dailyMinutes: number,
  profileSnapshot?: LearningProfileSnapshot
): Promise<StudyPlan> {
  const profile = getProfileContext(profileSnapshot);

  const systemPrompt = `你是一位学习规划专家。根据学生画像和学习目标，制定结构化学习计划。
输出 JSON 数组，每个元素格式：{"title":"","date":"YYYY-MM-DD","estimatedMin":45,"type":"review|practice|reading|quiz"}
只输出 JSON，不要额外文字。`;

  const userPrompt = `学生画像：${JSON.stringify(profile)}
目标：${goal}
周期：${durationDays} 天
每日可用时间：${dailyMinutes} 分钟
请生成 ${Math.min(durationDays, 10)} 个关键任务。`;

  const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 1200 });

  const tasks = parseTasks(raw);
  if (tasks.length === 0) {
    throw new Error("MODEL_INVALID_RESPONSE: 学习计划不是有效 JSON");
  }

  const plan: StudyPlan = {
    planId: generateId("plan"),
    userId,
    goal,
    tasks,
  };
  return plan;
}

function parseTasks(raw: string): PlanTask[] {
  try {
    const arr = JSON.parse(extractJsonPayload(raw));
    if (Array.isArray(arr)) {
      return arr.slice(0, 10).map((t: Record<string, unknown>, i: number) => ({
        id: generateId("task"),
        title: String(t.title ?? `任务 ${i + 1}`),
        date: String(t.date ?? new Date(Date.now() + i * 86400000).toISOString().slice(0, 10)),
        estimatedMin: Number(t.estimatedMin ?? 45),
        type: (["review", "practice", "reading", "quiz"].includes(String(t.type))
          ? t.type
          : "review") as PlanTask["type"],
      }));
    }
  } catch {
    return [];
  }
  return [];
}
