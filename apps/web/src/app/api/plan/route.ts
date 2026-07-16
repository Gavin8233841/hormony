// GET /api/plan — 获取学习计划
// POST /api/plan — 生成学习计划

import { runPlannerAgent } from "@/lib/agents/planner-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import { getModelRuntimeInfo, ModelUnavailableError } from "@/lib/agents/model";
import { modelErrorResponse, SafetyBlockedError } from "@/lib/api-errors";
import type { LearningProfileSnapshot, StudyPlan } from "@/lib/types";
import { runSafetyAgent, validateUserInput } from "@/lib/agents/safety-agent";
import { readJsonObject } from "@/lib/request-json";
import {
  readBoundedInteger,
  readDateKey,
  sanitizeLearningProfile,
} from "@/lib/api-validation";

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
  const parsed = await readJsonObject<Record<string, unknown>>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);
  if (body.goal === undefined) {
    return Response.json({ error: "缺少 goal 字段", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (typeof body.goal !== "string") {
    return Response.json({ error: "goal 必须是字符串", code: "INVALID_GOAL" }, { status: 400 });
  }
  const goal = body.goal.trim();
  const durationDays = readBoundedInteger(
    body.durationDays,
    14,
    1,
    30,
    "INVALID_DURATION",
    "durationDays"
  );
  if (!durationDays.ok) return durationDays.response;
  const dailyMinutes = readBoundedInteger(
    body.dailyMinutes,
    90,
    15,
    480,
    "INVALID_DAILY_MINUTES",
    "dailyMinutes"
  );
  if (!dailyMinutes.ok) return dailyMinutes.response;
  const startDate = readDateKey(
    body.startDate,
    new Date().toISOString().slice(0, 10),
    "INVALID_START_DATE",
    "startDate"
  );
  if (!startDate.ok) return startDate.response;
  const profile = sanitizeLearningProfile(body.profile);
  if (!profile.ok) return profile.response;
  const profileSafetyFlags = profile.value ? validateUserInput(profileSafetyText(profile.value)) : [];
  if (profileSafetyFlags.length > 0) {
    return Response.json(
      { error: "画像内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

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
    const plan = await runPlannerAgent(
      userId,
      goal,
      durationDays.value,
      dailyMinutes.value,
      startDate.value,
      profile.value as LearningProfileSnapshot | undefined
    );
    await assertSafePlan(plan);
    return Response.json(plan);
  } catch (err) {
    console.error("[plan/POST] error:", err instanceof Error ? err.message : String(err));
    return modelErrorResponse(err);
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}

function profileSafetyText(profile: LearningProfileSnapshot): string {
  return [
    profile.stage,
    profile.learningStyle,
    ...profile.weakTopics,
    ...profile.strongTopics,
  ].join("\n");
}

async function assertSafePlan(plan: StudyPlan): Promise<void> {
  const outputText = [
    plan.goal,
    ...(plan.agentTrace ?? []),
    ...plan.tasks.flatMap((task) => [
      task.title,
      task.topic ?? "",
      task.reason ?? "",
    ]),
  ].join("\n");
  const safety = await runSafetyAgent(outputText, []);
  if (!safety.passed) {
    throw new SafetyBlockedError();
  }
}
