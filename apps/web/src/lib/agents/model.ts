// 模型客户端：OpenAI 兼容接口。生产路径不提供伪造模型回退。

import OpenAI from "openai";
import type { ChatCompletionCreateParamsNonStreaming } from "openai/resources/chat/completions";

const DEFAULT_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3";
const DEFAULT_MODEL_NAME = "doubao-seed-1-6-250615";
const DEFAULT_TIMEOUT_MS = 45000;
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

  return Math.floor(value);
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

function readTestModelResponse(): string | undefined {
  if (process.env.NODE_ENV !== "test") return undefined;
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
}

// 统一调用入口：返回纯文本
export async function callModel(
  systemPrompt: string,
  userPrompt: string,
  opts?: ModelCallOptions
): Promise<string> {
  const testResponse = readTestModelResponse();
  if (testResponse !== undefined) return testResponse;

  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    throw new ModelUnavailableError("MODEL_API_KEY 未配置");
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
    const res = await client.chat.completions.create(request);

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    throw new ModelInvalidResponseError("模型返回为空");
  } catch (error) {
    if (error instanceof ModelInvalidResponseError) throw error;
    throw new ModelUnavailableError(
      error instanceof Error ? `模型请求失败：${error.message}` : "模型请求失败"
    );
  }
}

// 带对话历史的调用入口：支持多轮上下文
export async function callModelWithHistory(
  systemPrompt: string,
  userPrompt: string,
  history: { role: "user" | "assistant"; content: string }[],
  opts?: ModelCallOptions
): Promise<string> {
  const testResponse = readTestModelResponse();
  if (testResponse !== undefined) return testResponse;

  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    throw new ModelUnavailableError("MODEL_API_KEY 未配置");
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
    const res = await client.chat.completions.create(request);

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    throw new ModelInvalidResponseError("模型返回为空");
  } catch (error) {
    if (error instanceof ModelInvalidResponseError) throw error;
    throw new ModelUnavailableError(
      error instanceof Error ? `模型请求失败：${error.message}` : "模型请求失败"
    );
  }
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
