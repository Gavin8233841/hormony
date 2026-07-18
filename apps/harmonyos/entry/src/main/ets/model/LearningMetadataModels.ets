import {
  CuratedQuestion,
  QuizGradingItem,
  QuizQuestionView,
  QuizResult,
  QuizResultDetail,
  ReviewItem,
  StudyEvent,
  TagInsight,
  TopicMastery
} from './DataModels';

export interface LearningTagInsight extends TagInsight {
  courseId: string;
  topic: string;
  easyQuestions: number;
  mediumQuestions: number;
  hardQuestions: number;
  lastDifficulty: string;
  masteryLevel: string;
  masteryPoints: number;
  weakReason: string;
  nextStep: string;
}

export interface LearningQuizQuestionView extends QuizQuestionView {
  difficulty?: string;
}

export interface LearningQuizGradingItem extends QuizGradingItem {
  difficulty?: string;
}

export interface LearningQuizResultDetail extends QuizResultDetail {
  difficulty?: string;
}

export interface LearningQuizResult extends QuizResult {
  difficulty?: string;
  details: LearningQuizResultDetail[];
}

export interface LearningStudyEvent extends StudyEvent {
  source?: string;
  difficulty?: string;
  accuracy?: number;
  tags?: string[];
}

export interface LearningReviewItem extends ReviewItem {
  difficulty?: string;
}

export interface LearningCuratedQuestion extends CuratedQuestion {
  difficulty?: string;
  tags?: string[];
}

export interface AiQuizDraft {
  schemaVersion: number;
  attemptId: string;
  sourceQuizId: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
  difficulty: string;
  questionCount: number;
  questions: LearningQuizQuestionView[];
  grading: LearningQuizGradingItem[];
  answers: string[];
  currentIndex: number;
  attemptSubmittedAt?: string;
  updatedAt: string;
}

export interface CuratedPracticeDraft {
  schemaVersion: number;
  attemptId: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  selectedReviewItemId: string;
  questions: LearningCuratedQuestion[];
  reviewItemIds: string[];
  answers: string[];
  currentIndex: number;
  attemptSubmittedAt?: string;
  updatedAt: string;
}

export interface QuizLearningStats {
  totalAttempts: number;
  totalQuestions: number;
  correctQuestions: number;
  quizDates: string[];
  firstSubmittedAt?: string;
}

export interface TopicMasteryMilestone {
  courseId: string;
  topic: string;
  masteredAt: string;
}

export interface AppliedQuizProof {
  quizId: string;
  verification: 'verified' | 'legacy-unverifiable';
  fingerprintVersion: number;
  payloadSha256: string;
}

export interface QuizLearningState {
  schemaVersion: number;
  pendingResults: LearningQuizResult[];
  appliedQuizIds: string[];
  appliedQuizProofs: AppliedQuizProof[];
  appliedInsightEventIds: string[];
  recentResults: LearningQuizResult[];
  stats: QuizLearningStats;
  reviewItems: LearningReviewItem[];
  topicMastery: TopicMastery[];
  tagInsights: LearningTagInsight[];
  quizEvents: LearningStudyEvent[];
  masteryMilestones: TopicMasteryMilestone[];
  weakTopics: string[];
  strongTopics: string[];
}

export interface QuizWriteReceipt {
  quizId: string;
  applied: boolean;
  totalAttempts: number;
  totalQuestions: number;
  accuracy: number;
  activeReviewCount: number;
  dueReviewCount: number;
  topicAttempts: number;
  topicAccuracy: number;
  topicMastered: boolean;
  activityCount: number;
  courseProgress: number;
}
