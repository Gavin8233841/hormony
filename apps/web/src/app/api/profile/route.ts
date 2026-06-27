// GET /api/profile?userId=... — 获取用户学习画像

import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = sanitizeUserId(searchParams.get("userId"));
    const profile = store.getProfile(userId) ?? store.getProfile("demo");

    if (!profile) {
      return Response.json({ error: "用户不存在", code: "NOT_FOUND" }, { status: 404 });
    }
    return Response.json(profile);
  } catch (err) {
    console.error("[profile] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "画像数据获取失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
