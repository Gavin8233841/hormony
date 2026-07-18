import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { createCompletion } = vi.hoisted(() => ({
  createCompletion: vi.fn(),
}));

vi.mock("openai", () => ({
  default: class MockOpenAI {
    chat = {
      completions: {
        create: createCompletion,
      },
    };
  },
}));

import {
  callModel,
  callModelWithHistory,
  ModelTimeoutError,
  ModelUnavailableError,
} from "./model";

const ENV_NAMES = [
  "MODEL_API_KEY",
  "MODEL_BASE_URL",
  "TEST_MODEL_RESPONSE",
  "TEST_MODEL_RESPONSE_SEQUENCE",
  "TEST_MODEL_RESPONSE_SEQUENCE_SCOPE",
] as const;
const originalEnv = new Map(ENV_NAMES.map((name) => [name, process.env[name]]));

const calls = [
  ["single-turn", () => callModel("system", "user")],
  ["with-history", () => callModelWithHistory("system", "user", [])],
] as const;

beforeEach(() => {
  process.env.MODEL_API_KEY = "model-error-test-key";
  process.env.MODEL_BASE_URL = "https://model.example/v1";
  delete process.env.TEST_MODEL_RESPONSE;
  delete process.env.TEST_MODEL_RESPONSE_SEQUENCE;
  delete process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE;
  createCompletion.mockReset();
});

afterEach(() => {
  for (const name of ENV_NAMES) restoreEnv(name, originalEnv.get(name));
});

describe("model upstream error sanitization", () => {
  it.each(calls)("removes upstream details from %s availability errors", async (_name, invoke) => {
    createCompletion.mockRejectedValueOnce(new Error("upstream-secret-sentinel"));

    const error = await invoke().catch((reason: unknown) => reason);

    expect(error).toBeInstanceOf(ModelUnavailableError);
    expect((error as Error).message).toBe("模型服务未配置或暂不可用");
    expect((error as Error).message).not.toContain("upstream-secret-sentinel");
  });

  it.each(calls)("removes upstream details from %s timeout errors", async (_name, invoke) => {
    const upstreamError = new Error("timeout at upstream-timeout-sentinel");
    upstreamError.name = "APIConnectionTimeoutError";
    createCompletion.mockRejectedValueOnce(upstreamError);

    const error = await invoke().catch((reason: unknown) => reason);

    expect(error).toBeInstanceOf(ModelTimeoutError);
    expect((error as Error).message).toBe("模型请求超时");
    expect((error as Error).message).not.toContain("upstream-timeout-sentinel");
  });
});

function restoreEnv(name: typeof ENV_NAMES[number], value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
