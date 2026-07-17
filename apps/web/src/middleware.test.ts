import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import { middleware } from "./middleware";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;
const originalOriginAllowlist = process.env.ORIGIN_ALLOWLIST;
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_KEY_CAPACITY = 1000;
const API_CACHE_CONTROL = "private, no-store";

const STATEFUL_API_PREFIXES = [
  "/api/conversations",
  "/api/courses",
  "/api/knowledge/upload",
  "/api/plan/save",
  "/api/profile",
  "/api/quiz/submit",
  "/api/stats",
] as const;

const STATELESS_API_ENDPOINTS = [
  ["GET", "/api/health"],
  ["POST", "/api/chat"],
  ["POST", "/api/plan"],
  ["POST", "/api/quiz"],
  ["POST", "/api/knowledge/search"],
] as const;

const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https: http:; frame-ancestors 'none'",
} as const;

afterEach(() => {
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;

  vi.unstubAllEnvs();

  if (originalOriginAllowlist === undefined) delete process.env.ORIGIN_ALLOWLIST;
  else process.env.ORIGIN_ALLOWLIST = originalOriginAllowlist;
});

function apiRequest(
  path: string,
  options: { method?: string; origin?: string; forwardedFor?: string; runtimeIp?: string } = {}
): NextRequest {
  const headers = new Headers();
  if (options.origin) headers.set("Origin", options.origin);
  if (options.forwardedFor) headers.set("X-Forwarded-For", options.forwardedFor);
  return new NextRequest(`http://localhost:3000${path}`, {
    method: options.method ?? "GET",
    headers,
    ip: options.runtimeIp,
  });
}

function expectSecurityHeaders(response: Response): void {
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    expect(response.headers.get(name)).toBe(value);
  }
}

function expectCorsHeaders(response: Response, origin: string): void {
  expect(response.headers.get("Access-Control-Allow-Origin")).toBe(origin);
  expect(response.headers.get("Vary")?.split(",").map((value) => value.trim())).toContain("Origin");
  expect(response.headers.get("Access-Control-Allow-Methods")).toBe("GET, POST, PUT, PATCH, DELETE, OPTIONS");
  expect(response.headers.get("Access-Control-Allow-Headers")).toBe("Content-Type, Authorization");
  expect(response.headers.get("Cache-Control")).toBe(API_CACHE_CONTROL);
}

async function expectEndpointDisabled(response: Response): Promise<void> {
  expect(response.status).toBe(404);
  expectSecurityHeaders(response);
  expectCorsHeaders(response, "http://localhost:3000");
  await expect(response.json()).resolves.toEqual({
    error: "该接口在无状态部署中不可用",
    code: "ENDPOINT_DISABLED",
  });
}

describe("middleware API gateway", () => {
  it.each(STATEFUL_API_PREFIXES)("disables the exact stateful endpoint %s", async (path) => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest(path, {
      origin: "http://localhost:3000",
    }));

    await expectEndpointDisabled(response);
  });

  it("disables stateful endpoints by default in production", async () => {
    vi.stubEnv("NODE_ENV", "production");
    delete process.env.DEPLOYMENT_MODE;

    const response = middleware(apiRequest("/api/profile", {
      origin: "http://localhost:3000",
    }));

    await expectEndpointDisabled(response);
  });

  it.each(STATEFUL_API_PREFIXES)("disables child paths below %s", async (prefix) => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest(`${prefix}/nested/resource`, {
      origin: "http://localhost:3000",
    }));

    await expectEndpointDisabled(response);
  });

  it.each(STATEFUL_API_PREFIXES)("allows CORS preflight below %s before stateless blocking", async (prefix) => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest(`${prefix}/nested/resource`, {
      method: "OPTIONS",
      origin: "http://localhost:3000",
    }));

    expect(response.status).toBe(204);
    expectSecurityHeaders(response);
    expectCorsHeaders(response, "http://localhost:3000");
    await expect(response.text()).resolves.toBe("");
  });

  it.each(STATEFUL_API_PREFIXES)("does not block a similar prefix to %s", (prefix) => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest(`${prefix}-archive`, {
      method: "POST",
      origin: "http://localhost:3000",
    }));

    expect(response.status).toBe(200);
    expect(response.headers.get("x-middleware-next")).toBe("1");
    expectSecurityHeaders(response);
    expectCorsHeaders(response, "http://localhost:3000");
  });

  it.each(STATELESS_API_ENDPOINTS)("allows %s %s to continue downstream in stateless mode", (method, path) => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest(path, {
      method,
      origin: "http://localhost:3000",
    }));

    expect(response.status).toBe(200);
    expect(response.headers.get("x-middleware-next")).toBe("1");
    expectSecurityHeaders(response);
    expectCorsHeaders(response, "http://localhost:3000");
  });

  it("does not reflect an origin outside the allowlist", () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest("/api/profile", {
      origin: "https://untrusted.example",
    }));

    expect(response.status).toBe(404);
    expect(response.headers.has("Access-Control-Allow-Origin")).toBe(false);
    expect(response.headers.get("Vary")).toBeNull();
    expect(response.headers.get("Cache-Control")).toBe(API_CACHE_CONTROL);
    expectSecurityHeaders(response);
  });

  it("prevents API response storage when the request has no Origin", () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest("/api/health"));

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe(API_CACHE_CONTROL);
    expect(response.headers.has("Access-Control-Allow-Origin")).toBe(false);
  });

  it("adds CORS and Retry-After headers to rate-limit errors", async () => {
    delete process.env.DEPLOYMENT_MODE;
    const path = `/api/rate-limit-test-${Date.now()}`;
    const options = {
      origin: "http://localhost:3000",
      forwardedFor: "198.51.100.42",
    };

    for (let index = 0; index < 30; index++) {
      expect(middleware(apiRequest(path, options)).status).toBe(200);
    }
    const response = middleware(apiRequest(path, options));

    expect(response.status).toBe(429);
    expectCorsHeaders(response, "http://localhost:3000");
    expectSecurityHeaders(response);
    expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
    await expect(response.json()).resolves.toEqual({
      error: "请求过于频繁，请稍后重试",
      code: "RATE_LIMITED",
    });
  });

  it("does not let a forged X-Forwarded-For bypass rate limiting when runtime IP is available", async () => {
    delete process.env.DEPLOYMENT_MODE;
    const path = `/api/runtime-ip-rate-limit-test-${Date.now()}`;

    for (let index = 0; index < 30; index++) {
      const response = middleware(apiRequest(path, {
        forwardedFor: `198.51.100.${index + 1}`,
        runtimeIp: "203.0.113.10",
      }));
      expect(response.status).toBe(200);
    }

    const response = middleware(apiRequest(path, {
      forwardedFor: "198.51.100.31",
      runtimeIp: "203.0.113.10",
    }));

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({
      error: "请求过于频繁，请稍后重试",
      code: "RATE_LIMITED",
    });
  });

  it("uses a shared limited bucket when only untrusted forwarded IPs are available", async () => {
    delete process.env.DEPLOYMENT_MODE;
    const path = `/api/untrusted-forwarded-rate-limit-test-${Date.now()}`;

    for (let index = 0; index < 30; index++) {
      const response = middleware(apiRequest(path, {
        forwardedFor: `198.51.100.${index + 1}`,
      }));
      expect(response.status).toBe(200);
    }

    const response = middleware(apiRequest(path, {
      forwardedFor: "198.51.100.31",
    }));

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({
      error: "请求过于频繁，请稍后重试",
      code: "RATE_LIMITED",
    });
  });

  it("bounds rate-limit keys and accepts a new key after the window expires", async () => {
    delete process.env.DEPLOYMENT_MODE;
    const baseTime = Date.now() + RATE_LIMIT_WINDOW_MS + 1;
    const runtimeIp = "203.0.113.20";
    const blockedPath = "/api/rate-limit-capacity-blocked";
    vi.resetModules();
    const { middleware: isolatedMiddleware } = await import("./middleware");
    vi.useFakeTimers();
    vi.setSystemTime(baseTime);

    try {
      for (let index = 0; index < RATE_LIMIT_KEY_CAPACITY; index++) {
        const response = isolatedMiddleware(apiRequest(`/api/rate-limit-capacity-${index}`, {
          runtimeIp,
        }));
        expect(response.status).toBe(200);
      }

      for (let count = 1; count < 30; count++) {
        const response = isolatedMiddleware(apiRequest("/api/rate-limit-capacity-0", {
          runtimeIp,
        }));
        expect(response.status).toBe(200);
      }
      expect(isolatedMiddleware(apiRequest("/api/rate-limit-capacity-0", {
        runtimeIp,
      })).status).toBe(429);

      for (let attempt = 0; attempt < 2; attempt++) {
        const response = isolatedMiddleware(apiRequest(blockedPath, {
          origin: "http://localhost:3000",
          runtimeIp,
        }));

        expect(response.status).toBe(429);
        expectCorsHeaders(response, "http://localhost:3000");
        expectSecurityHeaders(response);
        expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
        await expect(response.json()).resolves.toEqual({
          error: "请求过于频繁，请稍后重试",
          code: "RATE_LIMITED",
        });
      }

      vi.setSystemTime(baseTime + RATE_LIMIT_WINDOW_MS);
      expect(isolatedMiddleware(apiRequest(blockedPath, { runtimeIp })).status).toBe(200);
    } finally {
      vi.useRealTimers();
      vi.resetModules();
    }
  });
});
