// PUT /api/profile/update — 更新用户学习画像

import { store } from "@/lib/store/db";
import type { UserProfile } from "@/lib/types";
import { readJsonObject } from "@/lib/request-json";
import { readUserId } from "@/lib/api-validation";
import { validateUserInput } from "@/lib/agents/safety-agent";

export const dynamic = "force-dynamic";

export async function PUT(req: Request) {
  const parsed = await readJsonObject<Partial<UserProfile> & { userId?: string }>(req);
  if (!parsed.ok) return parsed.response;
  const body = parsed.body;

  const userId = readUserId(body.userId);
  if (!userId.ok) return userId.response;

  // 只提取白名单字段，防止非法字段注入
  const updates: Partial<UserProfile> = {};

  // 字符串字段
  for (const field of ["name", "stage", "learningStyle"] as const) {
    const val = body[field];
    if (val === undefined) continue;
    if (typeof val !== "string") {
      return Response.json(
        { error: `${field} 必须是字符串`, code: "INVALID_PROFILE_FIELD" },
        { status: 400 }
      );
    }
    const trimmed = val.trim();
    if (trimmed.length < 1 || trimmed.length > 100) {
      return Response.json(
        { error: `${field} 长度必须为 1-100 字符`, code: "INVALID_PROFILE_FIELD" },
        { status: 400 }
      );
    }
    updates[field] = trimmed;
  }

  // 数组字段
  for (const field of ["weakTopics", "strongTopics"] as const) {
    const val = body[field];
    if (val === undefined) continue;
    if (!Array.isArray(val) || val.length > 20 || !val.every((item) => typeof item === "string")) {
      return Response.json(
        { error: `${field} 必须是最多 20 项的字符串数组`, code: "INVALID_PROFILE_FIELD" },
        { status: 400 }
      );
    }
    const topics = val.map((item) => item.trim());
    if (topics.some((item) => item.length < 1 || item.length > 50)) {
      return Response.json(
        { error: `${field} 每项长度必须为 1-50 字符`, code: "INVALID_PROFILE_FIELD" },
        { status: 400 }
      );
    }
    updates[field] = topics;
  }

  if (Object.keys(updates).length === 0) {
    return Response.json({ error: "没有有效的更新字段", code: "NO_VALID_FIELDS" }, { status: 400 });
  }
  const safetyText = [
    updates.name ?? "",
    updates.stage ?? "",
    updates.learningStyle ?? "",
    ...(updates.weakTopics ?? []),
    ...(updates.strongTopics ?? []),
  ].join("\n");
  if (validateUserInput(safetyText).length > 0) {
    return Response.json(
      { error: "画像内容不符合安全要求", code: "INPUT_REJECTED" },
      { status: 400 }
    );
  }

  const updated = store.updateProfile(userId.value, updates);
  if (!updated) {
    return Response.json({ error: "用户不存在", code: "NOT_FOUND" }, { status: 404 });
  }

  // 记录活动
  store.logActivity({
    userId: userId.value,
    type: "study",
    description: `更新学习画像：${Object.keys(updates).join("、")}`,
    timestamp: new Date().toISOString(),
  });

  return Response.json(updated);
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
