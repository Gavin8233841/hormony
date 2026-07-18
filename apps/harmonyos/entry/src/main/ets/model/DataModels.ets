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

export interface CourseCatalogItem {
  id: string;
  title: string;
  domain: string;
  goalType: string;
  goalLabel: string;
  goalSuggestion: string;
  baselineTopic: string;
  diagnosticFirst: boolean;
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

export interface PlanTaskUpdateReceipt {
  plan: StudyPlan;
  task: PlanTask;
  changed: boolean;
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
  focusTag?: string;
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
  focusTag?: string;
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
  options?: string[];
  userAnswer: string;
  correctAnswer: string;
  isCorrect: boolean;
  explanation: string;
  tags?: string[];
  reviewItemId?: string;
}

export interface QuizResult {
  quizId: string;
  sourceQuizId?: string;
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
  completionEventId?: string;
  completionEventSyncedAt?: string;
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
  quizId?: string;
  questionId: string;
  courseId: string;
  topic: string;
  source: string;
  stem: string;
  options?: string[];
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
  provenance?: string;
  sourceResourceIds?: string[];
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
  mediaResourceIds?: string[];
  activities: LearningActivity[];
}

export interface LearningActivity {
  id: string;
  type: string;
  title: string;
  focusTag: string;
  prompt: string;
  content: string;
  language: string;
  interactionMode: string;
  options: string[];
  answerIndexes: number[];
  answer: string;
  feedback: string;
  source: string;
  provenance?: string;
  sourceResourceIds?: string[];
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
  courseId?: string;
  courseIds?: string[];
  tags: string[];
  evidence?: ResourceEvidence;
  media?: ExternalMediaMetadata;
}

export interface ExternalMediaMetadata {
  mediaUrl: string;
  mimeType: string;
  byteLength: number;
  durationMs: number;
  transcript: string;
  transcriptLanguage: string;
  transcriptTimed: boolean;
  accent: string;
  transcriptSource: string;
  rawFilePath: string;
  attribution: string;
  licenseUrl: string;
  modified: boolean;
  shareAlike: boolean;
  sourceSha1: string;
}

export interface ResourceEvidence {
  publisher: string;
  publishedAt: string;
  accessedAt: string;
  version: string;
  sha256: string;
  rightsStatus: string;
  license: string;
  allowModification: boolean;
  allowRedistribution: boolean;
  accessibility: string;
  packagePolicy: string;
  api12Rendering: string;
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
  startDate: string;
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
  startDate: string;
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
