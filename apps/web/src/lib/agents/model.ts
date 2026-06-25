// 模型客户端：OpenAI 兼容接口
// 若未配置 API Key，自动回退到演示模式（返回结构化模拟数据），保证原型可独立演示

import OpenAI from "openai";

const apiKey = process.env.MODEL_API_KEY ?? "";
const baseURL = process.env.MODEL_BASE_URL ?? "https://api.openai.com/v1";
const modelName = process.env.MODEL_NAME ?? "gpt-4o-mini";

export const isModelConfigured = apiKey.length > 0;

export const modelClient = isModelConfigured
  ? new OpenAI({ apiKey, baseURL })
  : null;

export { modelName };

// 统一调用入口：返回纯文本
export async function callModel(
  systemPrompt: string,
  userPrompt: string,
  opts?: { temperature?: number; maxTokens?: number }
): Promise<string> {
  if (!modelClient) {
    return demoResponse(systemPrompt, userPrompt);
  }
  const res = await modelClient.chat.completions.create({
    model: modelName,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    temperature: opts?.temperature ?? 0.3,
    max_tokens: opts?.maxTokens ?? 1024,
  });
  return res.choices[0]?.message?.content ?? "";
}

// 演示模式回退：基于关键词的简单规则应答
function demoResponse(systemPrompt: string, userPrompt: string): string {
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
  return `（演示模式：未配置模型 API Key，以下为模拟应答）\\n已收到你的问题。基于课程知识库，这是一个关于「${userPrompt.slice(0, 40)}」的问题。建议结合课程资料中的相关章节进行复习。配置 MODEL_API_KEY 后可获得完整 AI 回答。`;
}
