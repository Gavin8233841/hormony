import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import { randomUUID } from "crypto";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function generateId(prefix = "id"): string {
  return `${prefix}_${randomUUID().slice(0, 8)}`;
}

// userId 格式校验：仅允许字母数字下划线连字符，最长 64 字符
export function sanitizeUserId(raw: unknown): string {
  const s = String(raw ?? "demo").trim();
  if (s.length === 0 || s.length > 64) return "demo";
  if (!/^[a-zA-Z0-9_-]+$/.test(s)) return "demo";
  return s;
}
