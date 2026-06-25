// POST /api/plan — 生成学习计划

import { runPlannerAgent } from "@/lib/agents/planner-agent";

export async function POST(req: Request) {
  let body: { userId?: string; goal?: string; durationDays?: number; dailyMinutes?: number };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = body.userId ?? "demo";
  const goal = body.goal ?? "制定学习计划";
  const durationDays = body.durationDays ?? 14;
  const dailyMinutes = body.dailyMinutes ?? 90;

  const plan = await runPlannerAgent(userId, goal, durationDays, dailyMinutes);
  return Response.json(plan);
}
