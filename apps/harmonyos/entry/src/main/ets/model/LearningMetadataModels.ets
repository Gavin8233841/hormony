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

export interface QuizLearningStats {
  totalAttempts: number;
  totalQuestions: number;
  correctQuestions: number;
  quizDates: string[];
  firstSubmittedAt?: string;
}

export interface LegacyQuizTopicHistorySnapshot {
  courseId: string;
  topic: string;
  attempts: number;
  totalQuestions: number;
  correctQuestions: number;
  lastPracticedAt?: string;
}

export interface LegacyQuizHistorySnapshot {
  updatedAt: string;
  totalQuestions: number;
  correctQuestions: number;
  resultIds: string[];
  topicMastery: LegacyQuizTopicHistorySnapshot[];
}

export interface TopicMasteryMilestone {
  courseId: string;
  topic: string;
  masteredAt: string;
}

export interface QuizLearningState {
  schemaVersion: number;
  legacyHistorySnapshot?: LegacyQuizHistorySnapshot;
  pendingResults: LearningQuizResult[];
  appliedQuizIds: string[];
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
