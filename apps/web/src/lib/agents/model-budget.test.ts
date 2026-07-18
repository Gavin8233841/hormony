import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { withModelRequestBudget } from "./model";

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("model request budget resources", () => {
  it("clears the timer and both signal listeners after success", async () => {
    const requestController = new AbortController();
    const routeController = new AbortController();
    const requestAddSpy = vi.spyOn(requestController.signal, "addEventListener");
    const requestRemoveSpy = vi.spyOn(requestController.signal, "removeEventListener");
    const routeAddSpy = vi.spyOn(routeController.signal, "addEventListener");
    const routeRemoveSpy = vi.spyOn(routeController.signal, "removeEventListener");

    const result = await withModelRequestBudget(
      async (signal) => {
        expect(signal.aborted).toBe(false);
        return "completed";
      },
      {
        timeoutMs: 100_000,
        signal: requestController.signal,
        abortSignal: routeController.signal,
      }
    );

    expect(result).toBe("completed");
    expect(vi.getTimerCount()).toBe(0);
    expect(requestAddSpy).toHaveBeenCalledWith("abort", expect.any(Function), { once: true });
    expect(requestRemoveSpy).toHaveBeenCalledWith("abort", expect.any(Function));
    expect(routeAddSpy).toHaveBeenCalledWith("abort", expect.any(Function), { once: true });
    expect(routeRemoveSpy).toHaveBeenCalledWith("abort", expect.any(Function));
  });

  it("preserves an internal route abort reason while stopping the operation", async () => {
    const routeController = new AbortController();
    const routeError = Object.assign(new Error("stream output limit"), {
      code: "OUTPUT_LIMIT_EXCEEDED",
    });
    let operationSignal: AbortSignal | undefined;
    const operation = withModelRequestBudget(
      async (signal) => {
        operationSignal = signal;
        return new Promise<never>(() => undefined);
      },
      { timeoutMs: 100_000, abortSignal: routeController.signal }
    );

    routeController.abort(routeError);

    await expect(operation).rejects.toBe(routeError);
    expect(operationSignal?.aborted).toBe(true);
    expect(operationSignal?.reason).toBe(routeError);
    expect(vi.getTimerCount()).toBe(0);
  });
});
