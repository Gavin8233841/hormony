// POST /api/plan/save — 保存学习计划
// PATCH /api/plan/save — 更新计划任务状态（打卡）

import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { StudyPlan } from "@/lib/types";

export const dynamic = "force-dynamic";

// 保存完整计划
export async function POST(req: Request) {
  let body: StudyPlan;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = sanitizeUserId(body.userId);
  const goal = String(body.goal ?? "").trim();
  const tasks = Array.isArray(body.tasks) ? body.tasks : [];

  if (!goal) {
    return Response.json({ error: "缺少目标描述", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (goal.length > 500) {
    return Response.json({ error: "目标描述过长（上限 500 字符）", code: "GOAL_TOO_LONG" }, { status: 400 });
  }
  if (tasks.length === 0) {
    return Response.json({ error: "任务列表不能为空", code: "EMPTY_TASKS" }, { status: 400 });
  }
  if (tasks.length > 50) {
    return Response.json({ error: "任务数量超出上限（50 个）", code: "TOO_MANY_TASKS" }, { status: 400 });
  }

  const plan: StudyPlan = {
    planId: body.planId ?? `plan_${Date.now().toString(36)}`,
    userId,
    goal,
    tasks: tasks.slice(0, 50).map((t) => ({
      id: String(t.id ?? `task_${Math.random().toString(36).slice(2, 8)}`),
      title: String(t.title ?? "未命名任务").slice(0, 200),
      date: String(t.date ?? new Date().toISOString().slice(0, 10)),
      estimatedMin: Math.min(Math.max(Number(t.estimatedMin) || 30, 5), 480),
      type: ["review", "practice", "reading", "quiz"].includes(String(t.type))
        ? t.type
        : "review",
      done: Boolean(t.done),
    })),
  };

  store.savePlan(plan);
  store.logActivity({
    type: "plan",
    description: `保存学习计划：${goal.slice(0, 40)}`,
    timestamp: new Date().toISOString(),
  });

  return Response.json(plan);
}

// 更新任务打卡状态
export async function PATCH(req: Request) {
  let body: { userId?: string; taskId?: string; done?: boolean };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = sanitizeUserId(body.userId);
  const taskId = String(body.taskId ?? "").trim();
  const done = Boolean(body.done);

  if (!taskId) {
    return Response.json({ error: "缺少 taskId", code: "MISSING_FIELD" }, { status: 400 });
  }

  const plan = store.updatePlanTask(userId, taskId, done);
  if (!plan) {
    return Response.json({ error: "计划不存在", code: "NOT_FOUND" }, { status: 404 });
  }

  return Response.json(plan);
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
