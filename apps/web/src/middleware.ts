// Next.js 中间件：安全头 + API 速率限制
// 适用于 App Router，在边缘运行时执行

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// 速率限制配置
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 分钟窗口
const RATE_LIMIT_MAX_REQUESTS = 30;  // 每窗口最大请求数

const STATEFUL_API_PREFIXES = [
  "/api/conversations",
  "/api/knowledge/upload",
  "/api/plan/save",
  "/api/profile",
  "/api/quiz/submit",
  "/api/stats",
];

// 内存存储（单实例够用，多实例需换 Redis）
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

// 安全响应头
const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https: http:; frame-ancestors 'none'",
};

// CORS 允许来源白名单
// 默认允许：本地开发环境 + 鸿蒙模拟器访问宿主机
// 可通过环境变量 ORIGIN_ALLOWLIST 覆盖（逗号分隔，例如 "https://a.com,https://b.com"）
const DEFAULT_ORIGIN_ALLOWLIST = [
  "http://localhost:3000", // 开发环境
  "http://10.0.2.2:3000",  // 鸿蒙模拟器访问宿主机
];

function getOriginAllowlist(): string[] {
  const raw = process.env.ORIGIN_ALLOWLIST;
  if (!raw) return DEFAULT_ORIGIN_ALLOWLIST;
  const list = raw
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  // 解析为空时回退到默认白名单，避免误配置导致全部来源被拒
  return list.length > 0 ? list : DEFAULT_ORIGIN_ALLOWLIST;
}

// 根据请求 Origin 头返回允许的来源；无 Origin 或不在白名单时返回 null
function resolveAllowedOrigin(req: NextRequest): string | null {
  const origin = req.headers.get("origin");
  if (!origin) return null;
  return getOriginAllowlist().includes(origin) ? origin : null;
}

// 为响应注入 CORS 头：仅当请求来源命中白名单时回显具体 Origin（不再使用通配符 *）
function applyCorsHeaders(res: NextResponse, req: NextRequest) {
  const origin = resolveAllowedOrigin(req);
  if (origin) {
    res.headers.set("Access-Control-Allow-Origin", origin);
    res.headers.append("Vary", "Origin");
  }
  res.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
  res.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // CORS 预检必须早于无状态接口拦截，否则受限接口会返回 404，客户端无法发起实际请求。
  if (pathname.startsWith("/api/") && req.method === "OPTIONS") {
    const res = new NextResponse(null, { status: 204 });
    addSecurityHeaders(res);
    applyCorsHeaders(res, req);
    return res;
  }

  if (
    process.env.DEPLOYMENT_MODE === "stateless" &&
    STATEFUL_API_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))
  ) {
    const res = NextResponse.json(
      { error: "该接口在无状态部署中不可用", code: "ENDPOINT_DISABLED" },
      { status: 404 }
    );
    addSecurityHeaders(res);
    applyCorsHeaders(res, req);
    return res;
  }

  // 仅对 API 路由执行速率限制
  if (pathname.startsWith("/api/")) {
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
        applyCorsHeaders(res, req);
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

  // API 路由添加 CORS 头（仅允许白名单来源）
  if (pathname.startsWith("/api/")) {
    applyCorsHeaders(res, req);
  }

  return res;
}

function addSecurityHeaders(res: NextResponse) {
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    res.headers.set(key, value);
  }
}

// 中间件匹配路径（覆盖所有路由，静态资源由 Next.js 处理）
export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico).*)",
  ],
};
