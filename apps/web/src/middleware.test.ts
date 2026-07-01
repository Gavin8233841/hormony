import { NextRequest } from "next/server";
import { afterEach, describe, expect, it } from "vitest";

import { middleware } from "./middleware";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;
const originalOriginAllowlist = process.env.ORIGIN_ALLOWLIST;

afterEach(() => {
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;

  if (originalOriginAllowlist === undefined) delete process.env.ORIGIN_ALLOWLIST;
  else process.env.ORIGIN_ALLOWLIST = originalOriginAllowlist;
});

function apiRequest(
  path: string,
  options: { method?: string; origin?: string; ip?: string } = {}
): NextRequest {
  const headers = new Headers();
  if (options.origin) headers.set("Origin", options.origin);
  if (options.ip) headers.set("X-Forwarded-For", options.ip);
  return new NextRequest(`http://localhost:3000${path}`, {
    method: options.method ?? "GET",
    headers,
  });
}

describe("middleware API gateway", () => {
  it("allows CORS preflight before stateless endpoint blocking", () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest("/api/profile/update", {
      method: "OPTIONS",
      origin: "http://localhost:3000",
    }));

    expect(response.status).toBe(204);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("http://localhost:3000");
    expect(response.headers.get("Access-Control-Allow-Methods")).toContain("PUT");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
  });

  it("adds readable CORS headers to stateless endpoint errors", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest("/api/profile", {
      origin: "http://localhost:3000",
    }));

    expect(response.status).toBe(404);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("http://localhost:3000");
    await expect(response.json()).resolves.toMatchObject({ code: "ENDPOINT_DISABLED" });
  });

  it("does not reflect an origin outside the allowlist", () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = middleware(apiRequest("/api/profile", {
      origin: "https://untrusted.example",
    }));

    expect(response.status).toBe(404);
    expect(response.headers.has("Access-Control-Allow-Origin")).toBe(false);
  });

  it("adds CORS and Retry-After headers to rate-limit errors", async () => {
    delete process.env.DEPLOYMENT_MODE;
    const path = `/api/rate-limit-test-${Date.now()}`;
    const options = {
      origin: "http://localhost:3000",
      ip: "198.51.100.42",
    };

    for (let index = 0; index < 30; index++) {
      expect(middleware(apiRequest(path, options)).status).toBe(200);
    }
    const response = middleware(apiRequest(path, options));

    expect(response.status).toBe(429);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("http://localhost:3000");
    expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
    await expect(response.json()).resolves.toMatchObject({ code: "RATE_LIMITED" });
  });
});
