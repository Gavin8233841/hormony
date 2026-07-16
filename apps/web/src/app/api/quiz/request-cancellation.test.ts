import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ModelCancelledError } from "@/lib/agents/model";

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
});

afterEach(() => {
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
  vi.restoreAllMocks();
});

describe("quiz request cancellation", () => {
  it("propagates Request cancellation to Quiz Agent and preserves MODEL_CANCELLED", async () => {
    let quizSignal: AbortSignal | undefined;
    runQuizAgentMock.mockImplementation(async (
      _userId,
      _courseId,
      _topic,
      _count,
      _difficulty,
      _focusTag,
      signal
    ) => {
      quizSignal = signal;
      if (!signal) throw new Error("Quiz Agent signal missing");
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
    const responsePromise = POST(new Request("http://localhost/api/quiz", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: "demo",
        courseId: "cs101",
        topic: "二叉树与BST",
        count: 5,
        difficulty: "medium",
      }),
      signal: requestController.signal,
    }));

    await vi.waitFor(() => expect(quizSignal).toBeDefined());
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
