import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;
const RATE_LIMIT_MAX_REQUESTS = 30;
const STATEFUL_PATH = "/api/profile";
const TRUSTED_RUNTIME_IP = "203.0.113.80";

afterEach(() => {
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;

  vi.resetModules();
});

function request(method = "GET"): NextRequest {
  return new NextRequest(`http://localhost:3000${STATEFUL_PATH}`, {
    method,
    ip: TRUSTED_RUNTIME_IP,
  });
}

async function expectEndpointDisabled(response: Response): Promise<void> {
  expect(response.status).toBe(404);
  await expect(response.json()).resolves.toEqual({
    error: "该接口在无状态部署中不可用",
    code: "ENDPOINT_DISABLED",
  });
}

async function expectRateLimited(response: Response): Promise<void> {
  expect(response.status).toBe(429);
  expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
  await expect(response.json()).resolves.toEqual({
    error: "请求过于频繁，请稍后重试",
    code: "RATE_LIMITED",
  });
}

describe("middleware stateless endpoint rate limiting", () => {
  it("rate limits a trusted client after 30 disabled endpoint requests", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    vi.resetModules();
    const { middleware } = await import("./middleware");

    for (let count = 0; count < RATE_LIMIT_MAX_REQUESTS; count++) {
      await expectEndpointDisabled(middleware(request()));
    }

    await expectRateLimited(middleware(request()));
  });

  it("keeps OPTIONS free while actual disabled requests consume the window", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    vi.resetModules();
    const { middleware } = await import("./middleware");

    for (let count = 0; count <= RATE_LIMIT_MAX_REQUESTS; count++) {
      const response = middleware(request("OPTIONS"));
      expect(response.status).toBe(204);
      await expect(response.text()).resolves.toBe("");
    }

    for (let count = 0; count < RATE_LIMIT_MAX_REQUESTS; count++) {
      await expectEndpointDisabled(middleware(request()));
    }

    expect(middleware(request("OPTIONS")).status).toBe(204);
    await expectRateLimited(middleware(request()));
  });
});
