import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { ChatRequest, StreamEvent } from "@/lib/types";

const orchestrateStreamMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/agents/orchestrator", () => ({
  orchestrateStream: orchestrateStreamMock,
}));

import { POST } from "./route";

const originalTestModelResponse = process.env.TEST_MODEL_RESPONSE;
// Production model calls cap output at 2048 tokens; Tutor currently emits at most
// 12 events including the retrieval agent's three-citation maximum.
const MAX_SSE_EVENT_BYTES = 64 * 1024;
const MAX_SSE_TOTAL_BYTES = 512 * 1024;
const MAX_SSE_EVENTS = 128;

type Emit = (event: StreamEvent) => void;

beforeEach(() => {
  process.env.TEST_MODEL_RESPONSE = "configured-for-route-test";
  orchestrateStreamMock.mockReset();
});

afterEach(() => {
  if (originalTestModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalTestModelResponse;
  vi.restoreAllMocks();
});

function chatRequest(signal?: AbortSignal): NextRequest {
  return new NextRequest("http://localhost/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userId: "demo", message: "解释二叉树" }),
    signal,
  });
}

async function readEvents(response: Response): Promise<{
  bytes: number;
  events: StreamEvent[];
}> {
  const text = await response.text();
  const events = text
    .split("\n\n")
    .filter((frame) => frame.startsWith("data: "))
    .map((frame) => JSON.parse(frame.slice(6)) as StreamEvent);
  return {
    bytes: new TextEncoder().encode(text).byteLength,
    events,
  };
}

function mockOrchestration(
  implementation: (
    request: ChatRequest,
    emit: Emit,
    signal?: AbortSignal
  ) => Promise<void>
): void {
  orchestrateStreamMock.mockImplementation(implementation);
}

function expectLimitTermination(events: StreamEvent[]): void {
  expect(events.slice(-2)).toEqual([
    {
      type: "error",
      code: "OUTPUT_LIMIT_EXCEEDED",
      message: "模型输出超过流式响应限制，请缩短问题后重试",
    },
    { type: "done", sessionId: "error" },
  ]);
}

describe("chat SSE cancellation", () => {
  it("propagates Request.signal cancellation to orchestration", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestration(async (_request, emit, signal) => {
      orchestrationSignal = signal;
      emit({ type: "thinking", agent: "Tutor" });
      await new Promise<void>((resolve) => {
        if (signal?.aborted) {
          resolve();
          return;
        }
        signal?.addEventListener("abort", () => resolve(), { once: true });
      });
      emit({ type: "delta", content: "请求取消后不应继续写入" });
    });

    const requestController = new AbortController();
    const response = await POST(chatRequest(requestController.signal));
    requestController.abort();

    try {
      await vi.waitFor(() => expect(orchestrationSignal?.aborted).toBe(true));
      const { events } = await readEvents(response);
      expect(events).toEqual([{ type: "thinking", agent: "Tutor" }]);
    } finally {
      if (!orchestrationSignal?.aborted) await response.body?.cancel();
    }
  });

  it("removes the Request.signal listener after orchestration completes", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestration(async (_request, emit, signal) => {
      orchestrationSignal = signal;
      emit({ type: "thinking", agent: "Tutor" });
      emit({ type: "done", sessionId: "session-complete" });
    });

    const requestController = new AbortController();
    const response = await POST(chatRequest(requestController.signal));
    await readEvents(response);
    requestController.abort();

    expect(orchestrationSignal?.aborted).toBe(false);
  });

  it("aborts orchestration when the response reader disconnects", async () => {
    let orchestrationSignal: AbortSignal | undefined;
    mockOrchestration(async (_request, emit, signal) => {
      orchestrationSignal = signal;
      emit({ type: "thinking", agent: "Tutor" });
      await new Promise<void>((resolve) => {
        if (signal?.aborted) {
          resolve();
          return;
        }
        signal?.addEventListener("abort", () => resolve(), { once: true });
      });
      emit({ type: "delta", content: "取消后不应继续写入" });
    });

    const response = await POST(chatRequest());
    const reader = response.body?.getReader();
    expect(reader).toBeDefined();
    await reader?.read();
    await reader?.cancel("client disconnected");

    await vi.waitFor(() => expect(orchestrationSignal?.aborted).toBe(true));
  });
});

describe("chat SSE resource limits", () => {
  it("preserves the normal event order below every limit", async () => {
    mockOrchestration(async (_request, emit) => {
      emit({ type: "thinking", agent: "Tutor" });
      emit({ type: "delta", content: "二叉树讲解" });
      emit({ type: "done", sessionId: "session-normal" });
    });

    const response = await POST(chatRequest());
    const { events } = await readEvents(response);

    expect(events).toEqual([
      { type: "thinking", agent: "Tutor" },
      { type: "delta", content: "二叉树讲解" },
      { type: "done", sessionId: "session-normal" },
    ]);
  });

  it("rejects a single SSE event above 64 KiB and then emits done", async () => {
    mockOrchestration(async (_request, emit) => {
      emit({ type: "thinking", agent: "Tutor" });
      emit({ type: "delta", content: "x".repeat(MAX_SSE_EVENT_BYTES) });
      emit({ type: "done", sessionId: "session-too-large" });
    });

    const response = await POST(chatRequest());
    const { bytes, events } = await readEvents(response);

    expect(bytes).toBeLessThanOrEqual(MAX_SSE_TOTAL_BYTES);
    expectLimitTermination(events);
  });

  it("caps every SSE response at 128 events including error and done", async () => {
    mockOrchestration(async (_request, emit) => {
      emit({ type: "thinking", agent: "Tutor" });
      for (let index = 0; index < MAX_SSE_EVENTS + 20; index += 1) {
        emit({ type: "trace", agent: "Tutor", content: `step-${index}` });
      }
      emit({ type: "done", sessionId: "session-too-many-events" });
    });

    const response = await POST(chatRequest());
    const { events } = await readEvents(response);

    expect(events.length).toBeLessThanOrEqual(MAX_SSE_EVENTS);
    expectLimitTermination(events);
  });

  it("caps total encoded SSE output at 512 KiB including error and done", async () => {
    mockOrchestration(async (_request, emit) => {
      emit({ type: "thinking", agent: "Tutor" });
      for (let index = 0; index < 80; index += 1) {
        emit({ type: "delta", content: `${index}:${"x".repeat(8 * 1024)}` });
      }
      emit({ type: "done", sessionId: "session-too-many-bytes" });
    });

    const response = await POST(chatRequest());
    const { bytes, events } = await readEvents(response);

    expect(bytes).toBeLessThanOrEqual(MAX_SSE_TOTAL_BYTES);
    expectLimitTermination(events);
  });
});
