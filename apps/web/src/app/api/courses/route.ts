// GET /api/courses?userId=...

import { store } from "@/lib/store/db";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get("userId") ?? "demo";
  const courses = store.getCourses(userId);
  return Response.json({ courses });
}
