// GET /api/courses?userId=... — 获取用户课程列表
// POST /api/courses — 添加新课程

import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { Course } from "@/lib/types";
import { readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = sanitizeUserId(searchParams.get("userId"));
    const courses = store.getCourses(userId);
    return Response.json({ courses });
  } catch (err) {
    console.error("[courses/GET] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "课程数据获取失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  const parsed = await readJsonObject<Partial<Course> & { userId?: string }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);
  const id = String(body.id ?? `course_${Date.now().toString(36)}`).trim();
  const title = String(body.title ?? "").trim();

  if (!title) {
    return Response.json({ error: "缺少课程名称", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (title.length > 100) {
    return Response.json({ error: "课程名称过长（上限 100 字符）", code: "TITLE_TOO_LONG" }, { status: 400 });
  }

  const course: Course = {
    id,
    title,
    progress: Math.min(Math.max(Number(body.progress) || 0, 0), 1),
    docCount: Math.max(Number(body.docCount) || 0, 0),
    topics: Array.isArray(body.topics)
      ? body.topics.filter((t) => typeof t === "string").slice(0, 20)
      : [],
  };

  try {
    store.addCourse(userId, course);
    store.logActivity({
      userId,
      type: "study",
      description: `添加课程：${title}`,
      timestamp: new Date().toISOString(),
    });
    return Response.json(course, { status: 201 });
  } catch (err) {
    console.error("[courses/POST] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "添加课程失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
