import type { AgentName, Citation, StreamEvent } from "@/lib/types";

type StreamErrorEvent = Extract<StreamEvent, { type: "error" }>;

const MAX_CHAT_HISTORY_MESSAGES = 12;
const MAX_CHAT_HISTORY_CONTENT_LENGTH = 1000;

export interface ChatHistoryMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ChatStreamResult {
  error: StreamErrorEvent | null;
  sessionId: string | null;
}

export class ChatStreamProtocolError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ChatStreamProtocolError";
  }
}

export class ChatRequestError extends Error {
  readonly status: number;
  readonly code: string | null;

  constructor(status: number, code: string | null, message: string) {
    super(message);
    this.name = "ChatRequestError";
    this.status = status;
    this.code = code;
  }
}

export class ChatRequestCoordinator {
  private current: AbortController | null = null;

  start(): AbortController {
    const next = new AbortController();
    const previous = this.current;
    this.current = next;
    previous?.abort("superseded");
    return next;
  }

  isCurrent(controller: AbortController): boolean {
    return this.current === controller;
  }

  stop(reason = "stopped"): AbortController | null {
    const controller = this.current;
    if (!controller) return null;
    this.current = null;
    controller.abort(reason);
    return controller;
  }

  finish(controller: AbortController): boolean {
    if (this.current !== controller) return false;
    this.current = null;
    return true;
  }
}

export function buildChatHistory(
  messages: readonly ChatHistoryMessage[]
): ChatHistoryMessage[] {
  return messages.slice(-MAX_CHAT_HISTORY_MESSAGES).map((message) => ({
    role: message.role,
    content: message.content.slice(0, MAX_CHAT_HISTORY_CONTENT_LENGTH),
  }));
}

const AGENT_NAMES: readonly AgentName[] = [
  "Profile",
  "Retrieval",
  "Planner",
  "Tutor",
  "Quiz",
  "Evaluator",
  "Safety",
];

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isAgentName(value: unknown): value is AgentName {
  return typeof value === "string" && AGENT_NAMES.some((name) => name === value);
}

function readCitation(value: unknown): Citation | null {
  if (!isRecord(value) || typeof value.doc !== "string") return null;
  if (value.page !== undefined && typeof value.page !== "number") return null;
  if (value.snippet !== undefined && typeof value.snippet !== "string") return null;

  return {
    doc: value.doc,
    page: value.page as number | undefined,
    snippet: value.snippet as string | undefined,
  };
}

function parseStreamEvent(payload: string): StreamEvent {
  let parsed: unknown;
  try {
    parsed = JSON.parse(payload) as unknown;
  } catch {
    throw new ChatStreamProtocolError("流式响应包含无法解析的 JSON 事件");
  }

  if (!isRecord(parsed) || typeof parsed.type !== "string") {
    throw new ChatStreamProtocolError("流式响应事件结构无效");
  }

  switch (parsed.type) {
    case "thinking":
      if (isAgentName(parsed.agent)) return { type: "thinking", agent: parsed.agent };
      break;
    case "delta":
      if (typeof parsed.content === "string") return { type: "delta", content: parsed.content };
      break;
    case "citation": {
      const source = readCitation(parsed.source);
      if (source) return { type: "citation", source };
      break;
    }
    case "trace":
      if (isAgentName(parsed.agent) && typeof parsed.content === "string") {
        return { type: "trace", agent: parsed.agent, content: parsed.content };
      }
      break;
    case "error":
      if (typeof parsed.code === "string" && typeof parsed.message === "string") {
        return { type: "error", code: parsed.code, message: parsed.message };
      }
      break;
    case "done":
      if (typeof parsed.sessionId === "string") {
        return { type: "done", sessionId: parsed.sessionId };
      }
      break;
  }

  throw new ChatStreamProtocolError(`流式响应事件 ${parsed.type} 的字段无效`);
}

function parseFrames(input: string, flush: boolean): { events: StreamEvent[]; remainder: string } {
  const normalized = input.replace(/\r\n/g, "\n");
  const frames = normalized.split("\n\n");
  const remainder = flush ? "" : (frames.pop() ?? "");
  const events: StreamEvent[] = [];

  for (const frame of frames) {
    if (!frame.trim()) continue;
    const dataLines = frame
      .split("\n")
      .filter((line) => line === "data:" || line.startsWith("data: "));
    if (dataLines.length === 0) continue;
    const payload = dataLines
      .map((line) => line === "data:" ? "" : line.slice(6))
      .join("\n")
      .trim();
    if (!payload) continue;
    events.push(parseStreamEvent(payload));
  }

  return { events, remainder };
}

export async function consumeChatEventStream(
  body: ReadableStream<Uint8Array> | null,
  onEvent: (event: StreamEvent) => void,
): Promise<ChatStreamResult> {
  if (!body) {
    throw new ChatStreamProtocolError("服务器未返回流式响应正文");
  }

  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let doneEventSeen = false;
  let streamError: StreamErrorEvent | null = null;
  let sessionId: string | null = null;

  const dispatch = (events: StreamEvent[]) => {
    for (const event of events) {
      if (doneEventSeen) {
        throw new ChatStreamProtocolError("流式响应在 done 事件后仍包含数据");
      }
      if (streamError && event.type !== "done") {
        throw new ChatStreamProtocolError("流式响应在 error 事件后未立即结束");
      }
      if (event.type === "error") {
        if (streamError) {
          throw new ChatStreamProtocolError("流式响应包含重复的 error 事件");
        }
        streamError = event;
      } else if (event.type === "done") {
        doneEventSeen = true;
        sessionId = streamError ? null : event.sessionId;
      }
      onEvent(event);
    }
  };

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const parsed = parseFrames(buffer, false);
      buffer = parsed.remainder;
      dispatch(parsed.events);
    }

    buffer += decoder.decode();
    const final = parseFrames(buffer, true);
    dispatch(final.events);

    if (!doneEventSeen) {
      throw new ChatStreamProtocolError("流式响应在收到 done 事件前已结束");
    }

    return { error: streamError, sessionId };
  } catch (error) {
    try {
      await reader.cancel(error);
    } catch {
      // Reader may already be closed by the server or caller cancellation.
    }
    throw error;
  } finally {
    reader.releaseLock();
  }
}

export async function readChatRequestError(response: Response): Promise<ChatRequestError> {
  const text = await response.text();
  let code: string | null = null;
  let message = `请求失败（HTTP ${response.status}）`;

  if (text) {
    try {
      const parsed = JSON.parse(text) as unknown;
      if (isRecord(parsed)) {
        if (typeof parsed.code === "string") code = parsed.code;
        if (typeof parsed.error === "string") message = parsed.error;
      }
    } catch {
      // 非 JSON 错误响应使用包含 HTTP 状态的通用消息。
    }
  }

  return new ChatRequestError(response.status, code, message);
}
