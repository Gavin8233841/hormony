import {
  CuratedQuestion,
  QuizGradingItem,
  QuizQuestionView,
  QuizResult,
  QuizResultDetail,
  ReviewItem,
  StudyEvent,
  TagInsight
} from './DataModels';

export interface LearningTagInsight extends TagInsight {
  easyQuestions: number;
  mediumQuestions: number;
  hardQuestions: number;
  lastDifficulty: string;
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
