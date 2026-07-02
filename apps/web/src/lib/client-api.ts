// client-api.ts — 零依赖客户端 API 工具
// 统一 Web 页面的 fetch 错误处理，消除非 2xx 响应被强制断言为成功数据、
// 错误消息丢失、请求卸载后继续更新状态、静默失败无法重试等问题。

/**
 * ApiError — 保留 HTTP status 和服务端精确 code。
 * message 优先使用响应 JSON 的 error 字段。
 */
export class ApiError extends Error {
  readonly status: number;
  readonly code: string | null;

  constructor(status: number, code: string | null, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

/**
 * 判断是否为 AbortError（请求被主动取消）。
 */
function isAbortError(error: unknown): boolean {
  return (
    error instanceof DOMException &&
    error.name === "AbortError"
  );
}

interface ErrorResponse {
  error?: string;
  code?: string;
}

function parseErrorResponse(text: string): ErrorResponse | null {
  if (!text) return null;

  try {
    const parsed = JSON.parse(text) as unknown;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }

    const record = parsed as Record<string, unknown>;
    return {
      error: typeof record.error === "string" ? record.error : undefined,
      code: typeof record.code === "string" ? record.code : undefined,
    };
  } catch {
    return null;
  }
}

/**
 * requestJson<T> — 安全的 JSON 请求封装。
 *
 * - 仅在 response.ok 时返回 T
 * - 非 2xx 时解析现有 `{ error, code }`，抛出 ApiError
 * - 错误响应不是 JSON 时使用包含 HTTP 状态的通用消息
 * - 成功响应不是合法 JSON 时抛出明确错误
 * - 不吞掉 AbortError
 * - 不添加依赖、不设计新的服务端响应包装格式
 */
export async function requestJson<T>(
  url: string,
  init?: RequestInit,
  signal?: AbortSignal
): Promise<T> {
  const response = await fetch(url, {
    ...init,
    signal: signal ?? init?.signal,
  });

  if (!response.ok) {
    // 尝试解析错误响应 JSON
    const errorBody = parseErrorResponse(await response.text());

    const message =
      errorBody?.error ?? `请求失败（HTTP ${response.status}）`;
    const code = errorBody?.code ?? null;

    throw new ApiError(response.status, code, message);
  }

  // 成功响应：解析 JSON
  const text = await response.text();
  if (!text) {
    throw new ApiError(
      response.status,
      "EMPTY_RESPONSE",
      "服务器返回空响应"
    );
  }

  try {
    return JSON.parse(text) as T;
  } catch {
    throw new ApiError(
      response.status,
      "INVALID_JSON",
      "服务器返回了非法 JSON 响应"
    );
  }
}

/**
 * getErrorMessage — 从各种错误类型中提取用户可见消息。
 *
 * - ApiError 返回服务端消息
 * - AbortError 返回 null（不应显示为业务失败）
 * - 其他 Error 返回 message
 * - 未知错误使用调用方提供的中文回退文本
 */
export function getErrorMessage(
  error: unknown,
  fallback: string
): string | null {
  if (isAbortError(error)) {
    return null;
  }

  if (error instanceof ApiError) {
    return error.message;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return fallback;
}

/**
 * isNotFound — 判断是否为 NOT_FOUND 错误（资源不存在，应显示空态而非错误态）。
 */
export function isNotFound(error: unknown): boolean {
  return error instanceof ApiError && error.code === "NOT_FOUND";
}

/**
 * isEndpointDisabled — 判断是否为 ENDPOINT_DISABLED 错误
 *（Web 部署不保存此类数据，需引导用户在 App 中查看）。
 */
export function isEndpointDisabled(error: unknown): boolean {
  return error instanceof ApiError && error.code === "ENDPOINT_DISABLED";
}
