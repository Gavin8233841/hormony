// GET /api/profile?userId=...

import { store } from "@/lib/store/db";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get("userId") ?? "demo";
  const profile = store.getProfile(userId) ?? store.getProfile("demo");

  if (!profile) {
    return Response.json({ error: "用户不存在", code: "NOT_FOUND" }, { status: 404 });
  }
  return Response.json(profile);
}
