// GET /api/courses?userId=... — 获取用户课程列表

import { store } from "@/lib/store/db";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId") ?? "demo";
    const courses = store.getCourses(userId);
    return Response.json({ courses });
  } catch (err) {
    console.error("[courses] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "课程数据获取失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
