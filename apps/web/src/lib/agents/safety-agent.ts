// Safety Agent：内容安全审核与反幻觉检查

import type { AgentResult, Citation, SafetyResult } from "@/lib/types";

// 敏感词/违规模式
const SENSITIVE_PATTERNS = [
  { pattern: /暴力|血腥|杀人|伤害他人/i, label: "暴力内容" },
  { pattern: /色情|成人|裸体/i, label: "色情内容" },
  { pattern: /赌博|吸毒|贩毒/i, label: "违法活动" },
  { pattern: /自杀|自残|不想活/i, label: "自我伤害" },
  { pattern: /仇恨|歧视|种族歧视/i, label: "仇恨言论" },
];

// Prompt 注入检测模式
const INJECTION_PATTERNS = [
  /ignore\s+(previous|above|all)\s+(instructions?|prompts?)/i,
  /disregard\s+(previous|above)\s+/i,
  /you\s+are\s+(now|actually)\s+(a|an)\s+/i,
  /system\s*:\s*/i,
  /\[INST\]|\[\/INST\]/i,
  /reveal\s+(your|the)\s+(system\s+)?prompt/i,
];

// PII 检测（中国大陆手机号、身份证号）
const PII_PATTERNS = [
  { pattern: /1[3-9]\d{9}/g, label: "手机号码" },
  { pattern: /\d{17}[\dXx]/g, label: "身份证号" },
  { pattern: /[\w.+-]+@[\w-]+\.[\w.-]+/g, label: "邮箱地址" },
];

export function validateUserInput(content: string): string[] {
  const flags: string[] = [];
  for (const pattern of INJECTION_PATTERNS) {
    if (pattern.test(content)) {
      flags.push("疑似 Prompt 注入攻击");
      break;
    }
  }
  for (const { pattern, label } of PII_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(content)) flags.push(`输入包含敏感信息：${label}`);
  }
  return flags;
}

export async function runSafetyAgent(
  content: string,
  citations: Citation[]
): Promise<SafetyResult> {
  const flags: string[] = [];

  // 1. 敏感内容检查
  for (const { pattern, label } of SENSITIVE_PATTERNS) {
    if (pattern.test(content)) {
      flags.push(`敏感内容：${label}`);
    }
  }

  // 2. Prompt 注入检测
  for (const pattern of INJECTION_PATTERNS) {
    if (pattern.test(content)) {
      flags.push("疑似 Prompt 注入攻击");
      break;
    }
  }

  // 3. PII 检测（仅检测输出内容中的 PII，防止泄露）
  for (const { pattern, label } of PII_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(content)) {
      flags.push(`输出包含敏感信息：${label}`);
    }
  }

  // 4. 学术诚信检查
  if (/直接帮我写完整答案|帮我代写|直接给我代码答案|帮我作弊/i.test(content)) {
    flags.push("疑似直接代答，应引导思路而非直接给答案");
  }

  // 5. 反幻觉评估
  const hallucinationRisk = assessHallucination(content, citations);

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
  const hasStrongClaim = /(一定是|绝对是|肯定是|百分之百|不可能|必然)/i.test(content);
  const hasHedge = /(可能|通常|一般来说|根据资料|依据|据统计|研究表明)/i.test(content);
  const hasNumericClaim = /\d+%|\d+次|\d+个/.test(content);

  if (citations.length === 0 && hasStrongClaim && !hasHedge) {
    return "high";
  }
  if (citations.length === 0 && (hasStrongClaim || hasNumericClaim) && !hasHedge) {
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
