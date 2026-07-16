import { describe, expect, it } from "vitest";
import type { StreamEvent } from "@/lib/types";
import {
  buildChatHistory,
  ChatRequestCoordinator,
  ChatRequestError,
  ChatStreamProtocolError,
  consumeChatEventStream,
  readChatRequestError,
} from "./sse-client";

describe("chat request contract", () => {
  it("只发送最后十二条历史且逐条截到一千字符", () => {
    const history = buildChatHistory(
      Array.from({ length: 14 }, (_, index) => ({
        role: index % 2 === 0 ? "user" as const : "assistant" as const,
        content: `${index}:` + "历".repeat(1200),
      }))
    );

    expect(history).toHaveLength(12);
    expect(history[0].content.startsWith("2:")).toBe(true);
    expect(history.every((message) => message.content.length <= 1000)).toBe(true);
    expect(history[11].content.startsWith("13:")).toBe(true);
  });

  it("旧请求的结束回调不能清除停止后启动的新控制器", () => {
    const coordinator = new ChatRequestCoordinator();
    const first = coordinator.start();

    expect(coordinator.stop()).toBe(first);
    expect(first.signal.aborted).toBe(true);
    expect(coordinator.isCurrent(first)).toBe(false);

    const second = coordinator.start();
    expect(coordinator.isCurrent(first)).toBe(false);
    expect(coordinator.finish(first)).toBe(false);
    expect(coordinator.isCurrent(second)).toBe(true);
    expect(coordinator.finish(second)).toBe(true);
  });
});

function streamFrom(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
      controller.close();
    },
  });
}

describe("consumeChatEventStream", () => {
  it("按服务端顺序消费跨分块事件并返回会话 ID", async () => {
    const events: StreamEvent[] = [];
    const result = await consumeChatEventStream(
      streamFrom([
        'data: {"type":"thinking","agent":"Tutor"}\n\ndata: {"type":"del',
        'ta","content":"二叉树"}\n\ndata: {"type":"done","sessionId":"session-1"}\n\n',
      ]),
      (event) => events.push(event),
    );

    expect(events.map((event) => event.type)).toEqual(["thinking", "delta", "done"]);
    expect(result).toEqual({ error: null, sessionId: "session-1" });
  });

  it("保留 SSE error 的精确 code/message，且不采用随后 done 的会话 ID", async () => {
    const events: StreamEvent[] = [];
    const result = await consumeChatEventStream(
      streamFrom([
        'data: {"type":"thinking","agent":"Safety"}\n\n',
        'data: {"type":"error","code":"SAFETY_BLOCKED","message":"本次回答未通过安全检查"}\n\n',
        'data: {"type":"done","sessionId":"session-should-not-be-used"}\n\n',
      ]),
      (event) => events.push(event),
    );

    expect(events.map((event) => event.type)).toEqual(["thinking", "error", "done"]);
    expect(result).toEqual({
      error: {
        type: "error",
        code: "SAFETY_BLOCKED",
        message: "本次回答未通过安全检查",
      },
      sessionId: null,
    });
  });

  it("拒绝缺少 done 边界的响应", async () => {
    await expect(
      consumeChatEventStream(
        streamFrom(['data: {"type":"delta","content":"未完成"}\n\n']),
        () => undefined,
      ),
    ).rejects.toThrow(ChatStreamProtocolError);
  });

  it("拒绝字段不完整的 error 事件", async () => {
    await expect(
      consumeChatEventStream(
        streamFrom(['data: {"type":"error","message":"缺少 code"}\n\n']),
        () => undefined,
      ),
    ).rejects.toThrow("error 的字段无效");
  });

  it("协议错误时取消仍在发送的响应流", async () => {
    const encoder = new TextEncoder();
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(encoder.encode('data: {"type":"unknown"}\n\n'));
      },
      cancel() {
        cancelled = true;
      },
    });

    await expect(consumeChatEventStream(stream, () => undefined)).rejects.toThrow(
      ChatStreamProtocolError,
    );
    expect(cancelled).toBe(true);
  });
});

describe("readChatRequestError", () => {
  it("保留非 2xx JSON 响应的 HTTP 状态与精确错误码", async () => {
    const response = new Response(
      JSON.stringify({ error: "云端学伴暂不可用", code: "MODEL_UNAVAILABLE" }),
      { status: 503 },
    );

    const error = await readChatRequestError(response);

    expect(error).toBeInstanceOf(ChatRequestError);
    expect(error.status).toBe(503);
    expect(error.code).toBe("MODEL_UNAVAILABLE");
    expect(error.message).toBe("云端学伴暂不可用");
  });
});
