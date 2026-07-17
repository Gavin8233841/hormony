import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ModelCancelledError, ModelTimeoutError } from "@/lib/agents/model";

type RunQuizAgent = typeof import("@/lib/agents/quiz-agent").runQuizAgent;

const runQuizAgentMock = vi.hoisted(() => vi.fn<RunQuizAgent>());

vi.mock("@/lib/agents/quiz-agent", () => ({
  runQuizAgent: runQuizAgentMock,
}));

import { POST } from "./route";

const originalModelResponse = process.env.TEST_MODEL_RESPONSE;

beforeEach(() => {
  process.env.TEST_MODEL_RESPONSE = "configured-for-route-test";
  runQuizAgentMock.mockReset();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
  vi.restoreAllMocks();
});

describe("quiz request total budget", () => {
  it("aborts the Quiz Agent and returns MODEL_TIMEOUT after 100000ms", async () => {
    let quizSignal: AbortSignal | undefined;
    mockAgentUntilAborted((signal) => {
      quizSignal = signal;
    });

    const responsePromise = POST(createQuizRequest());
    await vi.advanceTimersByTimeAsync(0);
    expect(quizSignal).toBeDefined();

    await vi.advanceTimersByTimeAsync(99_999);
    expect(quizSignal?.aborted).toBe(false);

    await vi.advanceTimersByTimeAsync(1);
    expect(quizSignal?.aborted).toBe(true);

    const response = await responsePromise;
    expect(response.status).toBe(504);
    await expect(response.json()).resolves.toEqual({
      error: "模型请求超时，请稍后重试",
      code: "MODEL_TIMEOUT",
    });
  });

  it("preserves external Request cancellation as MODEL_CANCELLED", async () => {
    let quizSignal: AbortSignal | undefined;
    mockAgentUntilAborted((signal) => {
      quizSignal = signal;
    });

    const requestController = new AbortController();
    const responsePromise = POST(createQuizRequest(requestController.signal));
    await vi.advanceTimersByTimeAsync(0);
    expect(quizSignal).toBeDefined();

    requestController.abort();
    await vi.waitFor(() => expect(quizSignal?.aborted).toBe(true));

    const response = await responsePromise;
    expect(response.status).toBe(499);
    await expect(response.json()).resolves.toEqual({
      error: "模型请求已取消",
      code: "MODEL_CANCELLED",
    });
  });
});

function mockAgentUntilAborted(onSignal: (signal: AbortSignal) => void): void {
  runQuizAgentMock.mockImplementation(async (
    _userId,
    _courseId,
    _topic,
    _count,
    _difficulty,
    _focusTag,
    signal
  ) => {
    if (!signal) throw new Error("Quiz Agent signal missing");
    onSignal(signal);
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
  });
}

function createQuizRequest(signal?: AbortSignal): Request {
  return new Request("http://localhost/api/quiz", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId: "demo",
      courseId: "cs101",
      topic: "二叉树与BST",
      count: 5,
      difficulty: "medium",
    }),
    signal,
  });
}
