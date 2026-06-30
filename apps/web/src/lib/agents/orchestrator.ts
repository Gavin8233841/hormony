// Orchestrator：多 Agent 编排器
// 职责：意图识别 → 调用对应 Agent → 安全审核 → 汇总输出
// 每个 Agent 调用独立 try-catch，单个 Agent 失败不阻断整体流程
// orchestrate（非流式）与 orchestrateStream（流式）共享前置 Agent、
// 主 Agent 路由、安全审核、会话持久化等公共逻辑（见下方辅助函数）。

import { runProfileAgent } from "./profile-agent";
import { runRetrievalAgent } from "./retrieval-agent";
import { runTutorAgent } from "./tutor-agent";
import { runPlannerAgent } from "./planner-agent";
import { runQuizAgent } from "./quiz-agent";
import { runEvaluatorAgent } from "./evaluator-agent";
import { runSafetyAgent } from "./safety-agent";
import type { AgentResult, Citation, StreamEvent, ChatRequest, ChatMessage, SafetyResult } from "@/lib/types";
import { generateId } from "@/lib/utils";

// 简易意图识别（关键词路由）
type Intent = "tutor" | "plan" | "quiz" | "evaluate" | "general";

function detectIntent(message: string): Intent {
  const m = message.toLowerCase();
  if (/(制定|生成|安排).*(计划|复习|学习|规划)|计划|时间表|日程|备考/.test(m)) return "plan";
  if (/(出题|测验|测试|练习题|考题|quiz|刷题)/.test(m)) return "quiz";
  if (/(分析|诊断|错题|薄弱|总结|评估|成绩|答题记录)/.test(m)) return "evaluate";
  if (/(什么是|解释|讲解|怎么理解|区别|原理|为什么|如何|说明|含义)/.test(m)) return "tutor";
  return "general";
}

// 安全执行单个 Agent，失败时返回降级结果
async function safeAgentCall(
  agentName: AgentResult["agent"],
  fn: () => Promise<AgentResult>
): Promise<AgentResult> {
  try {
    return await fn();
  } catch (err) {
    console.error(`[orchestrator] ${agentName} agent failed:`, err instanceof Error ? err.message : String(err));
    return {
      agent: agentName,
      content: `${agentName} 服务暂时不可用，已跳过。`,
    };
  }
}

export interface OrchestrationResult {
  sessionId: string;
  intent: Intent;
  agentResults: AgentResult[];
  finalContent: string;
  citations: Citation[];
  safetyPassed: boolean;
  safetySuggestion?: string;
}

// ========== 公共编排逻辑（orchestrate / orchestrateStream 共享） ==========

// 准备编排上下文：意图识别 + 会话 ID + 加载对话历史
function prepareContext(req: ChatRequest): {
  intent: Intent;
  sessionId: string;
  history: ChatMessage[];
} {
  const intent = detectIntent(req.message);
  const sessionId = req.context?.sessionId ?? generateId("session");
  const history: ChatMessage[] = req.history ?? [];
  return { intent, sessionId, history };
}

// 执行前置 Agent：Profile + Retrieval（失败不阻断）。
// 传入 emit 时按流式协议推送 thinking / trace 事件。
async function runPreAgents(
  req: ChatRequest,
  emit?: (event: StreamEvent) => void
): Promise<{ profileResult: AgentResult; retrievalResult: AgentResult }> {
  // Profile Agent
  emit?.({ type: "thinking", agent: "Profile" });
  const profileResult = await safeAgentCall("Profile", () => runProfileAgent(req.profile));
  emit?.({ type: "trace", agent: "Profile", content: profileResult.content });

  // Retrieval Agent
  emit?.({ type: "thinking", agent: "Retrieval" });
  const retrievalResult = await safeAgentCall("Retrieval", () =>
    runRetrievalAgent(req.message, req.context?.courseId)
  );
  emit?.({
    type: "trace",
    agent: "Retrieval",
    content: retrievalResult.content.slice(0, 200),
  });

  return { profileResult, retrievalResult };
}

// 按意图路由到主 Agent（失败不阻断）。
// 传入 emit 时按流式协议推送 thinking 事件；plan/quiz 在流式 / 非流式下采用不同内容格式。
async function routeMainAgent(
  intent: Intent,
  req: ChatRequest,
  retrievalResult: AgentResult,
  history: ChatMessage[],
  emit?: (event: StreamEvent) => void
): Promise<AgentResult> {
  // 是否为流式模式（由是否传入 emit 决定）：影响 plan/quiz 的内容格式化方式
  const isStream = !!emit;
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      emit?.({ type: "thinking", agent: "Planner" });
      mainResult = await (async () => {
        const plan = await runPlannerAgent(req.userId, req.message, 14, 90, req.profile);
        return {
          agent: "Planner",
          content: isStream
            ? `已为你生成学习计划（${plan.tasks.length} 个任务）：\n${plan.tasks
                .map((t) => `• [${t.date}] ${t.title}（${t.estimatedMin} 分钟，${t.type}）`)
                .join("\n")}`
            : JSON.stringify(plan, null, 2),
        };
      })();
      break;
    case "quiz":
      emit?.({ type: "thinking", agent: "Quiz" });
      mainResult = await (async () => {
        const quiz = await runQuizAgent(
          req.userId,
          req.context?.courseId ?? "cs101",
          req.message,
          5,
          "medium"
        );
        return {
          agent: "Quiz",
          content: isStream
            ? `已生成 ${quiz.questions.length} 道题：\n${quiz.questions
                .map(
                  (q, i) =>
                    `${i + 1}. ${q.stem}\n${q.options?.join("\n") ?? ""}`
                )
                .join("\n\n")}`
            : JSON.stringify(quiz, null, 2),
        };
      })();
      break;
    case "evaluate":
      emit?.({ type: "thinking", agent: "Evaluator" });
      mainResult = await runEvaluatorAgent(req.userId, [], req.profile);
      break;
    case "tutor":
    case "general":
    default:
      emit?.({ type: "thinking", agent: "Tutor" });
      mainResult = await runTutorAgent(
          req.userId,
          req.message,
          retrievalResult.content,
          retrievalResult.citations ?? [],
          history,
          req.profile
        );
      break;
  }
  return mainResult;
}

// 安全审核（失败时阻断正文输出）。
// 传入 emit 时推送 thinking + trace 事件；返回 safety 结果与对应的 AgentResult。
async function runSafetyCheck(
  content: string,
  citations: Citation[],
  emit?: (event: StreamEvent) => void
): Promise<{ safety: SafetyResult; safetyAgentResult: AgentResult }> {
  emit?.({ type: "thinking", agent: "Safety" });
  const safety = await runSafetyAgent(content, citations).catch((err) => {
    console.error(
      `[orchestrator${emit ? "/stream" : ""}] Safety agent failed:`,
      err instanceof Error ? err.message : String(err)
    );
    return {
      passed: false,
      flags: ["安全审核服务不可用"],
      hallucinationRisk: "high" as const,
      suggestion: "安全审核失败，已阻断本次回答。",
    };
  });
  const safetyAgentResult: AgentResult = {
    agent: "Safety",
    content: safety.passed
      ? "安全检查通过"
      : `安全检查未通过：${safety.flags.join("；")}`,
    metadata: safety,
  };
  emit?.({
    type: "trace",
    agent: "Safety",
    content: safety.passed
      ? "内容安全检查通过，幻觉风险低。"
      : `安全检查：${safety.flags.join("；")}，幻觉风险：${safety.hallucinationRisk}。${safety.suggestion ?? ""}`,
  });
  return { safety, safetyAgentResult };
}

// ========== 入口函数 ==========

// 非流式编排：用于一次性返回（如 plan/quiz 接口）
export async function orchestrate(req: ChatRequest): Promise<OrchestrationResult> {
  const { intent, sessionId, history } = prepareContext(req);
  const agentResults: AgentResult[] = [];

  // 1. 前置 Agent：Profile + Retrieval（失败不阻断）
  const { profileResult, retrievalResult } = await runPreAgents(req);
  agentResults.push(profileResult, retrievalResult);

  // 2. 按意图路由到主 Agent（失败不阻断）
  const mainResult = await routeMainAgent(intent, req, retrievalResult, history);
  agentResults.push(mainResult);

  // 3. 安全审核（失败不阻断）
  const { safety, safetyAgentResult } = await runSafetyCheck(
    mainResult.content,
    mainResult.citations ?? []
  );
  agentResults.push(safetyAgentResult);

  const finalContent = safety.passed
    ? mainResult.content
    : "本次回答未通过安全检查，请调整问题后重试。";

  return {
    sessionId,
    intent,
    agentResults,
    finalContent,
    citations: mainResult.citations ?? [],
    safetyPassed: safety.passed,
    safetySuggestion: safety.suggestion,
  };
}

// 流式编排：通过回调推送 SSE 事件
export async function orchestrateStream(
  req: ChatRequest,
  emit: (event: StreamEvent) => void
): Promise<void> {
  const { intent, sessionId, history } = prepareContext(req);

  // 1. 前置 Agent：Profile + Retrieval（失败不阻断，流式推送 trace）
  const { retrievalResult } = await runPreAgents(req, emit);

  // 2. 按意图路由到主 Agent（失败不阻断）
  const mainResult = await routeMainAgent(intent, req, retrievalResult, history, emit);

  // 3. 安全审核必须先于任何正文输出。
  const { safety } = await runSafetyCheck(
    mainResult.content,
    mainResult.citations ?? [],
    emit
  );
  if (!safety.passed) {
    emit({
      type: "error",
      code: "SAFETY_BLOCKED",
      message: "本次回答未通过安全检查，请调整问题后重试。",
    });
    emit({ type: "done", sessionId });
    return;
  }

  // 4. 审核通过后才输出正文与引用。
  emit({ type: "delta", content: mainResult.content });
  for (const c of mainResult.citations ?? []) {
    emit({ type: "citation", source: c });
  }

  // 5. 完成。会话由 HarmonyOS 本地仓库持久化。
  emit({ type: "done", sessionId });
}
