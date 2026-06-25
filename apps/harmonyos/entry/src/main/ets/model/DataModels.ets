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

// SSE 流式事件
export interface StreamEvent {
  type: string; // 'thinking' | 'delta' | 'citation' | 'trace' | 'done'
  agent?: string;
  content?: string;
  source?: Citation;
  sessionId?: string;
}
