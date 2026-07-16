import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ModelCancelledError } from "@/lib/agents/model";

type RunPlannerAgent = typeof import("@/lib/agents/planner-agent").runPlannerAgent;

const runPlannerAgentMock = vi.hoisted(() => vi.fn<RunPlannerAgent>());

vi.mock("@/lib/agents/planner-agent", () => ({
  runPlannerAgent: runPlannerAgentMock,
}));

import { POST } from "./route";

const originalModelResponse = process.env.TEST_MODEL_RESPONSE;

beforeEach(() => {
  process.env.TEST_MODEL_RESPONSE = "configured-for-route-test";
  runPlannerAgentMock.mockReset();
});

afterEach(() => {
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
  vi.restoreAllMocks();
});

describe("plan request cancellation", () => {
  it("passes Request.signal to Planner and preserves MODEL_CANCELLED", async () => {
    let plannerSignal: AbortSignal | undefined;
    runPlannerAgentMock.mockImplementation(async (
      _userId,
      _goal,
      _durationDays,
      _dailyMinutes,
      _startDate,
      _profile,
      signal
    ) => {
      plannerSignal = signal;
      if (!signal) throw new Error("Planner signal missing");
      return new Promise((_resolve, reject) => {
        if (signal.aborted) {
          reject(new ModelCancelledError());
          return;
        }
        signal.addEventListener(
          "abort",
          () => reject(new ModelCancelledError()),
          { once: true }
        );
      });
    });

    const requestController = new AbortController();
    const responsePromise = POST(new Request("http://localhost/api/plan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: "demo",
        goal: "复习数据结构",
        startDate: "2032-02-29",
      }),
      signal: requestController.signal,
    }));

    await vi.waitFor(() => expect(plannerSignal).toBeDefined());
    requestController.abort();
    await vi.waitFor(() => expect(plannerSignal?.aborted).toBe(true));

    const response = await responsePromise;
    expect(response.status).toBe(499);
    await expect(response.json()).resolves.toEqual({
      error: "模型请求已取消",
      code: "MODEL_CANCELLED",
    });
  });
});
