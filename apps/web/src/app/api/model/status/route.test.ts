import { afterEach, describe, expect, it } from "vitest";

import { GET } from "./route";

const originalModelApiKey = process.env.MODEL_API_KEY;
const originalModelBaseUrl = process.env.MODEL_BASE_URL;

afterEach(() => {
  restoreEnv("MODEL_API_KEY", originalModelApiKey);
  restoreEnv("MODEL_BASE_URL", originalModelBaseUrl);
});

describe("GET /api/model/status public contract", () => {
  it("does not expose the configured upstream URL or embedded credentials", async () => {
    process.env.MODEL_API_KEY = "status-" + "api-key-sentinel";
    process.env.MODEL_BASE_URL =
      "https://status-user:status-password@model.example/v1?token=status-query#status-fragment";

    const response = await GET();
    const rawBody = await response.text();
    const body = JSON.parse(rawBody) as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toEqual(expect.objectContaining({
      configured: true,
      mode: "model",
      provider: "openai-compatible",
      modelName: expect.any(String),
      timeoutMs: expect.any(Number),
    }));
    expect(Object.keys(body).sort()).toEqual([
      "configured",
      "mode",
      "modelName",
      "provider",
      "timeoutMs",
    ]);
    expect(body).not.toHaveProperty("baseURL");
    for (const secret of [
      "status-api-key-sentinel",
      "status-user",
      "status-password",
      "status-query",
      "status-fragment",
    ]) {
      expect(rawBody).not.toContain(secret);
    }
  });
});

function restoreEnv(name: "MODEL_API_KEY" | "MODEL_BASE_URL", value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
