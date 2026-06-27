// GET /api/conversations?userId=...&limit=... — 获取用户会话历史

import { store } from "@/lib/store/db";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get("userId") ?? "demo";
  const limit = Math.min(Math.max(Number(searchParams.get("limit")) || 20, 1), 100);

  try {
    const conversations = store.getConversations(userId, limit);
    return Response.json({ conversations, count: conversations.length });
  } catch (err) {
    console.error("[conversations] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "会话历史获取失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
