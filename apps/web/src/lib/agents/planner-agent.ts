// Planner Agent：学习计划生成与任务拆解

import { callModel, extractJsonPayload } from "./model";
import { getProfileContext } from "./profile-agent";
import { generateId } from "@/lib/utils";
import type { AgentResult, PlanTask, StudyPlan } from "@/lib/types";
import { store } from "@/lib/store/db";

export async function runPlannerAgent(
  userId: string,
  goal: string,
  durationDays: number,
  dailyMinutes: number
): Promise<StudyPlan> {
  const profile = getProfileContext(userId);

  const systemPrompt = `你是一位学习规划专家。根据学生画像和学习目标，制定结构化学习计划。
输出 JSON 数组，每个元素格式：{"title":"","date":"YYYY-MM-DD","estimatedMin":45,"type":"review|practice|reading|quiz"}
只输出 JSON，不要额外文字。`;

  const userPrompt = `学生画像：${JSON.stringify(profile)}
目标：${goal}
周期：${durationDays} 天
每日可用时间：${dailyMinutes} 分钟
请生成 ${Math.min(durationDays, 10)} 个关键任务。`;

  const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.4 });

  const tasks = parseTasks(raw, durationDays);

  const plan: StudyPlan = {
    planId: generateId("plan"),
    userId,
    goal,
    tasks,
  };
  store.savePlan(plan);
  return plan;
}

function parseTasks(raw: string, durationDays: number): PlanTask[] {
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
    // 解析失败，回退到演示任务
  }
  return demoTasks(durationDays);
}

function demoTasks(durationDays: number): PlanTask[] {
  const base = Date.now();
  const titles = [
    { title: "复习树与二叉树", type: "review" as const, min: 45 },
    { title: "练习二叉搜索树相关习题", type: "practice" as const, min: 30 },
    { title: "阅读动态规划章节", type: "reading" as const, min: 40 },
    { title: "完成动态规划小测", type: "quiz" as const, min: 20 },
    { title: "复习图论与遍历算法", type: "review" as const, min: 45 },
  ];
  return titles.slice(0, Math.min(durationDays, 5)).map((t, i) => ({
    id: generateId("task"),
    title: t.title,
    date: new Date(base + i * 86400000).toISOString().slice(0, 10),
    estimatedMin: t.min,
    type: t.type,
  }));
}
