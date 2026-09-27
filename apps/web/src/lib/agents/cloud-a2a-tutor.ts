// 小艺云 A2A 的文本讲解适配。协议输入/输出与业务编排分开，
// 公网路由必须先补齐平台鉴权、跨请求会话、取消及共享成本控制。
import { orchestrateTutorOnly } from "./orchestrator";
import { validateUserInput } from "./safety-agent";
import type { ChatMessage } from "@/lib/types";

const MAX_REQUEST_ID_LENGTH = 128;
const MAX_SESSION_ID_LENGTH = 128;
const MAX_TASK_ID_LENGTH = 128;
const MAX_MESSAGE_LENGTH = 2000;

type JsonObject = Record<string, unknown>;

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validId(value: unknown, maxLength: number): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength;
}

export interface CloudA2ATutorMessage {
  requestId: string;
  taskId: string;
  sessionId: string;
  text: string;
}

export type CloudA2AParseResult =
  | { ok: true; value: CloudA2ATutorMessage }
  | { ok: false; code: "INVALID_REQUEST" | "UNSUPPORTED_METHOD" | "UNSUPPORTED_PART" | "INPUT_REJECTED" };

/** Only the documented text form of message/stream is accepted for the first Tutor capability. */
export function parseCloudA2ATutorMessage(body: unknown): CloudA2AParseResult {
  if (!isObject(body) || body.jsonrpc !== "2.0" ||
      !validId(body.id, MAX_REQUEST_ID_LENGTH)) {
    return { ok: false, code: "INVALID_REQUEST" };
  }
  if (body.method !== "message/stream") {
    return { ok: false, code: "UNSUPPORTED_METHOD" };
  }
  const params = body.params;
  if (!isObject(params) || !validId(params.id, MAX_TASK_ID_LENGTH) ||
      !validId(params.sessionId, MAX_SESSION_ID_LENGTH) || !isObject(params.message) ||
      params.message.role !== "user" || !Array.isArray(params.message.parts) ||
      params.message.parts.length !== 1) {
    return { ok: false, code: "INVALID_REQUEST" };
  }
  const part: unknown = params.message.parts[0];
  if (!isObject(part) || part.kind !== "text" || typeof part.text !== "string") {
    return { ok: false, code: "UNSUPPORTED_PART" };
  }
  const text = part.text.trim();
  if (text.length === 0 || text.length > MAX_MESSAGE_LENGTH) {
    return { ok: false, code: "INVALID_REQUEST" };
  }
  if (validateUserInput(text).length > 0) {
    return { ok: false, code: "INPUT_REJECTED" };
  }
  return { ok: true, value: {
    requestId: body.id, taskId: params.id, sessionId: params.sessionId, text,
  } };
}

export interface CloudA2ATutorTurn {
  responseText: string;
  nextHistory: ChatMessage[];
}

/** The caller owns durable history keyed by a verified caller identity plus sessionId. */
export async function executeCloudA2ATutorTurn(
  message: CloudA2ATutorMessage,
  history: ChatMessage[],
): Promise<CloudA2ATutorTurn> {
  if (history.length > 12 || history.some((entry) =>
    (entry.role !== "user" && entry.role !== "assistant") ||
    typeof entry.content !== "string" || entry.content.length > 500 ||
    validateUserInput(entry.content).length > 0
  )) {
    throw new Error("INVALID_SESSION_HISTORY");
  }
  const result = await orchestrateTutorOnly({
    userId: "xiaoyi_guest",
    message: message.text,
    startDate: new Date().toISOString().slice(0, 10),
    sessionId: message.sessionId,
    history,
  });
  if (!result.safetyPassed) {
    throw new Error("TUTOR_OUTPUT_REJECTED");
  }
  const appendedHistory: ChatMessage[] = [
      ...history,
      { role: "user", content: message.text },
      { role: "assistant", content: result.finalContent },
    ];
  const nextHistory = appendedHistory.slice(-12);
  return { responseText: result.finalContent, nextHistory };
}

/** Minimal documented JSON-RPC SSE terminal answer; internal traces never leave the adapter. */
export function formatCloudA2ACompletedEvent(message: CloudA2ATutorMessage, responseText: string): string {
  const payload = {
    jsonrpc: "2.0",
    id: message.requestId,
    result: {
      taskId: message.taskId,
      kind: "artifact-update",
      append: false,
      lastChunk: true,
      final: true,
      artifact: {
        artifactId: message.taskId,
        parts: [{ kind: "text", text: responseText }],
      },
    },
  };
  return `data: ${JSON.stringify(payload)}\n\n`;
}
