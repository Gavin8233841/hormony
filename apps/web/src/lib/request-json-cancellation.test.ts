import { describe, expect, it, vi } from "vitest";

import { readJsonObject } from "./request-json";

const encoder = new TextEncoder();

function streamRequest(
  body: ReadableStream<Uint8Array>,
  signal: AbortSignal
): Request {
  const init: RequestInit & { duplex: "half" } = {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    signal,
    duplex: "half",
  };
  return new Request("http://localhost/api/test", init);
}

async function pendingAfterMicrotasks(turns = 20): Promise<{ kind: "pending" }> {
  for (let turn = 0; turn < turns; turn++) await Promise.resolve();
  return { kind: "pending" };
}

describe("readJsonObject request cancellation", () => {
  it("cancels an unfinished body and returns BAD_REQUEST after Request.signal aborts", async () => {
    let bodyController: ReadableStreamDefaultController<Uint8Array> | undefined;
    const cancelReasons: unknown[] = [];
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        bodyController = controller;
        controller.enqueue(encoder.encode('{"message":"complete"}'));
      },
      cancel(reason) {
        cancelReasons.push(reason);
      },
    });
    const requestController = new AbortController();
    const resultPromise = readJsonObject<Record<string, unknown>>(
      streamRequest(body, requestController.signal)
    );

    requestController.abort("client disconnected");
    const outcome = await Promise.race([
      resultPromise.then((result) => ({ kind: "settled" as const, result })),
      pendingAfterMicrotasks(),
    ]);

    if (outcome.kind === "pending") {
      bodyController?.close();
      await resultPromise;
      throw new Error("readJsonObject remained pending after Request.signal was aborted");
    }

    expect(cancelReasons).toHaveLength(1);
    expect(outcome.result.ok).toBe(false);
    if (!outcome.result.ok) {
      expect(outcome.result.response.status).toBe(400);
      await expect(outcome.result.response.json()).resolves.toEqual({
        error: "无效的 JSON 请求体",
        code: "BAD_REQUEST",
      });
    }
  });

  it("removes its Request.signal abort listener after a normal JSON body completes", async () => {
    const requestController = new AbortController();
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(encoder.encode('{"message":"complete"}'));
        controller.close();
      },
    });
    const request = streamRequest(body, requestController.signal);
    const addListener = vi.spyOn(request.signal, "addEventListener");
    const removeListener = vi.spyOn(request.signal, "removeEventListener");

    try {
      const result = await readJsonObject<Record<string, unknown>>(request);

      expect(result).toEqual({ ok: true, body: { message: "complete" } });
      expect(addListener).toHaveBeenCalledTimes(1);
      expect(addListener.mock.calls[0]?.[0]).toBe("abort");
      expect(removeListener).toHaveBeenCalledTimes(1);
      expect(removeListener.mock.calls[0]?.[0]).toBe("abort");
      expect(removeListener.mock.calls[0]?.[1]).toBe(addListener.mock.calls[0]?.[1]);
    } finally {
      addListener.mockRestore();
      removeListener.mockRestore();
    }
  });
});
