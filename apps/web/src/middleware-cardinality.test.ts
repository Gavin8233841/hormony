import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

const RATE_LIMIT_MAX_REQUESTS = 30;
const RATE_LIMIT_KEY_CAPACITY = 1000;

function apiRequest(path: string): NextRequest {
  return new NextRequest(`http://localhost:3000${path}`);
}

afterEach(() => {
  vi.resetModules();
});

describe("middleware rate-limit pathname cardinality", () => {
  it("shares one bounded bucket across unknown API paths when the trusted IP is missing", async () => {
    vi.resetModules();
    const { middleware } = await import("./middleware");

    const unknownResponses = Array.from(
      { length: RATE_LIMIT_MAX_REQUESTS + 1 },
      (_, index) => middleware(apiRequest(`/api/unknown-path-${index}`))
    );
    const firstHealthResponse = middleware(apiRequest("/api/health"));

    expect(unknownResponses.slice(0, RATE_LIMIT_MAX_REQUESTS).map(({ status }) => status)).toEqual(
      Array(RATE_LIMIT_MAX_REQUESTS).fill(200)
    );
    expect(unknownResponses[RATE_LIMIT_MAX_REQUESTS].status).toBe(429);
    expect(firstHealthResponse.status).not.toBe(429);
  });

  it("does not let unknown path variants consume the capacity reserved for a valid API", async () => {
    vi.resetModules();
    const { middleware } = await import("./middleware");

    for (let index = 0; index < RATE_LIMIT_KEY_CAPACITY; index++) {
      middleware(apiRequest(`/api/unknown-capacity-path-${index}`));
    }

    const firstHealthResponse = middleware(apiRequest("/api/health"));

    expect(firstHealthResponse.status).not.toBe(429);
  });
});
