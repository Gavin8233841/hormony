// GET /api/resources — 获取外部资源索引
// GET /api/resources?courseId=cs101 — 按课程筛选
// GET /api/resources?type=textbook — 按类型筛选

import { store } from "@/lib/store/db";
import { isExternalResourceType } from "@/lib/data";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const courseId = searchParams.get("courseId");
    const type = searchParams.get("type");

    if (type && !isExternalResourceType(type)) {
      return Response.json(
        { error: "无效的资源类型", code: "BAD_REQUEST" },
        { status: 400 }
      );
    }

    let resources = courseId
      ? store.getExternalResources(courseId)
      : store.getExternalResources();

    if (type) {
      resources = resources.filter((r) => r.type === type);
    }

    return Response.json({ resources, total: resources.length });
  } catch (err) {
    console.error("[resources/GET] error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "获取资源索引失败", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
