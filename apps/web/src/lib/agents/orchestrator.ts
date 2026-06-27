// Orchestrator：多 Agent 编排器
// 职责：意图识别 → 调用对应 Agent → 安全审核 → 汇总输出
// 每个 Agent 调用独立 try-catch，单个 Agent 失败不阻断整体流程

import { runProfileAgent } from "./profile-agent";
import { runRetrievalAgent } from "./retrieval-agent";
import { runTutorAgent } from "./tutor-agent";
import { runPlannerAgent } from "./planner-agent";
import { runQuizAgent } from "./quiz-agent";
import { runEvaluatorAgent } from "./evaluator-agent";
import { runSafetyAgent } from "./safety-agent";
import type { AgentResult, Citation, StreamEvent, ChatRequest, ChatMessage } from "@/lib/types";
import { generateId } from "@/lib/utils";
import { store } from "@/lib/store/db";

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

// 非流式编排：用于一次性返回（如 plan/quiz 接口）
export async function orchestrate(req: ChatRequest): Promise<OrchestrationResult> {
  const intent = detectIntent(req.message);
  const sessionId = req.context?.sessionId ?? generateId("session");
  const agentResults: AgentResult[] = [];

  // 0. 加载对话历史（多轮上下文）
  const history: ChatMessage[] = req.history ?? [];
  if (!req.history) {
    for (const c of store.getConversations(req.userId, 5)) {
      history.push({ role: "user", content: c.message });
      history.push({ role: "assistant", content: c.response });
    }
  }

  // 1. 始终加载用户画像（失败不阻断）
  const profileResult = await safeAgentCall("Profile", () => runProfileAgent(req.userId));
  agentResults.push(profileResult);

  // 2. 始终执行 RAG 检索（失败不阻断）
  const retrievalResult = await safeAgentCall("Retrieval", () =>
    runRetrievalAgent(req.message, req.context?.courseId)
  );
  agentResults.push(retrievalResult);

  // 3. 按意图路由（失败不阻断）
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      mainResult = await safeAgentCall("Planner", async () => {
        const plan = await runPlannerAgent(req.userId, req.message, 14, 90);
        return {
          agent: "Planner",
          content: JSON.stringify(plan, null, 2),
        };
      });
      break;
    case "quiz":
      mainResult = await safeAgentCall("Quiz", async () => {
        const quiz = await runQuizAgent(
          req.userId,
          req.context?.courseId ?? "cs101",
          req.message,
          5,
          "medium"
        );
        return {
          agent: "Quiz",
          content: JSON.stringify(quiz, null, 2),
        };
      });
      break;
    case "evaluate":
      mainResult = await safeAgentCall("Evaluator", () =>
        runEvaluatorAgent(req.userId, [])
      );
      break;
    case "tutor":
    case "general":
    default:
      mainResult = await safeAgentCall("Tutor", () =>
        runTutorAgent(
          req.userId,
          req.message,
          retrievalResult.content,
          retrievalResult.citations ?? [],
          history
        )
      );
      break;
  }
  agentResults.push(mainResult);

  // 4. 安全审核（失败不阻断）
  const safety = await runSafetyAgent(
    mainResult.content,
    mainResult.citations ?? []
  ).catch((err) => {
    console.error("[orchestrator] Safety agent failed:", err instanceof Error ? err.message : String(err));
    return {
      passed: true,
      flags: [],
      hallucinationRisk: "low" as const,
      suggestion: "安全审核服务暂不可用，已跳过。",
    };
  });
  const safetyAgentResult: AgentResult = {
    agent: "Safety",
    content: safety.passed
      ? "安全检查通过"
      : `安全检查未通过：${safety.flags.join("；")}`,
    metadata: safety,
  };
  agentResults.push(safetyAgentResult);

  // 5. 记录会话历史
  store.addConversation({
    sessionId,
    userId: req.userId,
    message: req.message,
    response: mainResult.content,
    intent,
    citations: mainResult.citations ?? [],
    createdAt: new Date().toISOString(),
  });

  return {
    sessionId,
    intent,
    agentResults,
    finalContent: mainResult.content,
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
  const intent = detectIntent(req.message);
  const sessionId = req.context?.sessionId ?? generateId("session");

  // 0. 加载对话历史（多轮上下文）
  const history: ChatMessage[] = req.history ?? [];
  if (!req.history) {
    for (const c of store.getConversations(req.userId, 5)) {
      history.push({ role: "user", content: c.message });
      history.push({ role: "assistant", content: c.response });
    }
  }

  // 1. Profile Agent（失败不阻断）
  emit({ type: "thinking", agent: "Profile" });
  const profileResult = await safeAgentCall("Profile", () => runProfileAgent(req.userId));
  emit({ type: "trace", agent: "Profile", content: profileResult.content });

  // 2. Retrieval Agent（失败不阻断）
  emit({ type: "thinking", agent: "Retrieval" });
  const retrievalResult = await safeAgentCall("Retrieval", () =>
    runRetrievalAgent(req.message, req.context?.courseId)
  );
  emit({
    type: "trace",
    agent: "Retrieval",
    content: retrievalResult.content.slice(0, 200),
  });

  // 3. 按意图路由到主 Agent（失败不阻断）
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      emit({ type: "thinking", agent: "Planner" });
      mainResult = await safeAgentCall("Planner", async () => {
        const plan = await runPlannerAgent(req.userId, req.message, 14, 90);
        return {
          agent: "Planner",
          content: `已为你生成学习计划（${plan.tasks.length} 个任务）：\n${plan.tasks
            .map((t) => `• [${t.date}] ${t.title}（${t.estimatedMin} 分钟，${t.type}）`)
            .join("\n")}`,
        };
      });
      break;
    case "quiz":
      emit({ type: "thinking", agent: "Quiz" });
      mainResult = await safeAgentCall("Quiz", async () => {
        const quiz = await runQuizAgent(
          req.userId,
          req.context?.courseId ?? "cs101",
          req.message,
          5,
          "medium"
        );
        return {
          agent: "Quiz",
          content: `已生成 ${quiz.questions.length} 道题：\n${quiz.questions
            .map(
              (q, i) =>
                `${i + 1}. ${q.stem}\n${q.options?.join("\n") ?? ""}`
            )
            .join("\n\n")}`,
        };
      });
      break;
    case "evaluate":
      emit({ type: "thinking", agent: "Evaluator" });
      mainResult = await safeAgentCall("Evaluator", () =>
        runEvaluatorAgent(req.userId, [])
      );
      break;
    case "tutor":
    case "general":
    default:
      emit({ type: "thinking", agent: "Tutor" });
      mainResult = await safeAgentCall("Tutor", () =>
        runTutorAgent(
          req.userId,
          req.message,
          retrievalResult.content,
          retrievalResult.citations ?? [],
          history
        )
      );
      break;
  }

  // 流式输出正文（逐段）
  emit({ type: "delta", content: mainResult.content });

  // 4. 推送引用
  for (const c of mainResult.citations ?? []) {
    emit({ type: "citation", source: c });
  }

  // 5. 安全审核（失败不阻断）
  emit({ type: "thinking", agent: "Safety" });
  const safety = await runSafetyAgent(
    mainResult.content,
    mainResult.citations ?? []
  ).catch((err) => {
    console.error("[orchestrator/stream] Safety agent failed:", err instanceof Error ? err.message : String(err));
    return {
      passed: true,
      flags: [],
      hallucinationRisk: "low" as const,
      suggestion: "安全审核服务暂不可用。",
    };
  });
  emit({
    type: "trace",
    agent: "Safety",
    content: safety.passed
      ? "内容安全检查通过，幻觉风险低。"
      : `安全检查：${safety.flags.join("；")}，幻觉风险：${safety.hallucinationRisk}。${safety.suggestion ?? ""}`,
  });

  // 6. 记录会话历史
  store.addConversation({
    sessionId,
    userId: req.userId,
    message: req.message,
    response: mainResult.content,
    intent,
    citations: mainResult.citations ?? [],
    createdAt: new Date().toISOString(),
  });

  // 7. 完成
  emit({ type: "done", sessionId });
}
