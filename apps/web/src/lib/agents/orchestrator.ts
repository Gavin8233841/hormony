// Orchestrator：多 Agent 编排器
// 职责：意图识别 → 调用对应 Agent → 安全审核 → 汇总输出

import { runProfileAgent } from "./profile-agent";
import { runRetrievalAgent } from "./retrieval-agent";
import { runTutorAgent } from "./tutor-agent";
import { runPlannerAgent } from "./planner-agent";
import { runQuizAgent } from "./quiz-agent";
import { runEvaluatorAgent } from "./evaluator-agent";
import { runSafetyAgent } from "./safety-agent";
import type { AgentResult, Citation, StreamEvent, ChatRequest } from "@/lib/types";
import { generateId } from "@/lib/utils";

// 简易意图识别（关键词路由）
type Intent = "tutor" | "plan" | "quiz" | "evaluate" | "general";

function detectIntent(message: string): Intent {
  const m = message.toLowerCase();
  if (/(制定|生成|安排).*(计划|复习|学习|规划)|计划|时间表|日程/.test(m)) return "plan";
  if (/(出题|测验|测试|练习题|考题|quiz)/.test(m)) return "quiz";
  if (/(分析|诊断|错题|薄弱|总结).*(答题|成绩|错题)/.test(m)) return "evaluate";
  if (/(什么是|解释|讲解|怎么理解|区别|原理|为什么|如何)/.test(m)) return "tutor";
  return "general";
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
  const sessionId = generateId("session");
  const agentResults: AgentResult[] = [];

  // 1. 始终加载用户画像
  const profileResult = await runProfileAgent(req.userId);
  agentResults.push(profileResult);

  // 2. 始终执行 RAG 检索（通用场景提供上下文）
  const retrievalResult = await runRetrievalAgent(
    req.message,
    req.context?.courseId
  );
  agentResults.push(retrievalResult);

  // 3. 按意图路由
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      mainResult = {
        agent: "Planner",
        content: JSON.stringify(
          await runPlannerAgent(req.userId, req.message, 14, 90),
          null,
          2
        ),
      };
      break;
    case "quiz":
      mainResult = {
        agent: "Quiz",
        content: JSON.stringify(
          await runQuizAgent(
            req.userId,
            req.context?.courseId ?? "cs101",
            req.message,
            5,
            "medium"
          ),
          null,
          2
        ),
      };
      break;
    case "evaluate":
      mainResult = await runEvaluatorAgent(req.userId, []);
      break;
    case "tutor":
    case "general":
    default:
      mainResult = await runTutorAgent(
        req.userId,
        req.message,
        retrievalResult.content,
        retrievalResult.citations ?? []
      );
      break;
  }
  agentResults.push(mainResult);

  // 4. 安全审核
  const safety = await runSafetyAgent(
    mainResult.content,
    mainResult.citations ?? []
  );
  const safetyAgentResult: AgentResult = {
    agent: "Safety",
    content: safety.passed
      ? "安全检查通过"
      : `安全检查未通过：${safety.flags.join("；")}`,
    metadata: safety,
  };
  agentResults.push(safetyAgentResult);

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
  const sessionId = generateId("session");

  // 1. Profile Agent
  emit({ type: "thinking", agent: "Profile" });
  const profileResult = await runProfileAgent(req.userId);
  emit({ type: "trace", agent: "Profile", content: profileResult.content });

  // 2. Retrieval Agent
  emit({ type: "thinking", agent: "Retrieval" });
  const retrievalResult = await runRetrievalAgent(
    req.message,
    req.context?.courseId
  );
  emit({
    type: "trace",
    agent: "Retrieval",
    content: retrievalResult.content.slice(0, 200),
  });

  // 3. 按意图路由到主 Agent
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      emit({ type: "thinking", agent: "Planner" });
      const plan = await runPlannerAgent(req.userId, req.message, 14, 90);
      mainResult = {
        agent: "Planner",
        content: `已为你生成学习计划（${plan.tasks.length} 个任务）：\n${plan.tasks
          .map((t) => `• [${t.date}] ${t.title}（${t.estimatedMin} 分钟，${t.type}）`)
          .join("\n")}`,
      };
      break;
    case "quiz":
      emit({ type: "thinking", agent: "Quiz" });
      const quiz = await runQuizAgent(
        req.userId,
        req.context?.courseId ?? "cs101",
        req.message,
        5,
        "medium"
      );
      mainResult = {
        agent: "Quiz",
        content: `已生成 ${quiz.questions.length} 道题：\n${quiz.questions
          .map(
            (q, i) =>
              `${i + 1}. ${q.stem}\n${q.options?.join("\n") ?? ""}`
          )
          .join("\n\n")}`,
      };
      break;
    case "tutor":
    case "general":
    default:
      emit({ type: "thinking", agent: "Tutor" });
      mainResult = await runTutorAgent(
        req.userId,
        req.message,
        retrievalResult.content,
        retrievalResult.citations ?? []
      );
      break;
  }

  // 流式输出正文（逐段）
  emit({ type: "delta", content: mainResult.content });

  // 4. 推送引用
  for (const c of mainResult.citations ?? []) {
    emit({ type: "citation", source: c });
  }

  // 5. 安全审核
  emit({ type: "thinking", agent: "Safety" });
  const safety = await runSafetyAgent(
    mainResult.content,
    mainResult.citations ?? []
  );
  emit({
    type: "trace",
    agent: "Safety",
    content: safety.passed
      ? "内容安全检查通过，幻觉风险低。"
      : `安全检查：${safety.flags.join("；")}，幻觉风险：${safety.hallucinationRisk}。${safety.suggestion ?? ""}`,
  });

  // 6. 完成
  emit({ type: "done", sessionId });
}
