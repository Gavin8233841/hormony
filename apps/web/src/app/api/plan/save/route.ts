// POST /api/plan/save — 保存学习计划
// PATCH /api/plan/save — 更新计划任务状态（打卡）

import { store } from "@/lib/store/db";
import type { PlanTask, StudyPlan } from "@/lib/types";
import { isCourseId } from "@/lib/data";
import { isJsonObject, readJsonObject } from "@/lib/request-json";
import { readUserId } from "@/lib/api-validation";
import { validateUserInput } from "@/lib/agents/safety-agent";

export const dynamic = "force-dynamic";

const PLAN_TYPES = ["review", "practice", "reading", "quiz"] as const;
const PLAN_ACTIONS = ["lesson", "practice", "quiz", "review"] as const;

// 保存完整计划
export async function POST(req: Request) {
  const parsed = await readJsonObject<StudyPlan>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;
  if (body.goal !== undefined && typeof body.goal !== "string") {
    return Response.json({ error: "目标描述必须是字符串", code: "INVALID_GOAL" }, { status: 400 });
  }
  const goal = body.goal?.trim() ?? "";
  if (body.tasks !== undefined && !Array.isArray(body.tasks)) {
    return Response.json(
      { error: "任务列表必须是数组", code: "INVALID_TASKS" },
      { status: 400 }
    );
  }
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
  if (body.planId !== undefined) {
    if (typeof body.planId !== "string" || body.planId.trim().length < 1 || body.planId.length > 100) {
      return Response.json({ error: "planId 长度必须为 1-100 字符", code: "INVALID_PLAN_ID" }, { status: 400 });
    }
  }
  if (!tasks.every(isJsonObject)) {
    return Response.json(
      { error: "任务列表必须只包含对象", code: "INVALID_TASKS" },
      { status: 400 }
    );
  }
  const taskObjects = tasks as unknown as Record<string, unknown>[];

  for (const task of taskObjects) {
    const taskValidation = validateTask(task);
    if (taskValidation) return taskValidation;
  }
  const traceValidation = validateTrace(body.agentTrace);
  if (traceValidation) return traceValidation;
  const agentTrace = sanitizeTrace(body.agentTrace);
  const safetyText = [
    goal,
    ...(agentTrace ?? []),
    ...taskObjects.flatMap((task) => [
      task.id,
      task.title,
      task.date,
      task.topic,
      task.reason,
    ].filter((value): value is string => typeof value === "string")),
  ].join("\n");
  if (validateUserInput(safetyText).length > 0) {
    return Response.json(
      { error: "计划内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  const plan: StudyPlan = {
    planId: body.planId?.trim() ?? `plan_${Date.now().toString(36)}`,
    userId: userId.value,
    goal,
    tasks: taskObjects.slice(0, 50).map((t) => sanitizeTask(t)),
    agentTrace,
  };

  store.savePlan(plan);
  store.logActivity({
    userId: userId.value,
    type: "plan",
    description: `保存学习计划：${goal.slice(0, 40)}`,
    timestamp: new Date().toISOString(),
  });

  return Response.json(plan);
}

function validateTask(task: Record<string, unknown>): Response | null {
  if (task.id !== undefined && (typeof task.id !== "string" || task.id.trim().length < 1 || task.id.length > 100)) {
    return Response.json({ error: "任务 id 长度必须为 1-100 字符", code: "INVALID_TASK_ID" }, { status: 400 });
  }
  if (task.type !== undefined && (typeof task.type !== "string" || !isPlanType(task.type))) {
    return Response.json({ error: "任务包含不支持的类型", code: "INVALID_TASK_TYPE" }, { status: 400 });
  }
  if (task.title !== undefined && (typeof task.title !== "string" || task.title.trim().length === 0 || task.title.length > 200)) {
    return Response.json({ error: "任务标题长度必须为 1-200 字符", code: "INVALID_TASK_TITLE" }, { status: 400 });
  }
  if (task.date !== undefined && (typeof task.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(task.date))) {
    return Response.json({ error: "任务日期必须为 YYYY-MM-DD", code: "INVALID_TASK_DATE" }, { status: 400 });
  }
  if (task.estimatedMin !== undefined) {
    if (typeof task.estimatedMin !== "number" || !Number.isFinite(task.estimatedMin) || !Number.isInteger(task.estimatedMin) || task.estimatedMin < 5 || task.estimatedMin > 480) {
      return Response.json({ error: "任务时长必须为 5-480 分钟整数", code: "INVALID_ESTIMATED_MIN" }, { status: 400 });
    }
  }
  if (task.done !== undefined && typeof task.done !== "boolean") {
    return Response.json({ error: "任务完成状态必须是布尔值", code: "INVALID_DONE" }, { status: 400 });
  }
  if (
    task.reason !== undefined &&
    (typeof task.reason !== "string" || task.reason.trim().length > 120)
  ) {
    return Response.json({ error: "任务原因必须是 120 字符以内字符串", code: "INVALID_REASON" }, { status: 400 });
  }
  if (task.courseId !== undefined) {
    if (typeof task.courseId !== "string" || !isCourseId(task.courseId)) {
      return Response.json({ error: "任务包含不支持的课程", code: "INVALID_COURSE" }, { status: 400 });
    }
  }
  if (task.topic !== undefined) {
    if (typeof task.topic !== "string") {
      return Response.json({ error: "任务主题必须是字符串", code: "INVALID_TOPIC" }, { status: 400 });
    }
    const topic = task.topic.trim();
    if (topic.length === 0 || topic.length > 100) {
      return Response.json({ error: "任务主题长度必须为 1-100 字符", code: "INVALID_TOPIC" }, { status: 400 });
    }
  }
  if (task.action !== undefined) {
    if (typeof task.action !== "string" || !isPlanAction(task.action)) {
      return Response.json({ error: "任务包含不支持的动作", code: "INVALID_ACTION" }, { status: 400 });
    }
  }
  return null;
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

  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;
  if (body.taskId !== undefined && typeof body.taskId !== "string") {
    return Response.json({ error: "taskId 必须是字符串", code: "INVALID_TASK_ID" }, { status: 400 });
  }
  const taskId = body.taskId?.trim() ?? "";

  if (!taskId) {
    return Response.json({ error: "缺少 taskId", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (taskId.length > 100) {
    return Response.json({ error: "taskId 长度不能超过 100 字符", code: "INVALID_TASK_ID" }, { status: 400 });
  }
  if (body.done === undefined) {
    return Response.json({ error: "缺少 done", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (typeof body.done !== "boolean") {
    return Response.json({ error: "done 必须是布尔值", code: "INVALID_DONE" }, { status: 400 });
  }

  const plan = store.updatePlanTask(userId.value, taskId, body.done);
  if (!plan) {
    return Response.json({ error: "计划或任务不存在", code: "NOT_FOUND" }, { status: 404 });
  }

  if (body.done) {
    const task = plan.tasks.find((item) => item.id === taskId);
    if (task) {
      store.logActivity({
        userId: userId.value,
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
    reason: typeof t.reason === "string" ? t.reason.trim().slice(0, 120) : undefined,
    done: Boolean(t.done),
  };
}

function sanitizeTrace(trace: unknown): string[] | undefined {
  if (!Array.isArray(trace)) return undefined;
  const items = trace
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim().slice(0, 160))
    .filter((item) => item.length > 0)
    .slice(0, 8);
  return items.length > 0 ? items : undefined;
}

function validateTrace(trace: unknown): Response | null {
  if (trace === undefined) return null;
  if (!Array.isArray(trace) || trace.length > 8) {
    return Response.json(
      { error: "agentTrace 必须是最多 8 项的字符串数组", code: "INVALID_AGENT_TRACE" },
      { status: 400 }
    );
  }
  if (
    !trace.every(
      (item) => typeof item === "string" && item.trim().length <= 160
    )
  ) {
    return Response.json(
      { error: "agentTrace 每项必须是 160 字符以内字符串", code: "INVALID_AGENT_TRACE" },
      { status: 400 }
    );
  }
  return null;
}

function isPlanType(value: string): boolean {
  return PLAN_TYPES.some((type) => type === value);
}

function isPlanAction(value: string): boolean {
  return PLAN_ACTIONS.some((action) => action === value);
}
