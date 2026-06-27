import { randomUUID } from "crypto";

export function generateId(prefix = "id"): string {
  return `${prefix}_${randomUUID().slice(0, 8)}`;
}

// userId 格式校验：仅允许字母数字和下划线，长度 1-50 字符
// 空值或非法输入回退到 'demo'，防止 userId 伪造与路径/注入攻击
export function sanitizeUserId(raw: unknown): string {
  const s = String(raw ?? "demo").trim();
  if (s.length < 1 || s.length > 50) return "demo";
  if (!/^[a-zA-Z0-9_]+$/.test(s)) return "demo";
  return s;
}
