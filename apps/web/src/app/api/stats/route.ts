// GET /api/stats?userId=... — 仪表盘统计数据聚合

import { store } from "@/lib/store/db";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get("userId") ?? "demo";

  try {
    const stats = store.getStats(userId);
    return Response.json(stats);
  } catch (err) {
    console.error("[stats] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "统计数据获取失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
