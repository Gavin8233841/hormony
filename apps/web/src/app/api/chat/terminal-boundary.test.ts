import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { ChatRequest, StreamEvent } from "@/lib/types";

const orchestrateStreamMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/agents/orchestrator", () => ({
  orchestrateStream: orchestrateStreamMock,
}));

import { POST } from "./route";

const originalTestModelResponse = process.env.TEST_MODEL_RESPONSE;

beforeEach(() => {
  process.env.TEST_MODEL_RESPONSE = "configured-for-route-test";
  orchestrateStreamMock.mockReset();
  vi.spyOn(console, "error").mockImplementation(() => undefined);
});

afterEach(() => {
  if (originalTestModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalTestModelResponse;
  vi.restoreAllMocks();
});

function chatRequest(): NextRequest {
  return new NextRequest("http://localhost/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userId: "demo", message: "解释二叉树" }),
  });
}

async function readEvents(response: Response): Promise<StreamEvent[]> {
  const text = await response.text();
  return text
    .split("\n\n")
    .filter((frame) => frame.startsWith("data: "))
    .map((frame) => JSON.parse(frame.slice(6)) as StreamEvent);
}

describe("chat SSE terminal boundary", () => {
  it("does not append an error or another done after orchestration emitted done", async () => {
    orchestrateStreamMock.mockImplementation(
      async (_request: ChatRequest, emit: (event: StreamEvent) => void) => {
        emit({ type: "done", sessionId: "session-complete" });
        throw new Error("late orchestration failure");
      },
    );

    const response = await POST(chatRequest());

    expect(response.status).toBe(200);
    await expect(readEvents(response)).resolves.toEqual([
      { type: "done", sessionId: "session-complete" },
    ]);
  });

  it("ignores orchestration events emitted after done", async () => {
    orchestrateStreamMock.mockImplementation(
      async (_request: ChatRequest, emit: (event: StreamEvent) => void) => {
        emit({ type: "done", sessionId: "session-complete" });
        emit({ type: "delta", content: "late output" });
        emit({ type: "done", sessionId: "duplicate-terminal" });
      },
    );

    const response = await POST(chatRequest());

    expect(response.status).toBe(200);
    await expect(readEvents(response)).resolves.toEqual([
      { type: "done", sessionId: "session-complete" },
    ]);
  });

  it("preserves error then done as the only terminal sequence after a late throw", async () => {
    orchestrateStreamMock.mockImplementation(
      async (_request: ChatRequest, emit: (event: StreamEvent) => void) => {
        emit({ type: "error", code: "SAFETY_BLOCKED", message: "输出内容不符合安全要求" });
        emit({ type: "done", sessionId: "blocked" });
        throw new Error("late cleanup failure");
      },
    );

    const response = await POST(chatRequest());

    expect(response.status).toBe(200);
    await expect(readEvents(response)).resolves.toEqual([
      { type: "error", code: "SAFETY_BLOCKED", message: "输出内容不符合安全要求" },
      { type: "done", sessionId: "blocked" },
    ]);
  });
});
