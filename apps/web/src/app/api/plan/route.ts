// GET /api/plan — 获取学习计划
// POST /api/plan — 生成学习计划

import { runPlannerAgent } from "@/lib/agents/planner-agent";
import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
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
  let body: { userId?: string; goal?: string; durationDays?: number; dailyMinutes?: number };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = sanitizeUserId(body.userId);
  const goal = String(body.goal ?? "制定学习计划").trim();
  const durationDays = Math.min(Math.max(Number(body.durationDays) || 14, 1), 30);
  const dailyMinutes = Math.min(Math.max(Number(body.dailyMinutes) || 90, 15), 480);

  if (goal.length > 500) {
    return Response.json({ error: "目标描述过长（上限 500 字符）", code: "GOAL_TOO_LONG" }, { status: 400 });
  }

  try {
    const plan = await runPlannerAgent(userId, goal, durationDays, dailyMinutes);
    return Response.json(plan);
  } catch (err) {
    console.error("[plan/POST] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "生成计划失败，请稍后重试", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
