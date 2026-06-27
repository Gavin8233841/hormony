// POST /api/plan — 生成学习计划

import { runPlannerAgent } from "@/lib/agents/planner-agent";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  let body: { userId?: string; goal?: string; durationDays?: number; dailyMinutes?: number };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = body.userId ?? "demo";
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
    console.error("[plan] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "生成计划失败，请稍后重试", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}
