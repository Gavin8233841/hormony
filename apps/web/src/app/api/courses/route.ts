// GET /api/courses?userId=... — 获取用户课程列表
// POST /api/courses — 添加新课程

import { store } from "@/lib/store/db";
import type { Course } from "@/lib/types";
import { readJsonObject } from "@/lib/request-json";
import { readUserId } from "@/lib/api-validation";
import { validateUserInput } from "@/lib/agents/safety-agent";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = readUserId(searchParams.get("userId"));
    if (!userId.ok) return userId.response;
    const courses = store.getCourses(userId.value);
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

  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;
  if (body.id !== undefined && typeof body.id !== "string") {
    return Response.json({ error: "课程 id 必须是字符串", code: "INVALID_COURSE_ID" }, { status: 400 });
  }
  const id = body.id?.trim() || `course_${Date.now().toString(36)}`;
  if (id.length > 100) {
    return Response.json({ error: "课程 id 长度不能超过 100 字符", code: "INVALID_COURSE_ID" }, { status: 400 });
  }
  if (body.title !== undefined && typeof body.title !== "string") {
    return Response.json({ error: "课程名称必须是字符串", code: "INVALID_TITLE" }, { status: 400 });
  }
  const title = body.title?.trim() ?? "";

  if (!title) {
    return Response.json({ error: "缺少课程名称", code: "MISSING_FIELD" }, { status: 400 });
  }
  if (title.length > 100) {
    return Response.json({ error: "课程名称过长（上限 100 字符）", code: "TITLE_TOO_LONG" }, { status: 400 });
  }
  if (
    body.progress !== undefined &&
    (typeof body.progress !== "number" || !Number.isFinite(body.progress) || body.progress < 0 || body.progress > 1)
  ) {
    return Response.json({ error: "课程进度必须在 0-1 之间", code: "INVALID_PROGRESS" }, { status: 400 });
  }
  if (
    body.docCount !== undefined &&
    (typeof body.docCount !== "number" || !Number.isInteger(body.docCount) || body.docCount < 0)
  ) {
    return Response.json({ error: "资料数量必须是非负整数", code: "INVALID_DOC_COUNT" }, { status: 400 });
  }
  if (body.topics !== undefined && !Array.isArray(body.topics)) {
    return Response.json({ error: "课程主题必须是字符串数组", code: "INVALID_TOPICS" }, { status: 400 });
  }
  const topicValues = body.topics ?? [];
  if (topicValues.length > 20 || !topicValues.every((topic) => typeof topic === "string")) {
    return Response.json({ error: "课程主题最多包含 20 个字符串", code: "INVALID_TOPICS" }, { status: 400 });
  }
  const topics = topicValues.map((topic) => topic.trim());
  if (topics.some((topic) => topic.length < 1 || topic.length > 100)) {
    return Response.json({ error: "课程主题长度必须为 1-100 字符", code: "INVALID_TOPICS" }, { status: 400 });
  }
  if (validateUserInput([id, title, ...topics].join("\n")).length > 0) {
    return Response.json(
      { error: "课程内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  const course: Course = {
    id,
    title,
    progress: body.progress ?? 0,
    docCount: body.docCount ?? 0,
    topics,
  };

  try {
    store.addCourse(userId.value, course);
    store.logActivity({
      userId: userId.value,
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
