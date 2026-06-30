/**
 * 数据模型定义
 */

export interface UserProfile {
  userId: string;
  name: string;
  stage: string;
  weakTopics: string[];
  strongTopics: string[];
  learningStyle: string;
  stats: UserStats;
}

export interface UserStats {
  totalQuestions: number;
  accuracy: number;
  studyDays: number;
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
  type: string;
}

export interface StudyPlan {
  planId: string;
  userId: string;
  goal: string;
  tasks: PlanTask[];
}

export interface ChatMessage {
  role: string; // 'user' | 'assistant'
  content: string;
  citations?: Citation[];
  agentTrace?: string[];
}

export interface Citation {
  doc: string;
  snippet?: string;
}

// 知识库检索结果条目
export interface KnowledgeChunk {
  id?: string;
  text: string;
  source: string;
  courseId?: string;
  topic?: string;
  score?: number;
}

export interface QuizQuestionView {
  id: string;
  type: string;
  stem: string;
  options?: string[];
}

export interface QuizView {
  quizId: string;
  courseId: string;
  topic: string;
  questions: QuizQuestionView[];
}

export interface QuizRequest {
  userId: string;
  courseId: string;
  topic: string;
  count: number;
  difficulty: string;
}

export interface QuizAnswer {
  questionId: string;
  userAnswer: string;
}

export interface QuizSubmission {
  quizId: string;
  userId: string;
  answers: QuizAnswer[];
}

export interface QuizResultDetail {
  questionId: string;
  stem: string;
  userAnswer: string;
  correctAnswer: string;
  isCorrect: boolean;
  explanation: string;
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

// SSE 流式事件
export interface StreamEvent {
  type: string; // 'thinking' | 'delta' | 'citation' | 'trace' | 'done'
  agent?: string;
  content?: string;
  source?: Citation;
  sessionId?: string;
}

// API 请求体接口
export interface PlanRequest {
  userId: string;
  goal: string;
  durationDays: number;
  dailyMinutes: number;
}

export interface ChatRequest {
  userId: string;
  message: string;
}

export interface KnowledgeSearchRequest {
  query: string;
  courseId?: string;
  topK: number;
}

// API 响应体接口
export interface CoursesResponse {
  courses: Course[];
}

export interface KnowledgeSearchResponse {
  chunks: KnowledgeChunk[];
}
