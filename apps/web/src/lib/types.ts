// 共享类型定义

export interface UserProfile {
  userId: string;
  name: string;
  stage: string; // 本科 / 硕士 / ...
  weakTopics: string[];
  strongTopics: string[];
  learningStyle: string;
  stats: {
    totalQuestions: number;
    accuracy: number;
    studyDays: number;
  };
}

export interface Course {
  id: string;
  title: string;
  progress: number;
  docCount: number;
  topics: string[];
}

export interface PlanTask {
  id: string;
  title: string;
  date: string;
  estimatedMin: number;
  type: "review" | "practice" | "reading" | "quiz";
  done?: boolean;
}

export interface StudyPlan {
  planId: string;
  userId: string;
  goal: string;
  tasks: PlanTask[];
}

export interface QuizQuestion {
  id: string;
  type: "choice" | "short";
  stem: string;
  options?: string[];
  answer: string;
  explanation: string;
}

export interface Quiz {
  quizId: string;
  courseId: string;
  topic: string;
  questions: QuizQuestion[];
}

export interface KnowledgeChunk {
  id: string;
  text: string;
  source: string;
  courseId: string;
  score?: number;
}

export interface Citation {
  doc: string;
  page?: number;
  snippet?: string;
}

export interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  citations?: Citation[];
  agentTrace?: string[];
}

export interface SafetyResult {
  passed: boolean;
  flags: string[];
  hallucinationRisk: "low" | "medium" | "high";
  suggestion?: string;
}

// Agent 相关
export type AgentName =
  | "Profile"
  | "Retrieval"
  | "Planner"
  | "Tutor"
  | "Quiz"
  | "Evaluator"
  | "Safety";

export interface AgentResult {
  agent: AgentName;
  content: string;
  citations?: Citation[];
  metadata?: unknown;
}

export interface ChatRequest {
  userId: string;
  message: string;
  context?: {
    courseId?: string;
    sessionId?: string;
  };
}

// SSE 流式事件
export type StreamEvent =
  | { type: "thinking"; agent: AgentName }
  | { type: "delta"; content: string }
  | { type: "citation"; source: Citation }
  | { type: "trace"; agent: AgentName; content: string }
  | { type: "done"; sessionId: string };
