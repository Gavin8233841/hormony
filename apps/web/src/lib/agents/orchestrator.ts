// Orchestrator：多 Agent 编排器
// 职责：意图识别 → 调用对应 Agent → 安全审核 → 汇总输出
// 任何 Agent 失败均向上抛出异常，由 API 路由返回对应错误码。
// 不提供假降级、假回答或假反馈——失败即报错。
// orchestrate（非流式）与 orchestrateStream（流式）共享前置 Agent、
// 主 Agent 路由、安全审核、会话持久化等公共逻辑（见下方辅助函数）。

import { runProfileAgent } from "./profile-agent";
import { runRetrievalAgent } from "./retrieval-agent";
import { runTutorAgent } from "./tutor-agent";
import { runPlannerAgent } from "./planner-agent";
import { runQuizAgent } from "./quiz-agent";
import { runEvaluatorAgent } from "./evaluator-agent";
import { runSafetyAgent } from "./safety-agent";
import type { AgentResult, Citation, StreamEvent, ChatRequest, ChatMessage, SafetyResult, ChatAction } from "@/lib/types";
import { generateId } from "@/lib/utils";
import { SafetyBlockedError } from "@/lib/api-errors";
import { isCourseTopic } from "@/lib/data";

// 简易意图识别（关键词路由）
type Intent = "tutor" | "plan" | "quiz" | "evaluate" | "general";

function detectIntent(message: string, context?: ChatRequest["context"]): Intent {
  if (context?.question) return context.submitted === true ? "evaluate" : "tutor";
  const m = message.toLowerCase();
  if (/(制定|生成|安排).*(计划|复习|学习|规划)|计划|时间表|日程|备考/.test(m)) return "plan";
  if (/(出题|测验|测试|练习题|考题|quiz|刷题)/.test(m)) return "quiz";
  if (/(分析|诊断|错题|薄弱|总结|评估|成绩|答题记录)/.test(m)) return "evaluate";
  if (/(什么是|解释|讲解|怎么理解|区别|原理|为什么|如何|说明|含义)/.test(m)) return "tutor";
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
  action?: ChatAction;
}

// ========== 公共编排逻辑（orchestrate / orchestrateStream 共享） ==========

// 准备编排上下文：意图识别 + 会话 ID + 加载对话历史
function prepareContext(req: ChatRequest, forcedIntent?: Intent): {
  intent: Intent;
  sessionId: string;
  history: ChatMessage[];
} {
  const intent = forcedIntent ?? detectIntent(req.message, req.context);
  const sessionId = req.context?.sessionId ?? generateId("session");
  const history: ChatMessage[] = req.history ?? [];
  return { intent, sessionId, history };
}

// 执行前置 Agent：Profile + 按需 Retrieval。
// 只有 Tutor / General 需要把检索上下文交给主 Agent；Plan / Evaluate 不消费
// 前置检索结果，Quiz Agent 会按主题自行检索课程资料。
// 任何 Agent 失败均向上抛出异常，不提供假降级。
// 传入 emit 时按流式协议推送 thinking / trace 事件。
async function runPreAgents(
  intent: Intent,
  req: ChatRequest,
  emit?: (event: StreamEvent) => void
): Promise<{
  profileResult: AgentResult;
  retrievalResult: AgentResult;
  retrievalSafety: SafetyResult;
}> {
  const shouldRetrieve = intent === "tutor" || intent === "general";
  emit?.({ type: "thinking", agent: "Profile" });
  if (shouldRetrieve) emit?.({ type: "thinking", agent: "Retrieval" });

  const [profileResult, retrievalResult] = shouldRetrieve
    ? await Promise.all([
        runProfileAgent(req.profile),
        runRetrievalAgent(req.context?.question ?
          `${req.context.topic ?? ""} ${req.context.question}` : req.message, req.context?.courseId),
      ])
    : [await runProfileAgent(req.profile), skippedRetrievalResult(intent)];

  const retrievalSafety: SafetyResult = shouldRetrieve
    ? await runSafetyAgent(
        retrievalResult.content,
        retrievalResult.citations ?? []
      )
    : { passed: true, flags: [], hallucinationRisk: "low" };

  emit?.({ type: "trace", agent: "Profile", content: profileResult.content });
  if (retrievalSafety.passed) {
    emit?.({
      type: "trace",
      agent: "Retrieval",
      content: shouldRetrieve
        ? `已完成课程资料检索（${retrievalResult.citations?.length ?? 0} 条）`
        : retrievalResult.content,
    });
  }

  return { profileResult, retrievalResult, retrievalSafety };
}

function skippedRetrievalResult(intent: Intent): AgentResult {
  const content = intent === "quiz"
    ? "已跳过通用前置检索；Quiz Agent 将按指定课程和主题检索出题资料。"
    : "已跳过通用前置检索；当前意图不消费课程检索上下文。";
  return {
    agent: "Retrieval",
    content,
    citations: [],
    metadata: { skipped: true, intent },
  };
}

// 按意图路由到主 Agent。
// 任何 Agent 失败均向上抛出异常，不提供假降级。
// 传入 emit 时按流式协议推送 thinking 事件；plan/quiz 在流式 / 非流式下采用不同内容格式。
async function routeMainAgent(
  intent: Intent,
  req: ChatRequest,
  retrievalResult: AgentResult,
  history: ChatMessage[],
  emit?: (event: StreamEvent) => void,
  signal?: AbortSignal,
  tutorOnly: boolean = false
): Promise<AgentResult> {
  // 是否为流式模式（由是否传入 emit 决定）：影响 plan/quiz 的内容格式化方式
  const isStream = !!emit;
  let mainResult: AgentResult;
  switch (intent) {
    case "plan":
      emit?.({ type: "thinking", agent: "Planner" });
      mainResult = await (async () => {
        const plan = await runPlannerAgent(
          req.userId,
          req.message,
          14,
          90,
          req.startDate,
          req.profile,
          signal
        );
        return {
          agent: "Planner" as const,
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
          "medium",
          undefined,
          signal
        );
        return {
          agent: "Quiz" as const,
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
      mainResult = await runEvaluatorAgent(
        req.context?.submitted === true && req.context.question !== undefined &&
          req.context.userAnswer !== undefined && req.context.correctAnswer !== undefined ? [{
            question: req.context.question,
            userAnswer: req.context.userAnswer,
            correctAnswer: req.context.correctAnswer,
          }] : [], req.profile, signal, req.context?.courseId, req.message);
      break;
    case "tutor":
    case "general":
    default:
      emit?.({ type: "thinking", agent: "Tutor" });
      mainResult = await runTutorAgent(
          req.userId,
          req.context?.question ?
            `当前题目：${req.context.question}\n学生当前作答：${req.context.userAnswer ?? "尚未作答"}\n` +
            `此题尚未提交，请先给思考提示，不直接给答案。学生问题：${req.message}` : req.message,
          retrievalResult.content,
          retrievalResult.citations ?? [],
          history,
          req.profile,
          signal,
          tutorOnly ? "concept" : "general"
        );
      break;
  }
  return mainResult;
}

// 安全审核。
// 传入 emit 时推送 thinking + trace 事件；返回 safety 结果与对应的 AgentResult。
// 安全审核失败时向上抛出异常，不提供假降级。
async function runSafetyCheck(
  content: string,
  citations: Citation[],
  emit?: (event: StreamEvent) => void
): Promise<{ safety: SafetyResult; safetyAgentResult: AgentResult }> {
  emit?.({ type: "thinking", agent: "Safety" });
  const safety = await runSafetyAgent(content, citations);
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
      ? "内容安全检查通过。"
      : `安全检查：${safety.flags.join("；")}，幻觉风险：${safety.hallucinationRisk}。${safety.suggestion ?? ""}`,
  });
  return { safety, safetyAgentResult };
}

function nextAction(req: ChatRequest, intent: Intent): ChatAction | undefined {
  const courseId = req.context?.courseId;
  const topic = req.context?.topic;
  if (!courseId || !topic || !isCourseTopic(courseId, topic)) return undefined;
  const kind: ChatAction["kind"] = intent === "quiz" ? "quiz" :
    intent === "evaluate" && req.context?.submitted === true ? "practice" : "lesson";
  const title = kind === "quiz" ? `开始${topic}测验` :
    kind === "practice" ? `练习${topic}` : `学习${topic}`;
  const reason = kind === "practice" ? "再做一组本主题练习，检查刚才的错因" :
    kind === "quiz" ? "在专用测验页生成并提交题目" : "打开课程内容，先整理概念和解题步骤";
  return { kind, courseId, topic, title, reason };
}

// ========== 入口函数 ==========

// 非流式编排：用于一次性返回（如 plan/quiz 接口）
async function orchestrateWithIntent(req: ChatRequest, forcedIntent?: Intent): Promise<OrchestrationResult> {
  const { intent, sessionId, history } = prepareContext(req, forcedIntent);
  const agentResults: AgentResult[] = [];

  // 1. 前置 Agent：Profile + Retrieval
  const { profileResult, retrievalResult, retrievalSafety } = await runPreAgents(intent, req);
  agentResults.push(profileResult, retrievalResult);
  if (!retrievalSafety.passed) {
    throw new SafetyBlockedError("检索结果未通过安全审核");
  }

  // 2. 按意图路由到主 Agent
  const mainResult = await routeMainAgent(
    intent, req, retrievalResult, history, undefined, undefined, forcedIntent === "tutor");
  agentResults.push(mainResult);

  // 3. 安全审核
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
    action: safety.passed ? nextAction(req, intent) : undefined,
  };
}

export async function orchestrate(req: ChatRequest): Promise<OrchestrationResult> {
  return orchestrateWithIntent(req);
}

// 小艺等外部入口只能调用课程讲解。不接收端侧画像、答题记录或可触发
// Evaluator 的题目上下文；网络入口仍须独立校验消息和历史。
export interface TutorOnlyRequest {
  userId: string;
  message: string;
  startDate: string;
  courseId?: string;
  topic?: string;
  sessionId?: string;
  history?: ChatMessage[];
}

export async function orchestrateTutorOnly(input: TutorOnlyRequest): Promise<OrchestrationResult> {
  const req: ChatRequest = {
    userId: input.userId,
    message: input.message,
    startDate: input.startDate,
    context: {
      courseId: input.courseId,
      topic: input.topic,
      sessionId: input.sessionId,
    },
    history: input.history,
  };
  return orchestrateWithIntent(req, "tutor");
}

// 流式编排：通过回调推送 SSE 事件
export async function orchestrateStream(
  req: ChatRequest,
  emit: (event: StreamEvent) => void,
  signal?: AbortSignal,
  forcedIntent?: "tutor"
): Promise<void> {
  const { intent, sessionId, history } = prepareContext(req, forcedIntent);

  // 1. 前置 Agent：Profile + Retrieval（流式推送 trace）
  const { retrievalResult, retrievalSafety } = await runPreAgents(intent, req, emit);
  if (!retrievalSafety.passed) {
    emit({
      type: "error",
      code: "SAFETY_BLOCKED",
      message: "本次回答未通过安全检查，请调整问题后重试。",
    });
    emit({ type: "done", sessionId });
    return;
  }

  // 2. 按意图路由到主 Agent
  const mainResult = await routeMainAgent(
    intent, req, retrievalResult, history, emit, signal, forcedIntent === "tutor");

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
  const action = nextAction(req, intent);
  if (action) emit({ type: "action", action });

  // 5. 完成。会话由 HarmonyOS 本地仓库持久化。
  emit({ type: "done", sessionId });
}
