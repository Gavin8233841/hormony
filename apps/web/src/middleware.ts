// Next.js 中间件：安全头 + API 速率限制
// 适用于 App Router，在边缘运行时执行

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// 速率限制配置
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 分钟窗口
const RATE_LIMIT_MAX_REQUESTS = 30;  // 每窗口最大请求数

// 内存存储（单实例够用，多实例需换 Redis）
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

// 安全响应头
const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "X-XSS-Protection": "1; mode=block",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
};

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // 仅对 API 路由执行速率限制
  if (pathname.startsWith("/api/")) {
    // CORS 预检直接放行
    if (req.method === "OPTIONS") {
      const res = new NextResponse(null, { status: 204 });
      addSecurityHeaders(res);
      res.headers.set("Access-Control-Allow-Origin", "*");
      res.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
      res.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      return res;
    }

    // 速率限制（基于 IP）
    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const now = Date.now();
    const key = `${clientIp}:${pathname}`;
    const record = rateLimitMap.get(key);

    if (record && now < record.resetTime) {
      record.count++;
      if (record.count > RATE_LIMIT_MAX_REQUESTS) {
        const res = NextResponse.json(
          { error: "请求过于频繁，请稍后重试", code: "RATE_LIMITED" },
          { status: 429 }
        );
        res.headers.set("Retry-After", String(Math.ceil((record.resetTime - now) / 1000)));
        addSecurityHeaders(res);
        return res;
      }
    } else {
      rateLimitMap.set(key, { count: 1, resetTime: now + RATE_LIMIT_WINDOW_MS });
    }

    // 定期清理过期记录（防止内存泄漏）
    if (rateLimitMap.size > 1000) {
      for (const [k, v] of rateLimitMap) {
        if (now >= v.resetTime) rateLimitMap.delete(k);
      }
    }
  }

  // 对所有响应添加安全头
  const res = NextResponse.next();
  addSecurityHeaders(res);

  // API 路由添加 CORS 头
  if (pathname.startsWith("/api/")) {
    res.headers.set("Access-Control-Allow-Origin", "*");
    res.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
    res.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  }

  return res;
}

function addSecurityHeaders(res: NextResponse) {
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    res.headers.set(key, value);
  }
}

// 中间件匹配路径
export const config = {
  matcher: [
    "/api/:path*",
  ],
};
