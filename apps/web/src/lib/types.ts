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

export interface LearningProfileSnapshot {
  stage: string;
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

export type QuizDifficulty = "easy" | "medium" | "hard";

export interface PlanTask {
  id: string;
  title: string;
  date: string;
  estimatedMin: number;
  type: "review" | "practice" | "reading" | "quiz";
  courseId?: string;
  topic?: string;
  action?: "lesson" | "practice" | "quiz" | "review";
  reason?: string;
  done?: boolean;
}

export interface StudyPlan {
  planId: string;
  userId: string;
  goal: string;
  tasks: PlanTask[];
  agentTrace?: string[];
}

export interface QuizQuestion {
  id: string;
  type: "choice" | "short";
  stem: string;
  options?: string[];
  answer: string;
  explanation: string;
  difficulty?: QuizDifficulty;
  tags?: string[];
}

export interface Quiz {
  quizId: string;
  courseId: string;
  topic: string;
  focusTag?: string;
  questions: QuizQuestion[];
}

export interface QuizQuestionView {
  id: string;
  type: "choice" | "short";
  stem: string;
  options?: string[];
  difficulty?: QuizDifficulty;
  tags: string[];
}

export interface QuizView {
  quizId: string;
  courseId: string;
  topic: string;
  focusTag?: string;
  questions: QuizQuestionView[];
}

export interface QuizGradingItem {
  questionId: string;
  answer: string;
  explanation: string;
  difficulty?: QuizDifficulty;
  tags: string[];
}

export interface QuizPackage extends QuizView {
  grading: QuizGradingItem[];
}

export interface QuizCatalogItem {
  quizId: string;
  courseId: string;
  topic: string;
  questionCount: number;
}

export interface ContentProvenance {
  sourceTitle: string;
  sourceVersion: string;
  sourceLocator: string;
  sourceUrl: string;
  rightsStatus: "reference-only" | "external-link-only" | "redistributable";
  rightsName: string;
  rightsUrl: string;
  accessStatus: "reachable" | "unreachable" | "not-checked";
  checkedAt: string | null;
  httpStatus: number | null;
}

export interface KnowledgeChunk {
  id: string;
  text: string;
  source: string;
  courseId: string;
  topic?: string;
  score?: number;
  provenance?: ContentProvenance;
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
  history?: ChatMessage[];
  profile?: LearningProfileSnapshot;
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
  | { type: "error"; code: string; message: string }
  | { type: "done"; sessionId: string };

// ========== 测验提交与评分 ==========

export interface QuizSubmission {
  quizId: string;
  userId: string;
  answers: QuizAnswer[];
}

export interface QuizAnswer {
  questionId: string;
  userAnswer: string;
}

export interface QuizResult {
  quizId: string;
  userId: string;
  totalQuestions: number;
  correctCount: number;
  accuracy: number;
  details: QuizResultDetail[];
  evaluation: string;
  weakTopics: string[];
  submittedAt: string;
}

export interface QuizResultDetail {
  questionId: string;
  stem: string;
  userAnswer: string;
  correctAnswer: string;
  isCorrect: boolean;
  explanation: string;
  difficulty?: QuizDifficulty;
  tags?: string[];
}

// ========== 仪表盘统计 ==========

export interface DashboardStats {
  userId: string;
  totalQuestions: number;
  accuracy: number;
  studyDays: number;
  activeCourses: number;
  totalTasks: number;
  completedTasks: number;
  totalQuizSubmissions: number;
  recentActivity: RecentActivity[];
}

export interface RecentActivity {
  userId: string;
  type: "chat" | "quiz" | "plan" | "study";
  description: string;
  timestamp: string;
}

// ========== 会话历史 ==========

export interface ConversationRecord {
  sessionId: string;
  userId: string;
  message: string;
  response: string;
  intent: string;
  citations: Citation[];
  createdAt: string;
}

// ========== 知识上传 ==========

export interface KnowledgeUploadRequest {
  userId?: string;
  courseId: string;
  source: string;
  text: string;
}

// ========== 外部资源索引 ==========

export interface ExternalResource {
  id: string;
  title: string;
  type: "textbook" | "documentation" | "course" | "standard" | "tool";
  url: string;
  description: string;
  courseId?: string;
  tags: string[];
  provenance: ContentProvenance;
}

// ========== 计划任务打卡 ==========

export interface PlanTaskUpdate {
  taskId: string;
  done: boolean;
}
