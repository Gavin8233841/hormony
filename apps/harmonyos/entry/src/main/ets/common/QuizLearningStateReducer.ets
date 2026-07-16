import { TopicMastery } from '../model/DataModels';
import {
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail,
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight,
  QuizLearningState,
  QuizLearningStats,
  QuizWriteReceipt,
  TopicMasteryMilestone
} from '../model/LearningMetadataModels';

const QUIZ_STATE_SCHEMA_VERSION: number = 2;
const RECENT_RESULT_LIMIT: number = 20;
const QUIZ_EVENT_LIMIT: number = 500;
const RESOLVED_REVIEW_LIMIT: number = 200;

export class QuizLearningStateReducer {
  static createEmptyState(): QuizLearningState {
    const stats: QuizLearningStats = {
      totalAttempts: 0,
      totalQuestions: 0,
      correctQuestions: 0,
      quizDates: []
    };
    return {
      schemaVersion: QUIZ_STATE_SCHEMA_VERSION,
      pendingResults: [],
      appliedQuizIds: [],
      appliedInsightEventIds: [],
      recentResults: [],
      stats: stats,
      reviewItems: [],
      topicMastery: [],
      tagInsights: [],
      quizEvents: [],
      masteryMilestones: [],
      weakTopics: [],
      strongTopics: []
    };
  }

  static preparePersistentState(state: QuizLearningState): boolean {
    let changed = false;
    if (state.schemaVersion !== QUIZ_STATE_SCHEMA_VERSION) {
      state.schemaVersion = QUIZ_STATE_SCHEMA_VERSION;
      changed = true;
    }
    if (state.appliedInsightEventIds === undefined) {
      state.appliedInsightEventIds = [];
      changed = true;
    }
    if (state.masteryMilestones === undefined) {
      state.masteryMilestones = [];
      changed = true;
    }
    const milestoneCount = state.masteryMilestones.length;
    QuizLearningStateReducer.ensureMasteryMilestones(state);
    return changed || state.masteryMilestones.length !== milestoneCount;
  }

  static enqueueResult(state: QuizLearningState, result: QuizResult): boolean {
    if (state.appliedQuizIds.includes(result.quizId)) return false;
    const pending = state.pendingResults.find((item: QuizResult): boolean => item.quizId === result.quizId);
    if (pending !== undefined) return false;
    state.pendingResults.push(result);
    return true;
  }

  static applyPendingResults(state: QuizLearningState): number {
    const pending = state.pendingResults.slice();
    state.pendingResults = [];
    let appliedCount = 0;
    for (const result of pending) {
      if (QuizLearningStateReducer.applyResult(state, result)) appliedCount += 1;
    }
    return appliedCount;
  }

  static applyResult(state: QuizLearningState, result: QuizResult): boolean {
    if (state.appliedQuizIds.includes(result.quizId)) return false;

    state.appliedQuizIds.push(result.quizId);
    state.recentResults.unshift(result);
    state.recentResults = state.recentResults.slice(0, RECENT_RESULT_LIMIT);
    state.stats.totalAttempts += 1;
    state.stats.totalQuestions += result.totalQuestions;
    state.stats.correctQuestions += result.correctCount;
    const quizDate = QuizLearningStateReducer.localDateKey(result.submittedAt);
    if (!state.stats.quizDates.includes(quizDate)) state.stats.quizDates.push(quizDate);
    if (state.stats.firstSubmittedAt === undefined || result.submittedAt < state.stats.firstSubmittedAt) {
      state.stats.firstSubmittedAt = result.submittedAt;
    }

    QuizLearningStateReducer.applyTopicMastery(state.topicMastery, result);
    QuizLearningStateReducer.recordMasteryMilestone(state, result);
    QuizLearningStateReducer.applyReviewItems(state, result);
    QuizLearningStateReducer.applyTagInsights(state.tagInsights, result);
    QuizLearningStateReducer.appendQuizEvent(state.quizEvents, result);
    state.quizEvents = QuizLearningStateReducer.compactQuizEvents(state.quizEvents);
    QuizLearningStateReducer.refreshProfileTopics(state);
    return true;
  }

  static createReceipt(state: QuizLearningState, result: QuizResult, applied: boolean,
    now: string = new Date().toISOString()): QuizWriteReceipt {
    const mastery = state.topicMastery.find((item: TopicMastery): boolean =>
      item.courseId === result.courseId && item.topic === result.topic);
    const activeItems = state.reviewItems.filter((item: ReviewItem): boolean => !item.resolved);
    const nowTime = new Date(now).getTime();
    const dueCount = activeItems.filter((item: ReviewItem): boolean =>
      new Date(item.nextReviewAt).getTime() <= nowTime).length;
    return {
      quizId: result.quizId,
      applied: applied,
      totalAttempts: state.stats.totalAttempts,
      totalQuestions: state.stats.totalQuestions,
      accuracy: state.stats.totalQuestions > 0 ?
        state.stats.correctQuestions / state.stats.totalQuestions : 0,
      activeReviewCount: activeItems.length,
      dueReviewCount: dueCount,
      topicAttempts: mastery?.attempts ?? 0,
      topicAccuracy: mastery?.accuracy ?? 0,
      topicMastered: mastery?.mastered ?? false,
      activityCount: state.stats.totalAttempts,
      courseProgress: 0
    };
  }

  static refreshProfileTopics(state: QuizLearningState): void {
    const weakTopics: string[] = [];
    const strongTopics: string[] = [];
    for (const mastery of state.topicMastery) {
      const hasActiveReview = state.reviewItems.some((item: ReviewItem): boolean =>
        !item.resolved && item.courseId === mastery.courseId && item.topic === mastery.topic);
      if (!mastery.mastered || hasActiveReview) {
        if (!weakTopics.includes(mastery.topic)) weakTopics.push(mastery.topic);
      } else if (!strongTopics.includes(mastery.topic)) {
        strongTopics.push(mastery.topic);
      }
    }
    state.weakTopics = weakTopics;
    state.strongTopics = strongTopics;
  }

  static ensureMasteryMilestones(state: QuizLearningState): void {
    for (const event of state.quizEvents) {
      if (event.type !== 'quiz_mastered' || event.courseId === undefined || event.topic === undefined) continue;
      const existing = state.masteryMilestones.find((item: TopicMasteryMilestone): boolean =>
        item.courseId === event.courseId && item.topic === event.topic);
      if (existing !== undefined) continue;
      let masteredAt = event.timestamp;
      for (const related of state.quizEvents) {
        if (related.type === 'quiz_mastered' && related.courseId === event.courseId && related.topic === event.topic &&
          related.timestamp < masteredAt) masteredAt = related.timestamp;
      }
      state.masteryMilestones.push({
        courseId: event.courseId,
        topic: event.topic,
        masteredAt: masteredAt
      });
    }
    for (const mastery of state.topicMastery) {
      if (!mastery.mastered || mastery.lastPracticedAt === undefined) continue;
      const existing = state.masteryMilestones.find((item: TopicMasteryMilestone): boolean =>
        item.courseId === mastery.courseId && item.topic === mastery.topic);
      if (existing === undefined) {
        state.masteryMilestones.push({
          courseId: mastery.courseId,
          topic: mastery.topic,
          masteredAt: mastery.lastPracticedAt
        });
      }
    }
  }

  static masteryTotals(mastery: TopicMastery[]): QuizLearningStats {
    const stats: QuizLearningStats = {
      totalAttempts: 0,
      totalQuestions: 0,
      correctQuestions: 0,
      quizDates: []
    };
    for (const item of mastery) {
      stats.totalAttempts += item.attempts;
      stats.totalQuestions += item.totalQuestions;
      stats.correctQuestions += item.correctQuestions;
      if (item.lastPracticedAt !== undefined) {
        const date = QuizLearningStateReducer.localDateKey(item.lastPracticedAt);
        if (!stats.quizDates.includes(date)) stats.quizDates.push(date);
        if (stats.firstSubmittedAt === undefined || item.lastPracticedAt < stats.firstSubmittedAt) {
          stats.firstSubmittedAt = item.lastPracticedAt;
        }
      }
    }
    return stats;
  }

  private static applyTopicMastery(mastery: TopicMastery[], result: QuizResult): void {
    let item = mastery.find((value: TopicMastery): boolean =>
      value.courseId === result.courseId && value.topic === result.topic);
    if (item === undefined) {
      item = {
        courseId: result.courseId,
        topic: result.topic,
        attempts: 0,
        totalQuestions: 0,
        correctQuestions: 0,
        accuracy: 0,
        mastered: false
      };
      mastery.push(item);
    }
    item.attempts += 1;
    item.totalQuestions += result.totalQuestions;
    item.correctQuestions += result.correctCount;
    item.accuracy = item.totalQuestions > 0 ? item.correctQuestions / item.totalQuestions : 0;
    item.mastered = item.accuracy >= 0.8;
    item.lastPracticedAt = result.submittedAt;
  }

  private static recordMasteryMilestone(state: QuizLearningState, result: QuizResult): void {
    const mastery = state.topicMastery.find((item: TopicMastery): boolean =>
      item.courseId === result.courseId && item.topic === result.topic);
    if (mastery === undefined || !mastery.mastered) return;
    const existing = state.masteryMilestones.find((item: TopicMasteryMilestone): boolean =>
      item.courseId === result.courseId && item.topic === result.topic);
    if (existing === undefined) {
      state.masteryMilestones.push({
        courseId: result.courseId,
        topic: result.topic,
        masteredAt: result.submittedAt
      });
    }
  }

  private static applyReviewItems(state: QuizLearningState, result: QuizResult): void {
    for (const detail of result.details) {
      const existingIndex = QuizLearningStateReducer.reviewIndex(state.reviewItems, result, detail);
      if (detail.isCorrect) {
        if (existingIndex >= 0) {
          const previous = state.reviewItems[existingIndex];
          const due = QuizLearningStateReducer.isReviewDue(previous, result.submittedAt);
          const nextInterval = due ?
            QuizLearningStateReducer.nextReviewInterval(previous.intervalDays) : previous.intervalDays;
          const next: ReviewItem = {
            id: previous.id,
            quizId: previous.quizId ?? QuizLearningStateReducer.sourceQuizId(result),
            questionId: previous.questionId,
            courseId: previous.courseId,
            topic: previous.topic,
            source: previous.source,
            stem: detail.stem,
            options: detail.options ?? previous.options ?? [],
            userAnswer: detail.userAnswer,
            correctAnswer: detail.correctAnswer,
            explanation: detail.explanation,
            attempts: previous.attempts + 1,
            resolved: due ? nextInterval === 0 : previous.resolved,
            intervalDays: due && nextInterval > 0 ? nextInterval : previous.intervalDays,
            nextReviewAt: due ? (nextInterval === 0 ? result.submittedAt :
              QuizLearningStateReducer.addDays(result.submittedAt, nextInterval)) : previous.nextReviewAt,
            updatedAt: result.submittedAt,
            difficulty: detail.difficulty ?? previous.difficulty,
            tags: detail.tags ?? previous.tags ?? []
          };
          state.reviewItems[existingIndex] = next;
        }
        continue;
      }

      const previous = existingIndex >= 0 ? state.reviewItems[existingIndex] : undefined;
      const next: ReviewItem = {
        id: previous?.id ?? QuizLearningStateReducer.reviewId(result, detail),
        quizId: previous?.quizId ?? QuizLearningStateReducer.sourceQuizId(result),
        questionId: previous?.questionId ?? detail.questionId,
        courseId: previous?.courseId ?? result.courseId,
        topic: previous?.topic ?? result.topic,
        source: previous?.source ?? result.source,
        stem: detail.stem,
        options: detail.options ?? previous?.options ?? [],
        userAnswer: detail.userAnswer,
        correctAnswer: detail.correctAnswer,
        explanation: detail.explanation,
        attempts: (previous?.attempts ?? 0) + 1,
        resolved: false,
        intervalDays: 1,
        nextReviewAt: QuizLearningStateReducer.addDays(result.submittedAt, 1),
        updatedAt: result.submittedAt,
        difficulty: detail.difficulty ?? previous?.difficulty ?? result.difficulty,
        tags: detail.tags ?? previous?.tags ?? []
      };
      if (existingIndex >= 0) state.reviewItems[existingIndex] = next;
      else state.reviewItems.push(next);
    }
    state.reviewItems = QuizLearningStateReducer.compactReviewItems(state.reviewItems);
  }

  private static reviewIndex(items: ReviewItem[], result: QuizResult, detail: QuizResultDetail): number {
    if (detail.reviewItemId !== undefined && detail.reviewItemId.length > 0) {
      return items.findIndex((item: ReviewItem): boolean => item.id === detail.reviewItemId);
    }
    return items.findIndex((item: ReviewItem): boolean => {
      if (item.courseId !== result.courseId || item.questionId !== detail.questionId) return false;
      if (result.source === 'curated' && item.source === 'curated') return true;
      return item.quizId === QuizLearningStateReducer.sourceQuizId(result);
    });
  }

  private static reviewId(result: QuizResult, detail: QuizResultDetail): string {
    if (result.source === 'curated') {
      return 'review_' + result.courseId + '_' + detail.questionId;
    }
    return 'review_' + QuizLearningStateReducer.sourceQuizId(result) + '_' + detail.questionId;
  }

  private static sourceQuizId(result: QuizResult): string {
    const sourceQuizId = result.sourceQuizId ?? '';
    return sourceQuizId.length > 0 ? sourceQuizId : result.quizId;
  }

  private static compactReviewItems(items: ReviewItem[]): ReviewItem[] {
    const active = items.filter((item: ReviewItem): boolean => !item.resolved);
    const resolved = items.filter((item: ReviewItem): boolean => item.resolved);
    resolved.sort((left: ReviewItem, right: ReviewItem): number =>
      left.updatedAt.localeCompare(right.updatedAt));
    return active.concat(resolved.slice(-RESOLVED_REVIEW_LIMIT));
  }

  private static nextReviewInterval(currentIntervalDays: number): number {
    if (currentIntervalDays < 1) return 1;
    if (currentIntervalDays < 3) return 3;
    if (currentIntervalDays < 7) return 7;
    if (currentIntervalDays < 14) return 14;
    return 0;
  }

  private static isReviewDue(item: ReviewItem, submittedAt: string): boolean {
    const nextReviewTime = new Date(item.nextReviewAt).getTime();
    if (Number.isNaN(nextReviewTime)) return true;
    return new Date(submittedAt).getTime() >= nextReviewTime;
  }

  private static applyTagInsights(insights: TagInsight[], result: QuizResult): void {
    for (const detail of result.details) {
      const seenTags: string[] = [];
      for (const rawTag of detail.tags ?? []) {
        const tag = rawTag.trim();
        if (tag.length === 0 || seenTags.includes(tag)) continue;
        seenTags.push(tag);
        const insightKey = QuizLearningStateReducer.tagInsightKey(result.courseId, result.topic, tag);
        let item = insights.find((value: TagInsight): boolean =>
          QuizLearningStateReducer.tagInsightKey(value.courseId, value.topic, value.tag) === insightKey);
        if (item === undefined) {
          item = QuizLearningStateReducer.emptyTagInsight(tag, result, detail);
          insights.push(item);
        }
        const difficulty = detail.difficulty ?? result.difficulty ?? 'medium';
        item.totalQuestions += 1;
        if (detail.isCorrect) item.correctQuestions += 1;
        if (difficulty === 'easy') item.easyQuestions += 1;
        else if (difficulty === 'hard') item.hardQuestions += 1;
        else item.mediumQuestions += 1;
        item.wrongQuestions = item.totalQuestions - item.correctQuestions;
        item.accuracy = item.totalQuestions > 0 ? item.correctQuestions / item.totalQuestions : 0;
        item.lastPracticedAt = result.submittedAt;
        item.lastDifficulty = difficulty;
        item.masteryPoints = QuizLearningStateReducer.tagMasteryPoints(item);
        item.masteryLevel = QuizLearningStateReducer.tagMasteryLevel(item.masteryPoints);
        item.weakReason = QuizLearningStateReducer.tagWeakReason(item);
        item.nextStep = QuizLearningStateReducer.tagNextStep(item);
      }
    }
  }

  static tagInsightKey(courseId: string, topic: string, tag: string): string {
    return JSON.stringify([courseId, topic, tag]);
  }

  static applyLearningInsightEvent(state: QuizLearningState, event: StudyEvent): boolean {
    if (event.type !== 'lesson_activity' || event.id.trim().length === 0) return false;
    const courseId = event.courseId ?? '';
    const topic = event.topic ?? '';
    if (courseId.length === 0 || topic.length === 0) return false;
    const normalizedTags: string[] = [];
    for (const rawTag of event.tags ?? []) {
      const tag = rawTag.trim();
      if (tag.length > 0 && !normalizedTags.includes(tag)) normalizedTags.push(tag);
    }
    if (normalizedTags.length === 0 || state.appliedInsightEventIds.includes(event.id)) return false;
    state.appliedInsightEventIds.push(event.id);
    const totalQuestions = Math.max(0, event.totalQuestions ?? 1);
    const correctQuestions = Math.max(0, Math.min(totalQuestions, event.correctCount ?? 0));
    const difficulty = event.difficulty ?? 'easy';
    for (const tag of normalizedTags) {
      const insightKey = QuizLearningStateReducer.tagInsightKey(courseId, topic, tag);
      let item = state.tagInsights.find((value: TagInsight): boolean =>
        QuizLearningStateReducer.tagInsightKey(value.courseId, value.topic, value.tag) === insightKey);
      if (item === undefined) {
        item = QuizLearningStateReducer.emptyEventTagInsight(tag, courseId, topic, event.timestamp, difficulty);
        state.tagInsights.push(item);
      }
      item.totalQuestions += totalQuestions;
      item.correctQuestions += correctQuestions;
      if (difficulty === 'hard') item.hardQuestions += totalQuestions;
      else if (difficulty === 'medium') item.mediumQuestions += totalQuestions;
      else item.easyQuestions += totalQuestions;
      item.wrongQuestions = item.totalQuestions - item.correctQuestions;
      item.accuracy = item.totalQuestions > 0 ? item.correctQuestions / item.totalQuestions : 0;
      if (event.timestamp >= item.lastPracticedAt) {
        item.lastPracticedAt = event.timestamp;
        item.lastDifficulty = difficulty;
      }
      item.masteryPoints = QuizLearningStateReducer.tagMasteryPoints(item);
      item.masteryLevel = QuizLearningStateReducer.tagMasteryLevel(item.masteryPoints);
      item.weakReason = QuizLearningStateReducer.tagWeakReason(item);
      item.nextStep = QuizLearningStateReducer.tagNextStep(item);
    }
    return true;
  }

  static compactQuizEvents(events: StudyEvent[]): StudyEvent[] {
    return events.length > QUIZ_EVENT_LIMIT ? events.slice(-QUIZ_EVENT_LIMIT) : events;
  }

  private static emptyEventTagInsight(tag: string, courseId: string, topic: string,
    timestamp: string, difficulty: string): TagInsight {
    return {
      tag: tag,
      courseId: courseId,
      topic: topic,
      totalQuestions: 0,
      correctQuestions: 0,
      accuracy: 0,
      wrongQuestions: 0,
      lastPracticedAt: timestamp,
      easyQuestions: 0,
      mediumQuestions: 0,
      hardQuestions: 0,
      lastDifficulty: difficulty,
      masteryLevel: '尝试',
      masteryPoints: 0,
      weakReason: '',
      nextStep: ''
    };
  }

  private static emptyTagInsight(tag: string, result: QuizResult, detail: QuizResultDetail): TagInsight {
    return {
      tag: tag,
      courseId: result.courseId,
      topic: result.topic,
      totalQuestions: 0,
      correctQuestions: 0,
      accuracy: 0,
      wrongQuestions: 0,
      lastPracticedAt: result.submittedAt,
      easyQuestions: 0,
      mediumQuestions: 0,
      hardQuestions: 0,
      lastDifficulty: detail.difficulty ?? result.difficulty ?? 'medium',
      masteryLevel: '尝试',
      masteryPoints: 0,
      weakReason: '',
      nextStep: ''
    };
  }

  private static appendQuizEvent(events: StudyEvent[], result: QuizResult): void {
    const event: StudyEvent = {
      id: 'quiz_' + result.quizId,
      type: result.accuracy >= 0.8 ? 'quiz_mastered' : 'quiz_submitted',
      timestamp: result.submittedAt,
      courseId: result.courseId,
      topic: result.topic,
      source: result.source,
      difficulty: result.difficulty,
      accuracy: result.accuracy,
      tags: QuizLearningStateReducer.collectResultTags(result),
      totalQuestions: result.totalQuestions,
      correctCount: result.correctCount
    };
    events.push(event);
  }

  private static collectResultTags(result: QuizResult): string[] {
    const tags: string[] = [];
    const wrongDetails = result.details.filter((detail: QuizResultDetail): boolean => !detail.isCorrect);
    const source = wrongDetails.length > 0 ? wrongDetails : result.details;
    for (const detail of source) {
      for (const rawTag of detail.tags ?? []) {
        const tag = rawTag.trim();
        if (tag.length > 0 && !tags.includes(tag)) tags.push(tag);
      }
    }
    return tags.slice(0, 6);
  }

  private static tagMasteryPoints(item: TagInsight): number {
    if (item.totalQuestions <= 0) return 0;
    const evidenceBonus = Math.min(item.totalQuestions * 6, 18);
    const difficultyBonus = item.hardQuestions > 0 ? 10 : (item.mediumQuestions > 0 ? 6 : 2);
    const accuracyPoints = Math.round(item.accuracy * 72);
    const penalty = Math.min(item.wrongQuestions * 8, 24);
    return Math.max(0, Math.min(100, accuracyPoints + evidenceBonus + difficultyBonus - penalty));
  }

  private static tagMasteryLevel(points: number): string {
    if (points >= 88) return '掌握';
    if (points >= 72) return '熟练';
    if (points >= 48) return '熟悉';
    if (points >= 20) return '尝试';
    return '未开始';
  }

  private static tagWeakReason(item: TagInsight): string {
    if (item.wrongQuestions === 0) return '最近答题稳定，暂未形成错题';
    if (item.accuracy < 0.6) return '正确率低于 60%，说明概念或判断步骤不稳';
    if (item.wrongQuestions >= 2) return '错题重复出现，建议按标签集中复盘';
    return '偶发失误，适合用短练习巩固';
  }

  private static tagNextStep(item: TagInsight): string {
    if (item.wrongQuestions === 0) return '继续挑战同主题进阶题';
    if (item.easyQuestions > 0 && item.accuracy < 0.7) return '先做基础题，确认定义和关键条件';
    if (item.hardQuestions > 0) return '复盘挑战题，拆解边界条件和推理步骤';
    return '练 5 道同标签题，再查看错题解析';
  }

  private static addDays(timestamp: string, days: number): string {
    const date = new Date(timestamp);
    date.setDate(date.getDate() + days);
    return date.toISOString();
  }

  static localDateKey(timestamp: string): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }
}
