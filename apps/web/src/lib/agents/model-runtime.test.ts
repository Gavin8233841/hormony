import { afterEach, describe, expect, it } from "vitest";

import { getModelRuntimeInfo } from "./model";

const originalModelTimeoutMs = process.env.MODEL_TIMEOUT_MS;

afterEach(() => {
  if (originalModelTimeoutMs === undefined) delete process.env.MODEL_TIMEOUT_MS;
  else process.env.MODEL_TIMEOUT_MS = originalModelTimeoutMs;
});

describe("model runtime timeout boundary", () => {
  it("uses the 45000ms default when timeout is absent", () => {
    delete process.env.MODEL_TIMEOUT_MS;

    expect(getModelRuntimeInfo().timeoutMs).toBe(45_000);
  });

  it("uses the default for values below the supported minimum", () => {
    process.env.MODEL_TIMEOUT_MS = "999";

    expect(getModelRuntimeInfo().timeoutMs).toBe(45_000);
  });

  it("caps deployment configuration at 100000ms", () => {
    process.env.MODEL_TIMEOUT_MS = "120000";

    expect(getModelRuntimeInfo().timeoutMs).toBe(100_000);
  });
});
