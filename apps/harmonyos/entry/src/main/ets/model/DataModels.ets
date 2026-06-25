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
  score?: number;
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
