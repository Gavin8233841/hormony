// 模型客户端：OpenAI 兼容接口。生产路径不提供伪造模型回退。

import OpenAI from "openai";
import type { ChatCompletionCreateParamsNonStreaming } from "openai/resources/chat/completions";

const DEFAULT_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3";
const DEFAULT_MODEL_NAME = "doubao-seed-2-1-pro-260628";
const DEFAULT_TIMEOUT_MS = 45000;
const MAX_TIMEOUT_MS = 100000;
const MODEL_API_KEY_PLACEHOLDERS = new Set([
  "your-api-key-here",
  "<在本机手动填入>",
]);

export interface ModelRuntimeInfo {
  configured: boolean;
  mode: "model" | "unavailable";
  provider: "openai-compatible";
  baseURL: string;
  modelName: string;
  timeoutMs: number;
}

export class ModelUnavailableError extends Error {
  readonly code = "MODEL_UNAVAILABLE";

  constructor(message = "模型服务未配置或暂不可用") {
    super(message);
    this.name = "ModelUnavailableError";
  }
}

export class ModelInvalidResponseError extends Error {
  readonly code = "MODEL_INVALID_RESPONSE";

  constructor(message = "模型返回内容无效") {
    super(message);
    this.name = "ModelInvalidResponseError";
  }
}

export class ModelTimeoutError extends Error {
  readonly code = "MODEL_TIMEOUT";

  constructor(message = "模型请求超时") {
    super(message);
    this.name = "ModelTimeoutError";
  }
}

export class KnowledgeUnavailableError extends Error {
  readonly code = "KNOWLEDGE_UNAVAILABLE";

  constructor(message = "当前主题缺少课程资料") {
    super(message);
    this.name = "KnowledgeUnavailableError";
  }
}

export class ModelCancelledError extends Error {
  readonly code = "MODEL_CANCELLED";

  constructor(message = "模型请求已取消") {
    super(message);
    this.name = "ModelCancelledError";
  }
}

interface ModelConfig extends ModelRuntimeInfo {
  apiKey: string;
}

interface ArkChatCompletionRequest extends ChatCompletionCreateParamsNonStreaming {
  thinking: {
    type: "disabled";
  };
}

let cachedClient: OpenAI | null = null;
let cachedClientKey = "";

function readEnvValue(name: string, fallback: string): string {
  const value = process.env[name]?.trim();
  return value && value.length > 0 ? value : fallback;
}

function readTimeoutMs(): number {
  const raw = process.env.MODEL_TIMEOUT_MS?.trim();
  if (!raw) return DEFAULT_TIMEOUT_MS;

  const value = Number(raw);
  if (!Number.isFinite(value) || value < 1000) {
    return DEFAULT_TIMEOUT_MS;
  }

  return Math.min(Math.floor(value), MAX_TIMEOUT_MS);
}

function readModelConfig(): ModelConfig {
  const apiKey = process.env.MODEL_API_KEY?.trim() ?? "";
  const configured =
    apiKey.length > 0 && !MODEL_API_KEY_PLACEHOLDERS.has(apiKey);
  const baseURL = readEnvValue("MODEL_BASE_URL", DEFAULT_BASE_URL);
  const modelName = readEnvValue("MODEL_NAME", DEFAULT_MODEL_NAME);
  const timeoutMs = readTimeoutMs();

  return {
    apiKey,
    configured,
    mode: configured ? "model" : "unavailable",
    provider: "openai-compatible",
    baseURL,
    modelName,
    timeoutMs,
  };
}

function readTestModelResponse(sourceText: string = ""): string | undefined {
  if (process.env.NODE_ENV !== "test") return undefined;
  const sequence = process.env.TEST_MODEL_RESPONSE_SEQUENCE?.trim();
  const sequenceScope = process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE?.trim();
  if (sequence && sequence.length > 0) {
    if (sequenceScope && !sourceText.includes(sequenceScope)) {
      const scopedFallback = process.env.TEST_MODEL_RESPONSE?.trim();
      return scopedFallback && scopedFallback.length > 0 ? scopedFallback : undefined;
    }
    try {
      const values = JSON.parse(sequence) as unknown;
      if (Array.isArray(values) && values.length > 0) {
        const [current, ...rest] = values;
        process.env.TEST_MODEL_RESPONSE_SEQUENCE = JSON.stringify(rest);
        return typeof current === "string" ? current : JSON.stringify(current);
      }
    } catch {
      return sequence;
    }
  }
  const value = process.env.TEST_MODEL_RESPONSE?.trim();
  return value && value.length > 0 ? value : undefined;
}

function getModelClient(config: ModelConfig): OpenAI | null {
  if (!config.configured) {
    cachedClient = null;
    cachedClientKey = "";
    return null;
  }

  const cacheKey = [
    config.baseURL,
    config.modelName,
    String(config.timeoutMs),
    config.apiKey,
  ].join("\n");

  if (!cachedClient || cachedClientKey !== cacheKey) {
    cachedClient = new OpenAI({
      apiKey: config.apiKey,
      baseURL: config.baseURL,
      timeout: config.timeoutMs,
      maxRetries: 0,
    });
    cachedClientKey = cacheKey;
  }

  return cachedClient;
}

async function createChatCompletion(
  client: OpenAI,
  request: ArkChatCompletionRequest,
  timeoutMs: number,
  signal?: AbortSignal
) {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let abortListener: (() => void) | undefined;
  let cancelListener: (() => void) | undefined;
  try {
    if (signal?.aborted) {
      throw new ModelCancelledError();
    }
    if (signal) {
      abortListener = () => controller.abort();
      signal.addEventListener("abort", abortListener, { once: true });
    }
    const timeoutPromise = new Promise<never>((_, reject) => {
      timer = setTimeout(() => {
        controller.abort();
        reject(new ModelTimeoutError(`模型请求超过 ${timeoutMs}ms`));
      }, timeoutMs);
    });
    const cancelPromise = signal
      ? new Promise<never>((_, reject) => {
          cancelListener = () => reject(new ModelCancelledError());
          signal.addEventListener("abort", cancelListener, { once: true });
        })
      : undefined;
    try {
      return await Promise.race([
        client.chat.completions.create(request, { signal: controller.signal }),
        timeoutPromise,
        ...(cancelPromise ? [cancelPromise] : []),
      ]);
    } catch (error) {
      if (signal?.aborted) {
        throw new ModelCancelledError();
      }
      throw error;
    }
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    if (signal && abortListener) signal.removeEventListener("abort", abortListener);
    if (signal && cancelListener) signal.removeEventListener("abort", cancelListener);
  }
}

export function getModelRuntimeInfo(): ModelRuntimeInfo {
  const config = readModelConfig();
  const testConfigured = readTestModelResponse() !== undefined;
  return {
    configured: config.configured || testConfigured,
    mode: config.configured || testConfigured ? "model" : "unavailable",
    provider: config.provider,
    baseURL: config.baseURL,
    modelName: config.modelName,
    timeoutMs: config.timeoutMs,
  };
}

export interface ModelCallOptions {
  temperature?: number;
  maxTokens?: number;
  signal?: AbortSignal;
}

export interface ModelRequestBudgetOptions {
  timeoutMs: number;
  signal?: AbortSignal;
  abortSignal?: AbortSignal;
}

export async function withModelRequestBudget<T>(
  operation: (signal: AbortSignal) => Promise<T>,
  options: ModelRequestBudgetOptions
): Promise<T> {
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs <= 0) {
    throw new RangeError("模型请求总预算必须为正数");
  }

  const timeoutMs = Math.floor(options.timeoutMs);
  const controller = new AbortController();
  const timeoutError = new ModelTimeoutError(`模型请求总预算超过 ${timeoutMs}ms`);
  const abortSignal = options.abortSignal;
  let timeoutTriggered = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let cancelListener: (() => void) | undefined;
  let abortListener: (() => void) | undefined;

  try {
    if (options.signal?.aborted) throw new ModelCancelledError();
    if (abortSignal?.aborted) {
      throw abortReason(abortSignal);
    }

    const timeoutPromise = new Promise<never>((_, reject) => {
      timer = setTimeout(() => {
        timeoutTriggered = true;
        controller.abort(timeoutError);
        reject(timeoutError);
      }, timeoutMs);
    });
    const cancelPromise = options.signal
      ? new Promise<never>((_, reject) => {
          cancelListener = () => {
            controller.abort(options.signal?.reason);
            reject(new ModelCancelledError());
          };
          options.signal?.addEventListener("abort", cancelListener, { once: true });
      })
      : undefined;
    const abortPromise = abortSignal
      ? new Promise<never>((_, reject) => {
          abortListener = () => {
            const error = abortReason(abortSignal);
            controller.abort(error);
            reject(error);
          };
          abortSignal.addEventListener("abort", abortListener, { once: true });
        })
      : undefined;

    return await Promise.race([
      operation(controller.signal),
      timeoutPromise,
      ...(cancelPromise ? [cancelPromise] : []),
      ...(abortPromise ? [abortPromise] : []),
    ]);
  } catch (error) {
    if (timeoutTriggered) throw timeoutError;
    if (options.signal?.aborted) throw new ModelCancelledError();
    throw error;
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    if (options.signal && cancelListener) {
      options.signal.removeEventListener("abort", cancelListener);
    }
    if (abortSignal && abortListener) {
      abortSignal.removeEventListener("abort", abortListener);
    }
  }
}

function abortReason(signal: AbortSignal): Error {
  return signal.reason instanceof Error
    ? signal.reason
    : new ModelCancelledError();
}

// 统一调用入口：返回纯文本
export async function callModel(
  systemPrompt: string,
  userPrompt: string,
  opts?: ModelCallOptions
): Promise<string> {
  const testResponse = readTestModelResponse(`${systemPrompt}\n${userPrompt}`);
  if (testResponse !== undefined) return testResponse;

  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    throw new ModelUnavailableError();
  }

  try {
    const request: ArkChatCompletionRequest = {
      model: config.modelName,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: opts?.temperature ?? 0.3,
      max_tokens: Math.min(Math.max(opts?.maxTokens ?? 1024, 128), 2048),
      thinking: { type: "disabled" },
    };
    const res = await createChatCompletion(client, request, config.timeoutMs, opts?.signal);

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    throw new ModelInvalidResponseError("模型返回为空");
  } catch (error) {
    if (error instanceof ModelInvalidResponseError) throw error;
    if (error instanceof ModelCancelledError) throw error;
    if (error instanceof ModelTimeoutError || isTimeoutLikeError(error)) {
      throw new ModelTimeoutError();
    }
    throw new ModelUnavailableError();
  }
}

// 带对话历史的调用入口：支持多轮上下文
export async function callModelWithHistory(
  systemPrompt: string,
  userPrompt: string,
  history: { role: "user" | "assistant"; content: string }[],
  opts?: ModelCallOptions
): Promise<string> {
  const testResponse = readTestModelResponse(`${systemPrompt}\n${userPrompt}`);
  if (testResponse !== undefined) return testResponse;

  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    throw new ModelUnavailableError();
  }

  try {
    const messages: { role: "system" | "user" | "assistant"; content: string }[] = [
      { role: "system", content: systemPrompt },
    ];
    // 最多保留最近 6 轮（12 条消息），避免 token 溢出
    const recentHistory = history.slice(-12);
    for (const msg of recentHistory) {
      messages.push({ role: msg.role, content: msg.content });
    }
    messages.push({ role: "user", content: userPrompt });

    const request: ArkChatCompletionRequest = {
      model: config.modelName,
      messages,
      temperature: opts?.temperature ?? 0.3,
      max_tokens: Math.min(Math.max(opts?.maxTokens ?? 1024, 128), 2048),
      thinking: { type: "disabled" },
    };
    const res = await createChatCompletion(client, request, config.timeoutMs, opts?.signal);

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    throw new ModelInvalidResponseError("模型返回为空");
  } catch (error) {
    if (error instanceof ModelInvalidResponseError) throw error;
    if (error instanceof ModelCancelledError) throw error;
    if (error instanceof ModelTimeoutError || isTimeoutLikeError(error)) {
      throw new ModelTimeoutError();
    }
    throw new ModelUnavailableError();
  }
}

function isTimeoutLikeError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  return error.name === "AbortError"
    || error.name === "APIConnectionTimeoutError"
    || /timeout|timed out|aborted/i.test(error.message);
}

// 从模型文本中提取 JSON，兼容纯 JSON、Markdown 代码块和前后带说明文字的输出。
export function extractJsonPayload(raw: string): string {
  const text = raw.trim();
  const fenced = /^```(?:json)?\s*([\s\S]*?)\s*```$/i.exec(text);
  if (fenced) {
    return fenced[1].trim();
  }

  const arrayStart = text.indexOf("[");
  const arrayEnd = text.lastIndexOf("]");
  if (arrayStart >= 0 && arrayEnd > arrayStart) {
    return text.slice(arrayStart, arrayEnd + 1);
  }

  const objectStart = text.indexOf("{");
  const objectEnd = text.lastIndexOf("}");
  if (objectStart >= 0 && objectEnd > objectStart) {
    return text.slice(objectStart, objectEnd + 1);
  }

  return text;
}
