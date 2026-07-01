// GET /api/plan — 获取学习计划
// POST /api/plan — 生成学习计划

import { runPlannerAgent } from "@/lib/agents/planner-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import { getModelRuntimeInfo, ModelUnavailableError } from "@/lib/agents/model";
import { modelErrorResponse } from "@/lib/api-errors";
import type { LearningProfileSnapshot } from "@/lib/types";
import { validateUserInput } from "@/lib/agents/safety-agent";
import { readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";
export const maxDuration = 120;

export async function GET(req: Request) {
  if (process.env.DEPLOYMENT_MODE === "stateless") {
    return Response.json(
      { error: "学习计划仅保存在 HarmonyOS 设备", code: "ENDPOINT_DISABLED" },
      { status: 404 }
    );
  }
  try {
    const { searchParams } = new URL(req.url);
    const userId = sanitizeUserId(searchParams.get("userId"));
    const plan = store.getPlan(userId);
    if (!plan) {
      return Response.json({ error: "未找到学习计划", code: "NOT_FOUND" }, { status: 404 });
    }
    return Response.json(plan);
  } catch (err) {
    console.error("[plan/GET] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "获取计划失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  const parsed = await readJsonObject<{
    userId?: string;
    goal?: string;
    durationDays?: number;
    dailyMinutes?: number;
    profile?: LearningProfileSnapshot;
  }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);
  const goal = String(body.goal ?? "").trim();
  const durationDays = Math.min(Math.max(Number(body.durationDays) || 14, 1), 30);
  const dailyMinutes = Math.min(Math.max(Number(body.dailyMinutes) || 90, 15), 480);

  if (goal.length === 0) {
    return Response.json({ error: "缺少 goal 字段", code: "MISSING_FIELD" }, { status: 400 });
  }

  if (goal.length > 500) {
    return Response.json({ error: "目标描述过长（上限 500 字符）", code: "GOAL_TOO_LONG" }, { status: 400 });
  }

  if (validateUserInput(goal).length > 0) {
    return Response.json(
      { error: "目标内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  if (!getModelRuntimeInfo().configured) {
    return modelErrorResponse(new ModelUnavailableError());
  }

  try {
    const plan = await runPlannerAgent(userId, goal, durationDays, dailyMinutes, body.profile);
    return Response.json(plan);
  } catch (err) {
    console.error("[plan/POST] error:", err instanceof Error ? err.message : String(err));
    return modelErrorResponse(err);
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
