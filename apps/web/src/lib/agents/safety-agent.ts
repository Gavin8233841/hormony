// Safety Agent：内容安全审核与反幻觉检查

import type { AgentResult, Citation, SafetyResult } from "@/lib/types";

// 敏感词/违规模式（简化版，生产环境应接入专业内容安全服务）
const SENSITIVE_PATTERNS = [
  /暴力|血腥/i,
  /色情|成人/i,
  /赌博|吸毒/i,
  /政治敏感词占位/i, // 实际应接入专业审核 API
];

export async function runSafetyAgent(
  content: string,
  citations: Citation[]
): Promise<SafetyResult> {
  // 1. 内容安全检查
  const flags: string[] = [];
  for (const pattern of SENSITIVE_PATTERNS) {
    if (pattern.test(content)) {
      flags.push(`命中敏感模式: ${pattern.source}`);
    }
  }

  // 2. 反幻觉检查：关键论断是否有引用支撑
  const hallucinationRisk = assessHallucination(content, citations);

  // 3. 学术诚信检查：是否包含直接代写答案的倾向
  if (/直接帮我写完整答案|帮我代写|直接给我代码答案/i.test(content)) {
    flags.push("疑似直接代答，应引导思路而非直接给答案");
  }

  const passed = flags.length === 0 && hallucinationRisk !== "high";

  return {
    passed,
    flags,
    hallucinationRisk,
    suggestion: passed
      ? undefined
      : hallucinationRisk === "high"
        ? "回答中存在缺乏资料支撑的论断，建议补充引用或标注为通用知识。"
        : flags.length > 0
          ? "内容触发安全规则，建议修改后再输出。"
          : undefined,
  };
}

// 反幻觉评估：检查回答是否过度断言而无引用
function assessHallucination(content: string, citations: Citation[]): "low" | "medium" | "high" {
  // 如果回答包含强论断但无任何引用
  const hasStrongClaim = /(一定是|绝对是|肯定是|百分之百|不可能)/i.test(content);
  const hasHedge = /(可能|通常|一般来说|根据资料|依据)/i.test(content);

  if (citations.length === 0 && hasStrongClaim && !hasHedge) {
    return "high";
  }
  if (citations.length === 0 && !hasHedge) {
    return "medium";
  }
  return "low";
}

export function safetyResultToAgentResult(s: SafetyResult): AgentResult {
  return {
    agent: "Safety",
    content: s.passed
      ? "安全检查通过。"
      : `安全检查未通过：${s.flags.join("；")}。幻觉风险：${s.hallucinationRisk}。${s.suggestion ?? ""}`,
    metadata: s,
  };
}
