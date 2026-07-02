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
  streakDays: number;
}

export interface TagInsight {
  tag: string;
  totalQuestions: number;
  correctQuestions: number;
  accuracy: number;
  wrongQuestions: number;
  lastPracticedAt: string;
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
  courseId?: string;
  topic?: string;
  action?: string;
  done?: boolean;
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
  thinking?: string[];
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
  difficulty?: string;
  tags?: string[];
}

export interface QuizView {
  quizId: string;
  courseId: string;
  topic: string;
  questions: QuizQuestionView[];
}

export interface QuizGradingItem {
  questionId: string;
  answer: string;
  explanation: string;
  difficulty?: string;
  tags?: string[];
}

export interface QuizPackage extends QuizView {
  grading: QuizGradingItem[];
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
  tags?: string[];
}

export interface QuizResult {
  quizId: string;
  userId: string;
  courseId: string;
  topic: string;
  source: string;
  totalQuestions: number;
  correctCount: number;
  accuracy: number;
  details: QuizResultDetail[];
  evaluation: string;
  weakTopics: string[];
  submittedAt: string;
}

export interface StudyEvent {
  id: string;
  type: string;
  timestamp: string;
  courseId?: string;
  topic?: string;
  taskId?: string;
  totalQuestions?: number;
  correctCount?: number;
}

export interface AchievementProgress {
  id: string;
  title: string;
  description: string;
  current: number;
  target: number;
  unlockedAt?: string;
}

export interface LessonProgress {
  courseId: string;
  topic: string;
  completedChunkIds: string[];
  completedAt?: string;
  updatedAt: string;
}

export interface TopicMastery {
  courseId: string;
  topic: string;
  attempts: number;
  totalQuestions: number;
  correctQuestions: number;
  accuracy: number;
  mastered: boolean;
  lastPracticedAt?: string;
}

export interface TopicRelation {
  id: string;
  courseId: string;
  topic: string;
  prerequisiteIds: string[];
  level: number;
}

export interface ReviewItem {
  id: string;
  questionId: string;
  courseId: string;
  topic: string;
  source: string;
  stem: string;
  userAnswer: string;
  correctAnswer: string;
  explanation: string;
  attempts: number;
  resolved: boolean;
  intervalDays: number;
  nextReviewAt: string;
  updatedAt: string;
  tags?: string[];
}

export interface CuratedKnowledgeChunk {
  id: string;
  text: string;
  source: string;
  courseId: string;
  topic: string;
}

export interface LessonExperience {
  schemaVersion: number;
  courseId: string;
  topic: string;
  visualTitle: string;
  visualSteps: string[];
  caseTitle: string;
  caseBody: string;
  workedExampleTitle: string;
  workedExampleSteps: string[];
  activities: LearningActivity[];
}

export interface LearningActivity {
  id: string;
  type: string;
  title: string;
  prompt: string;
  content: string;
  language: string;
  interactionMode: string;
  options: string[];
  answerIndexes: number[];
  answer: string;
  feedback: string;
  source: string;
}

export interface CuratedQuestion {
  id: string;
  courseId: string;
  topic: string;
  question: string;
  options: string[];
  answer: string;
  explanation: string;
}

export interface ExternalLearningResource {
  id: string;
  title: string;
  type: string;
  url: string;
  description: string;
  courseId: string;
  tags: string[];
}

// SSE 流式事件
export interface StreamEvent {
  type: string; // 'thinking' | 'delta' | 'citation' | 'trace' | 'done'
  agent?: string;
  content?: string;
  source?: Citation;
  sessionId?: string;
  code?: string;
  message?: string;
}

// API 请求体接口
export interface PlanRequest {
  userId: string;
  goal: string;
  durationDays: number;
  dailyMinutes: number;
  profile?: UserProfile;
}

export interface PlanTaskUpdate {
  userId: string;
  taskId: string;
  done: boolean;
}

export interface ChatRequest {
  userId: string;
  message: string;
  history?: ChatMessage[];
  profile?: UserProfile;
  context?: ChatContext;
}

export interface ChatContext {
  courseId?: string;
  sessionId?: string;
}

export interface HealthResponse {
  status: string;
  deploymentMode: string;
}

export interface KnowledgeSearchRequest {
  userId: string;
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
