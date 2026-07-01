// PUT /api/profile/update — 更新用户学习画像

import { store } from "@/lib/store/db";
import { sanitizeUserId } from "@/lib/utils";
import type { UserProfile } from "@/lib/types";
import { readJsonObject } from "@/lib/request-json";

export const dynamic = "force-dynamic";

export async function PUT(req: Request) {
  const parsed = await readJsonObject<Partial<UserProfile> & { userId?: string }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = sanitizeUserId(body.userId);

  // 只提取白名单字段，防止非法字段注入
  const updates: Partial<UserProfile> = {};

  // 字符串字段
  for (const field of ["name", "stage", "learningStyle"] as const) {
    const val = body[field];
    if (typeof val === "string") {
      const trimmed = val.trim();
      if (trimmed.length > 0 && trimmed.length <= 100) {
        updates[field] = trimmed;
      }
    }
  }

  // 数组字段
  for (const field of ["weakTopics", "strongTopics"] as const) {
    const val = body[field];
    if (Array.isArray(val) && val.every((v) => typeof v === "string")) {
      updates[field] = val.map((v) => v.slice(0, 50)).slice(0, 20);
    }
  }

  if (Object.keys(updates).length === 0) {
    return Response.json({ error: "没有有效的更新字段", code: "NO_VALID_FIELDS" }, { status: 400 });
  }

  const updated = store.updateProfile(userId, updates);
  if (!updated) {
    return Response.json({ error: "用户不存在", code: "NOT_FOUND" }, { status: 404 });
  }

  // 记录活动
  store.logActivity({
    userId,
    type: "study",
    description: `更新学习画像：${Object.keys(updates).join("、")}`,
    timestamp: new Date().toISOString(),
  });

  return Response.json(updated);
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
