// POST /api/plan/save — 保存学习计划
// PATCH /api/plan/save — 更新计划任务状态（打卡）

import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { PlanTask, StudyPlan } from "@/lib/types";
import { isCourseId } from "@/lib/data";
import { isJsonObject, readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";

const PLAN_TYPES = ["review", "practice", "reading", "quiz"] as const;
const PLAN_ACTIONS = ["lesson", "practice", "quiz", "review"] as const;

// 保存完整计划
export async function POST(req: Request) {
  const parsed = await readJsonObject<StudyPlan>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

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
  if (!tasks.every(isJsonObject)) {
    return Response.json(
      { error: "任务列表必须只包含对象", code: "INVALID_TASKS" },
      { status: 400 }
    );
  }
  const taskObjects = tasks as unknown as Record<string, unknown>[];

  for (const task of taskObjects) {
    if (task.courseId !== undefined && !isCourseId(String(task.courseId))) {
      return Response.json({ error: "任务包含不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
    }
    const topic = task.topic === undefined ? undefined : String(task.topic).trim();
    if (topic !== undefined && (topic.length === 0 || topic.length > 100)) {
      return Response.json({ error: "任务主题长度必须为 1-100 字符", code: "INVALID_TOPIC" }, { status: 400 });
    }
    if (task.action !== undefined && !isPlanAction(String(task.action))) {
      return Response.json({ error: "任务包含不支持的动作", code: "INVALID_ACTION" }, { status: 400 });
    }
  }

  const plan: StudyPlan = {
    planId: body.planId ?? `plan_${Date.now().toString(36)}`,
    userId,
    goal,
    tasks: taskObjects.slice(0, 50).map((t) => sanitizeTask(t)),
  };

  store.savePlan(plan);
  store.logActivity({
    userId,
    type: "plan",
    description: `保存学习计划：${goal.slice(0, 40)}`,
    timestamp: new Date().toISOString(),
  });

  return Response.json(plan);
}

// 更新任务打卡状态
export async function PATCH(req: Request) {
  const parsed = await readJsonObject<{
    userId?: string;
    taskId?: string;
    done?: boolean;
  }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);
  const taskId = String(body.taskId ?? "").trim();
  const done = Boolean(body.done);

  if (!taskId) {
    return Response.json({ error: "缺少 taskId", code: "MISSING_FIELD" }, { status: 400 });
  }

  const plan = store.updatePlanTask(userId, taskId, done);
  if (!plan) {
    return Response.json({ error: "计划或任务不存在", code: "NOT_FOUND" }, { status: 404 });
  }

  if (done) {
    const task = plan.tasks.find((item) => item.id === taskId);
    if (task) {
      store.logActivity({
        userId,
        type: "plan",
        description: `完成任务：${task.title.slice(0, 40)}`,
        timestamp: new Date().toISOString(),
      });
    }
  }

  return Response.json(plan);
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}

function sanitizeTask(t: Record<string, unknown>): PlanTask {
  const type = isPlanType(String(t.type)) ? String(t.type) as PlanTask["type"] : "review";
  const courseId = t.courseId === undefined ? undefined : String(t.courseId);
  const topic = t.topic === undefined ? undefined : String(t.topic).trim();
  const action = t.action === undefined ? undefined : String(t.action);
  return {
    id: String(t.id ?? `task_${Math.random().toString(36).slice(2, 8)}`),
    title: String(t.title ?? "未命名任务").slice(0, 200),
    date: String(t.date ?? new Date().toISOString().slice(0, 10)),
    estimatedMin: Math.min(Math.max(Number(t.estimatedMin) || 30, 5), 480),
    type,
    courseId,
    topic,
    action: isPlanAction(action ?? "") ? action as PlanTask["action"] : undefined,
    done: Boolean(t.done),
  };
}

function isPlanType(value: string): boolean {
  return PLAN_TYPES.some((type) => type === value);
}

function isPlanAction(value: string): boolean {
  return PLAN_ACTIONS.some((action) => action === value);
}
