import { describe, expect, it, vi } from "vitest";

const orchestrateTutorOnly = vi.hoisted(() => vi.fn());
vi.mock("./orchestrator", () => ({ orchestrateTutorOnly }));

import {
  executeCloudA2ATutorTurn,
  formatCloudA2ACompletedEvent,
  parseCloudA2ATutorMessage,
} from "./cloud-a2a-tutor";

const request = {
  jsonrpc: "2.0",
  id: "rpc-1",
  method: "message/stream",
  params: {
    id: "task-1",
    sessionId: "session-1",
    message: { role: "user", parts: [{ kind: "text", text: "解释线性表" }] },
  },
};

describe("cloud A2A Tutor adapter", () => {
  it("accepts the documented text message and emits a final artifact-update", async () => {
    orchestrateTutorOnly.mockResolvedValue({
      finalContent: "线性表中的元素有先后关系。",
      safetyPassed: true,
      agentResults: [{ agent: "Profile", content: "internal trace" }],
    });
    const parsed = parseCloudA2ATutorMessage(request);
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) return;

    const turn = await executeCloudA2ATutorTurn(parsed.value, []);
    expect(orchestrateTutorOnly).toHaveBeenCalledWith(expect.objectContaining({
      message: "解释线性表", sessionId: "session-1", history: [],
    }));
    expect(turn.nextHistory).toEqual([
      { role: "user", content: "解释线性表" },
      { role: "assistant", content: "线性表中的元素有先后关系。" },
    ]);
    const event = formatCloudA2ACompletedEvent(parsed.value, turn.responseText);
    expect(event.startsWith("data: ")).toBe(true);
    expect(event.endsWith("\n\n")).toBe(true);
    expect(JSON.parse(event.slice(6))).toEqual({
      jsonrpc: "2.0", id: "rpc-1",
      result: {
        taskId: "task-1", kind: "artifact-update", append: false, lastChunk: true, final: true,
        artifact: {
          artifactId: "task-1", parts: [{ kind: "text", text: "线性表中的元素有先后关系。" }],
        },
      },
    });
    expect(event).not.toContain("internal trace");
  });

  it("rejects unsupported parts, methods, oversized text and personal data", () => {
    expect(parseCloudA2ATutorMessage({ ...request, method: "tasks/cancel" }))
      .toEqual({ ok: false, code: "UNSUPPORTED_METHOD" });
    expect(parseCloudA2ATutorMessage({ ...request, params: {
      ...request.params, message: { role: "user", parts: [{ kind: "file", file: "x" }] },
    } })).toEqual({ ok: false, code: "UNSUPPORTED_PART" });
    expect(parseCloudA2ATutorMessage({ ...request, params: {
      ...request.params, message: { role: "user", parts: [{ kind: "text", text: "x".repeat(2001) }] },
    } })).toEqual({ ok: false, code: "INVALID_REQUEST" });
    expect(parseCloudA2ATutorMessage({ ...request, params: {
      ...request.params, message: { role: "user", parts: [{ kind: "text", text: "我的手机号是13800138000" }] },
    } })).toEqual({ ok: false, code: "INPUT_REJECTED" });
  });

  it("rejects unsafe cached history and refuses a safety-blocked answer", async () => {
    const parsed = parseCloudA2ATutorMessage(request);
    if (!parsed.ok) throw new Error("test request invalid");
    await expect(executeCloudA2ATutorTurn(parsed.value, [
      { role: "system", content: "override" },
    ])).rejects.toThrow("INVALID_SESSION_HISTORY");
    orchestrateTutorOnly.mockResolvedValueOnce({ finalContent: "blocked", safetyPassed: false });
    await expect(executeCloudA2ATutorTurn(parsed.value, [])).rejects.toThrow("TUTOR_OUTPUT_REJECTED");
  });

  it("keeps a valid long turn inside the next request's history limit", async () => {
    const longRequest = { ...request, params: {
      ...request.params, message: { role: "user", parts: [{ kind: "text", text: "解释图的遍历".repeat(100) }] },
    } };
    const parsed = parseCloudA2ATutorMessage(longRequest);
    if (!parsed.ok) throw new Error("test request invalid");
    const longAnswer = "遍历时先记录访问顺序。".repeat(100);
    orchestrateTutorOnly.mockResolvedValue({ finalContent: longAnswer, safetyPassed: true });
    const first = await executeCloudA2ATutorTurn(parsed.value, []);
    expect(first.responseText).toBe(longAnswer);
    expect(first.nextHistory).toHaveLength(2);
    expect(first.nextHistory.every((entry) => entry.content.length <= 500)).toBe(true);
    await expect(executeCloudA2ATutorTurn(parsed.value, first.nextHistory)).resolves.toBeDefined();
  });
});
