import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ModelCancelledError } from "@/lib/agents/model";
import type { ChatRequest, StreamEvent } from "@/lib/types";

const orchestrateStreamMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/agents/orchestrator", () => ({
  orchestrateStream: orchestrateStreamMock,
}));

import { POST } from "./route";

const originalTestModelResponse = process.env.TEST_MODEL_RESPONSE;

type Emit = (event: StreamEvent) => void;

beforeEach(() => {
  process.env.TEST_MODEL_RESPONSE = "configured-for-route-test";
  orchestrateStreamMock.mockReset();
  vi.spyOn(console, "error").mockImplementation(() => undefined);
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  if (originalTestModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalTestModelResponse;
  vi.restoreAllMocks();
});

describe("chat request total budget", () => {
  it("returns HTTP 504 when the budget expires before the first SSE event", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestrationUntilAborted((signal) => {
      orchestrationSignal = signal;
    }, false);

    const requestController = new AbortController();
    const responsePromise = POST(chatRequest(requestController.signal));
    await vi.advanceTimersByTimeAsync(0);
    expect(orchestrationSignal).toBeDefined();

    await vi.advanceTimersByTimeAsync(100_000);
    expect(orchestrationSignal?.aborted).toBe(true);

    const response = await responsePromise;
    expect(response.status).toBe(504);
    await expect(response.json()).resolves.toEqual({
      error: "模型请求超时，请稍后重试",
      code: "MODEL_TIMEOUT",
    });
  });

  it("aborts orchestration at 100000ms and terminates SSE once with MODEL_TIMEOUT", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestrationUntilAborted((signal) => {
      orchestrationSignal = signal;
    });

    const requestController = new AbortController();
    const response = await POST(chatRequest(requestController.signal));

    try {
      expect(response.status).toBe(200);
      expect(orchestrationSignal).toBeDefined();

      await vi.advanceTimersByTimeAsync(99_999);
      expect(orchestrationSignal?.aborted).toBe(false);

      await vi.advanceTimersByTimeAsync(1);
      expect(orchestrationSignal?.aborted).toBe(true);

      const events = await readEvents(response);
      expect(events).toEqual([
        { type: "thinking", agent: "Tutor" },
        {
          type: "error",
          code: "MODEL_TIMEOUT",
          message: "模型请求超时，请稍后重试",
        },
        { type: "done", sessionId: "error" },
      ]);
      expect(events.filter((event) => event.type === "error")).toHaveLength(1);
      expect(events.filter((event) => event.type === "done")).toHaveLength(1);
    } finally {
      if (!orchestrationSignal?.aborted) requestController.abort("test cleanup");
      await vi.advanceTimersByTimeAsync(0);
      if (!response.bodyUsed) await response.body?.cancel("test cleanup");
    }
  });

  it("does not append error or done when the external Request is aborted", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestrationUntilAborted((signal) => {
      orchestrationSignal = signal;
    });

    const requestController = new AbortController();
    const response = await POST(chatRequest(requestController.signal));

    expect(response.status).toBe(200);
    expect(orchestrationSignal).toBeDefined();

    requestController.abort("client disconnected");
    expect(orchestrationSignal?.aborted).toBe(true);
    await vi.advanceTimersByTimeAsync(0);

    await expect(readEvents(response)).resolves.toEqual([
      { type: "thinking", agent: "Tutor" },
    ]);
  });
});

function mockOrchestrationUntilAborted(
  onSignal: (signal: AbortSignal) => void,
  emitThinking = true
): void {
  orchestrateStreamMock.mockImplementation(async (
    _request: ChatRequest,
    emit: Emit,
    signal?: AbortSignal
  ) => {
    if (!signal) throw new Error("Chat orchestration signal missing");
    onSignal(signal);
    if (emitThinking) emit({ type: "thinking", agent: "Tutor" });
    await new Promise<void>((_resolve, reject) => {
      const rejectForAbort = () => {
        reject(
          signal.reason instanceof Error
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

function chatRequest(signal: AbortSignal): NextRequest {
  return new NextRequest("http://localhost/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userId: "demo", message: "解释二叉树" }),
    signal,
  });
}

async function readEvents(response: Response): Promise<StreamEvent[]> {
  const text = await response.text();
  return text
    .split("\n\n")
    .filter((frame) => frame.startsWith("data: "))
    .map((frame) => JSON.parse(frame.slice(6)) as StreamEvent);
}
