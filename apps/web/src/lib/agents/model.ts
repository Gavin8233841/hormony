// 模型客户端：OpenAI 兼容接口
// 若未配置 API Key，自动回退到演示模式，保证原型可独立演示

import OpenAI from "openai";

const DEFAULT_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3";
const DEFAULT_MODEL_NAME = "doubao-seed-2-1-pro-260628";
const DEFAULT_TIMEOUT_MS = 60000;
const MODEL_API_KEY_PLACEHOLDERS = new Set([
  "your-api-key-here",
  "<在本机手动填入>",
]);

export interface ModelRuntimeInfo {
  configured: boolean;
  mode: "model" | "demo";
  provider: "openai-compatible";
  baseURL: string;
  modelName: string;
  timeoutMs: number;
}

interface ModelConfig extends ModelRuntimeInfo {
  apiKey: string;
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
    mode: configured ? "model" : "demo",
    provider: "openai-compatible",
    baseURL,
    modelName,
    timeoutMs,
  };
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
    });
    cachedClientKey = cacheKey;
  }

  return cachedClient;
}

export function getModelRuntimeInfo(): ModelRuntimeInfo {
  const config = readModelConfig();
  return {
    configured: config.configured,
    mode: config.mode,
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
  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    return demoResponse(userPrompt);
  }

  try {
    const res = await client.chat.completions.create({
      model: config.modelName,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: opts?.temperature ?? 0.3,
      max_tokens: opts?.maxTokens ?? 1024,
    });

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    return demoResponse(userPrompt, "模型返回为空，已切换演示模式。");
  } catch {
    return demoResponse(userPrompt, "模型服务暂不可用，已切换演示模式。");
  }
}

// 带对话历史的调用入口：支持多轮上下文
export async function callModelWithHistory(
  systemPrompt: string,
  userPrompt: string,
  history: { role: "user" | "assistant"; content: string }[],
  opts?: ModelCallOptions
): Promise<string> {
  const config = readModelConfig();
  const client = getModelClient(config);

  if (!client) {
    return demoResponse(userPrompt);
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

    const res = await client.chat.completions.create({
      model: config.modelName,
      messages,
      temperature: opts?.temperature ?? 0.3,
      max_tokens: opts?.maxTokens ?? 1024,
    });

    const content = res.choices[0]?.message?.content;
    if (typeof content === "string" && content.trim().length > 0) {
      return content.trim();
    }

    return demoResponse(userPrompt, "模型返回为空，已切换演示模式。");
  } catch {
    return demoResponse(userPrompt, "模型服务暂不可用，已切换演示模式。");
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

// 演示模式回退：基于关键词的简单规则应答
function demoResponse(
  userPrompt: string,
  reason?: string
): string {
  const lower = userPrompt.toLowerCase();
  if (lower.includes("二叉搜索树") || lower.includes("bst")) {
    return "二叉搜索树（BST）是一种每个节点满足「左子树所有值 < 节点值 < 右子树所有值」的二叉树。其核心特性是中序遍历可得到升序序列，查找/插入/删除平均时间复杂度为 O(log n)，最坏退化为 O(n)。\\n\\n依据：数据结构.pdf ——「二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。」";
  }
  if (lower.includes("动态规划") || lower.includes("dp")) {
    return "动态规划适用于具有「最优子结构」和「重叠子问题」两个性质的问题。核心思路是把问题分解为子问题，用表格存储子问题解以避免重复计算。\\n\\n依据：数据结构.pdf ——「动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算。」";
  }
  if (lower.includes("调度") || lower.includes("进程")) {
    return "常见进程调度算法包括：先来先服务（FCFS）、短作业优先（SJF）、时间片轮转、多级反馈队列。FCFS 公平但平均等待时间长；SJF 平均等待最短但可能饥饿；时间片轮转适合交互式系统。\\n\\n依据：操作系统.pdf。";
  }
  if (lower.includes("tcp") || lower.includes("握手")) {
    return "TCP 三次握手流程：客户端发 SYN → 服务端回 SYN+ACK → 客户端发 ACK，连接建立。四次挥手用于安全关闭。三次握手确保双方都能收发数据。\\n\\n依据：计算机网络.pdf。";
  }
  const prefix = reason ?? "未配置模型 API Key，以下为模拟应答。";
  return `（演示模式：${prefix}）\\n已收到你的问题。基于课程知识库，这是一个关于「${userPrompt.slice(0, 40)}」的问题。建议结合课程资料中的相关章节进行复习。配置 MODEL_API_KEY 后可获得完整 AI 回答。`;
}
