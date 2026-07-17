import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ModelCancelledError, ModelTimeoutError } from "@/lib/agents/model";
import type { StudyPlan } from "@/lib/types";

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
  vi.spyOn(console, "error").mockImplementation(() => undefined);
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
  vi.restoreAllMocks();
});

describe("plan request total budget", () => {
  it("aborts Planner and returns MODEL_TIMEOUT after 100000ms", async () => {
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
      if (!signal) throw new Error("Planner signal missing");
      plannerSignal = signal;
      return rejectWhenAborted(signal);
    });

    const responsePromise = POST(createPlanRequest());
    await vi.advanceTimersByTimeAsync(0);
    expect(plannerSignal).toBeDefined();

    await vi.advanceTimersByTimeAsync(99_999);
    expect(plannerSignal?.aborted).toBe(false);

    await vi.advanceTimersByTimeAsync(1);
    expect(plannerSignal?.aborted).toBe(true);

    const response = await responsePromise;
    expect(response.status).toBe(504);
    await expect(response.json()).resolves.toEqual({
      error: "模型请求超时，请稍后重试",
      code: "MODEL_TIMEOUT",
    });
  });

  it("clears the deadline timer and Request listener after success", async () => {
    const request = createPlanRequest();
    const addListenerSpy = vi.spyOn(request.signal, "addEventListener");
    const removeListenerSpy = vi.spyOn(request.signal, "removeEventListener");
    runPlannerAgentMock.mockResolvedValue(planResult());

    const response = await POST(request);

    expect(response.status).toBe(200);
    expect(vi.getTimerCount()).toBe(0);
    expect(addListenerSpy).toHaveBeenCalledWith("abort", expect.any(Function), { once: true });
    expect(removeListenerSpy).toHaveBeenCalledWith("abort", expect.any(Function));
  });
});

function createPlanRequest(): Request {
  return new Request("http://localhost/api/plan", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId: "demo",
      goal: "复习数据结构",
      durationDays: 14,
      dailyMinutes: 90,
      startDate: "2032-02-29",
    }),
  });
}

function rejectWhenAborted(signal: AbortSignal): Promise<never> {
  return new Promise((_resolve, reject) => {
    const rejectForAbort = () => {
      reject(
        signal.reason instanceof ModelTimeoutError
          ? signal.reason
          : new ModelCancelledError()
      );
    };
    if (signal.aborted) {
      rejectForAbort();
      return;
    }
    signal.addEventListener("abort", rejectForAbort, { once: true });
  });
}

function planResult(): StudyPlan {
  return {
    planId: "plan_budget_test",
    userId: "demo",
    goal: "复习数据结构",
    tasks: [{
      id: "task_budget_test",
      title: "复习二叉树",
      date: "2032-02-29",
      estimatedMin: 45,
      type: "review",
      courseId: "cs101",
      topic: "二叉树与BST",
    }],
  };
}
