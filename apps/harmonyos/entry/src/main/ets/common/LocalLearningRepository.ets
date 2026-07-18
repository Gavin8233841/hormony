import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  ChatMessage,
  AchievementProgress,
  Course,
  LessonProgress,
  PlanTaskUpdateReceipt,
  StudyPlan,
  TopicMastery,
  UserProfile
} from '../model/DataModels';
import {
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail,
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight,
  LegacyQuizHistorySnapshot,
  LegacyQuizTopicHistorySnapshot,
  QuizLearningState,
  QuizWriteReceipt,
  TopicMasteryMilestone
} from '../model/LearningMetadataModels';
import { LearningContentRepository } from './LearningContentRepository';
import { QuizLearningStateReducer } from './QuizLearningStateReducer';

const STORE_NAME: string = 'hongxueban_learning.db';
const TABLE_NAME: string = 'app_state';
const SCHEMA_VERSION: number = 12;

const KEY_PROFILE: string = 'profile';
const KEY_COURSES: string = 'courses';
const KEY_PLAN: string = 'plan';
const KEY_QUIZ_RESULTS: string = 'quiz_results';
const KEY_CHAT_HISTORY: string = 'chat_history';
const KEY_STUDY_EVENTS: string = 'study_events';
const KEY_LESSON_PROGRESS: string = 'lesson_progress';
const KEY_REVIEW_ITEMS: string = 'review_items';
const KEY_TOPIC_MASTERY: string = 'topic_mastery';
const KEY_QUIZ_STATS: string = 'quiz_stats';
const KEY_QUIZ_LEARNING_STATE: string = 'quiz_learning_state';
const KEY_FORM_IDS: string = 'form_ids';

interface LegacyQuizStatsAggregate {
  totalQuestions: number;
  accuracy: number;
  studyDates: string[];
  updatedAt: string;
}

interface StoredValue<T> {
  value: T;
  updatedAt: number;
}

interface LegacyResultInclusion {
  statsAlreadyIncluded: boolean;
  topicAlreadyIncluded: boolean;
}

interface LegacyReplayEntry {
  result: QuizResult;
  resultIndex: number;
  inclusion: LegacyResultInclusion;
}

export interface ReviewQueueSnapshot {
  activeItems: ReviewItem[];
  dueItems: ReviewItem[];
}

export class LocalLearningRepository {
  private static store: relationalStore.RdbStore | null = null;
  private static initializationTask: Promise<void> | null = null;
  private static quizStateQueue: Promise<void> = Promise.resolve();
  private static lessonProgressQueue: Promise<void> = Promise.resolve();
  private static planQueue: Promise<void> = Promise.resolve();

  static async initialize(context: common.Context): Promise<void> {
    if (LocalLearningRepository.initializationTask !== null) {
      return LocalLearningRepository.initializationTask;
    }
    if (LocalLearningRepository.store !== null) return;

    const operation = LocalLearningRepository.initializeStore(context);
    LocalLearningRepository.initializationTask = operation;
    try {
      await operation;
    } finally {
      LocalLearningRepository.initializationTask = null;
    }
  }

  private static async initializeStore(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: STORE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    let store: relationalStore.RdbStore;
    try {
      store = await relationalStore.getRdbStore(context, config);
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS ' + TABLE_NAME +
        ' (state_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)'
      );
    } catch (error) {
      throw new Error('本地学习仓库初始化失败: ' + String(error));
    }
    LocalLearningRepository.store = store;
    try {
      const previousVersion = await LocalLearningRepository.getValue<number>('schema_version') ?? 0;
      await LocalLearningRepository.migrate(previousVersion);
      await LocalLearningRepository.putValue<number>('schema_version', SCHEMA_VERSION);
      await LocalLearningRepository.ensureDefaults();
      await LocalLearningRepository.flushPendingLessonCompletionEvents();
    } catch (error) {
      LocalLearningRepository.store = null;
      throw new Error('本地学习仓库初始化失败: ' + String(error));
    }
  }

  private static async migrate(previousVersion: number): Promise<void> {
    if (previousVersion < 2) {
      const profile = await LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
      if (profile !== null && profile.stats.totalQuestions === 128 &&
        Math.abs(profile.stats.accuracy - 0.76) < 0.001 && profile.stats.studyDays === 23) {
        profile.stats = { totalQuestions: 0, accuracy: 0, studyDays: 0, streakDays: 0 };
        profile.weakTopics = [];
        profile.strongTopics = [];
        await LocalLearningRepository.putValue<UserProfile>(KEY_PROFILE, profile);
      }
      const courses = await LocalLearningRepository.getValue<Course[]>(KEY_COURSES);
      if (courses !== null) {
        const resetCourses: Course[] = courses.map((course: Course): Course => {
          return {
            id: course.id,
            title: course.title,
            progress: 0,
            docCount: course.docCount,
            topics: course.topics
          };
        });
        await LocalLearningRepository.putValue<Course[]>(KEY_COURSES, resetCourses);
      }
      await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, []);
    }
    if (previousVersion < 3) {
      const plan = await LocalLearningRepository.getValue<StudyPlan>(KEY_PLAN);
      if (plan !== null && plan.planId === 'local-plan' &&
        plan.tasks.some((task): boolean => task.id === 't3' && task.title === '学习二叉树遍历')) {
        await LocalLearningRepository.putValue<StudyPlan | null>(KEY_PLAN, null);
      }
    }
    if (previousVersion < 4) {
      await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, []);
      await LocalLearningRepository.putValue<ReviewItem[]>(KEY_REVIEW_ITEMS, []);
    }
    if (previousVersion < 5) {
      const items = await LocalLearningRepository.getValue<ReviewItem[]>(KEY_REVIEW_ITEMS);
      if (items !== null) {
        for (const item of items) {
          item.intervalDays = item.intervalDays ?? 1;
          item.nextReviewAt = item.nextReviewAt ?? item.updatedAt;
        }
        await LocalLearningRepository.putValue<ReviewItem[]>(KEY_REVIEW_ITEMS, items);
      }
    }
    if (previousVersion < 6) {
      const results = (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
      const state = QuizLearningStateReducer.createEmptyState();
      for (const result of results.slice().reverse()) QuizLearningStateReducer.applyResult(state, result);
      await LocalLearningRepository.putValue<TopicMastery[]>(KEY_TOPIC_MASTERY, state.topicMastery);
    }
    if (previousVersion < 11) {
      await LocalLearningRepository.migrateQuizLearningState();
    }
    if (previousVersion < 12) {
      await LocalLearningRepository.migrateLessonCompletionOutbox();
    }
  }

  private static async migrateLessonCompletionOutbox(): Promise<void> {
    const items = await LocalLearningRepository.loadLessonProgressUnlocked();
    const events = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
    for (const item of items) {
      if (!LocalLearningRepository.isValidCompletedLessonProgress(item)) continue;
      const existing = events.find((event: StudyEvent): boolean =>
        event.type === 'lesson_completed' && event.courseId === item.courseId &&
        event.topic === item.topic && event.id.trim().length > 0 &&
        !Number.isNaN(new Date(event.timestamp).getTime()));
      if (existing !== undefined) {
        item.completionEventId = existing.id;
        item.completionEventSyncedAt = existing.timestamp;
      } else {
        item.completionEventId = LocalLearningRepository.buildLessonCompletionEventId(item.courseId, item.topic);
        item.completionEventSyncedAt = undefined;
      }
    }
    await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, items);
  }

  private static async migrateQuizLearningState(): Promise<void> {
    return LocalLearningRepository.runQuizStateTask(async (): Promise<void> => {
      const storedExisting = await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE);
      const existing = storedExisting !== null && typeof storedExisting === 'object' &&
        !Array.isArray(storedExisting) ? storedExisting : null;
      const storedLegacyEvents = await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS);
      const legacyEvents = Array.isArray(storedLegacyEvents) ? storedLegacyEvents : [];
      const validLegacyEvents = legacyEvents.filter((event: StudyEvent): boolean =>
        LocalLearningRepository.isValidStoredStudyEvent(event));
      const retainedStudyEvents = validLegacyEvents.filter((event: StudyEvent): boolean =>
        event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted').slice(-500);
      if (existing !== null) {
        LocalLearningRepository.prepareQuizLearningStateContainers(existing);
        LocalLearningRepository.sanitizeQuizLearningState(existing);
        QuizLearningStateReducer.preparePersistentState(existing);
        const pendingResults = existing.pendingResults.slice();
        const legacyStatsRow = await LocalLearningRepository.getStoredValue<LegacyQuizStatsAggregate>(KEY_QUIZ_STATS);
        const legacyStats = legacyStatsRow?.value ?? null;
        const legacyMasteryRow = await LocalLearningRepository.getStoredValue<TopicMastery[]>(KEY_TOPIC_MASTERY);
        const legacyMastery = legacyMasteryRow?.value ?? null;
        const legacyResultsRow = await LocalLearningRepository.getStoredValue<QuizResult[]>(KEY_QUIZ_RESULTS);
        const legacyResults = legacyResultsRow?.value ?? [];
        const legacyResultIds = LocalLearningRepository.validateLegacyResultWindow(legacyResults);
        const legacySnapshot = LocalLearningRepository.buildLegacyHistorySnapshot(
          legacyStats, legacyMastery, legacyResultIds);
        const previousSnapshot = existing.legacyHistorySnapshot;
        if (previousSnapshot !== undefined &&
          !LocalLearningRepository.isValidLegacyHistorySnapshot(previousSnapshot)) {
          throw new Error('旧测验累计迁移快照无效，无法安全继续迁移');
        }
        if (previousSnapshot !== undefined && legacySnapshot === null) {
          throw new Error('旧测验累计来源无效，无法安全继续迁移');
        }
        let newLegacyResults: QuizResult[] = [];
        if (previousSnapshot === undefined) {
          newLegacyResults = LocalLearningRepository.extractNewLegacyResultsWithoutSnapshot(existing, legacyResults);
          if (legacySnapshot !== null && newLegacyResults.length === 0) {
            const appendLegacyHistory = LocalLearningRepository.legacyHistoryPrecedesState(existing, legacySnapshot);
            LocalLearningRepository.mergeLegacyTopicMastery(existing, legacyMastery, appendLegacyHistory);
            LocalLearningRepository.mergeLegacyQuizStats(existing, legacyStats, appendLegacyHistory);
          }
        } else if (legacySnapshot !== null) {
          newLegacyResults = LocalLearningRepository.extractNewLegacyResults(
            existing, previousSnapshot.resultIds, legacyResults);
          LocalLearningRepository.validateLegacyHistoryProgress(
            existing, previousSnapshot, legacySnapshot, newLegacyResults);
        }
        QuizLearningStateReducer.applyPendingResults(existing);
        LocalLearningRepository.recoverLegacyResults(existing, newLegacyResults, pendingResults);
        LocalLearningRepository.mergeLegacyRecentResults(existing, legacyResults);
        const legacyReviews = await LocalLearningRepository.getValue<ReviewItem[]>(KEY_REVIEW_ITEMS);
        LocalLearningRepository.mergeLegacyReviewItems(existing, legacyReviews);
        const unmatchedLegacyEvents = LocalLearningRepository.unmatchedLegacyEvents(
          existing, validLegacyEvents, legacyResults);
        LocalLearningRepository.mergeLegacyQuizEvents(existing, unmatchedLegacyEvents);
        for (const event of unmatchedLegacyEvents) QuizLearningStateReducer.applyLearningInsightEvent(existing, event);
        if (legacySnapshot !== null) {
          existing.legacyHistorySnapshot = legacySnapshot;
        }
        QuizLearningStateReducer.refreshProfileTopics(existing);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, existing);
        await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, retainedStudyEvents);
        return;
      }

      const state = QuizLearningStateReducer.createEmptyState();
      const legacyResultsRow = await LocalLearningRepository.getStoredValue<QuizResult[]>(KEY_QUIZ_RESULTS);
      const legacyResults = legacyResultsRow?.value ?? [];
      const legacyResultIds = LocalLearningRepository.validateLegacyResultWindow(legacyResults);
      const legacyMasteryRow = await LocalLearningRepository.getStoredValue<TopicMastery[]>(KEY_TOPIC_MASTERY);
      const legacyMastery = legacyMasteryRow?.value ?? null;
      const legacyStatsRow = await LocalLearningRepository.getStoredValue<LegacyQuizStatsAggregate>(KEY_QUIZ_STATS);
      const legacyStats = legacyStatsRow?.value ?? null;
      const legacySnapshot = LocalLearningRepository.buildLegacyHistorySnapshot(
        legacyStats, legacyMastery, legacyResultIds);
      const replayEntries: LegacyReplayEntry[] = legacyResults.map(
        (result: QuizResult, index: number): LegacyReplayEntry => {
          return {
            result: result,
            resultIndex: index,
            inclusion: LocalLearningRepository.legacyResultInclusion(
              legacySnapshot, result, index, legacyResultsRow, legacyStatsRow, legacyMasteryRow)
          };
        });
      LocalLearningRepository.seedLegacyAggregateBaseline(
        state, legacySnapshot, legacyMastery, legacyStats, replayEntries);
      replayEntries.sort((left: LegacyReplayEntry, right: LegacyReplayEntry): number => {
        const timestampOrder = new Date(left.result.submittedAt).getTime() -
          new Date(right.result.submittedAt).getTime();
        return timestampOrder !== 0 ? timestampOrder : right.resultIndex - left.resultIndex;
      });
      for (const entry of replayEntries) {
        QuizLearningStateReducer.applyResult(state, entry.result);
      }
      const generatedReviews = state.reviewItems.slice();
      const legacyReviews = await LocalLearningRepository.getValue<ReviewItem[]>(KEY_REVIEW_ITEMS);
      if (legacyReviews !== null) {
        state.reviewItems = legacyReviews.filter((item: ReviewItem): boolean =>
          LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
        for (const generated of generatedReviews) {
          const index = state.reviewItems.findIndex((item: ReviewItem): boolean =>
            item.courseId === generated.courseId && item.topic === generated.topic &&
            item.questionId === generated.questionId && item.stem === generated.stem);
          if (index < 0) {
            state.reviewItems.push(generated);
          } else if ((state.reviewItems[index].options ?? []).length === 0 &&
            (generated.options ?? []).length > 0) {
            state.reviewItems[index].options = generated.options;
            state.reviewItems[index].quizId = generated.quizId;
          }
        }
      }

      const generatedEvents = state.quizEvents.slice();
      const unmatchedLegacyEvents = LocalLearningRepository.unmatchedLegacyEvents(
        state, validLegacyEvents, legacyResults);
      state.masteryMilestones = [];
      state.quizEvents = unmatchedLegacyEvents.filter((event: StudyEvent): boolean =>
        event.type === 'quiz_mastered' || event.type === 'quiz_submitted');
      QuizLearningStateReducer.mergeQuizEvents(state, generatedEvents);
      for (const event of state.quizEvents) {
        const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
        if (!state.stats.quizDates.includes(date)) state.stats.quizDates.push(date);
        LocalLearningRepository.mergeFirstSubmittedAt(state, event.timestamp);
      }
      for (const event of unmatchedLegacyEvents) {
        QuizLearningStateReducer.applyLearningInsightEvent(state, event);
      }
      QuizLearningStateReducer.refreshProfileTopics(state);
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, retainedStudyEvents);
    });
  }

  private static isNonNegativeInteger(value: number): boolean {
    return Number.isFinite(value) && value >= 0 && Math.floor(value) === value;
  }

  private static timestampPrecedes(incoming: string, current: string): boolean {
    const incomingTime = new Date(incoming).getTime();
    const currentTime = new Date(current).getTime();
    return !Number.isNaN(incomingTime) && !Number.isNaN(currentTime) && incomingTime < currentTime;
  }

  private static compareTimestamps(left: string, right: string): number {
    const leftTime = new Date(left).getTime();
    const rightTime = new Date(right).getTime();
    if (!Number.isNaN(leftTime) && !Number.isNaN(rightTime)) return leftTime - rightTime;
    if (!Number.isNaN(leftTime)) return -1;
    if (!Number.isNaN(rightTime)) return 1;
    return left.localeCompare(right);
  }

  private static mergeFirstSubmittedAt(state: QuizLearningState, timestamp: string): void {
    const incomingTime = new Date(timestamp).getTime();
    if (Number.isNaN(incomingTime)) return;
    if (state.stats.firstSubmittedAt === undefined ||
      LocalLearningRepository.timestampPrecedes(timestamp, state.stats.firstSubmittedAt)) {
      state.stats.firstSubmittedAt = timestamp;
    }
  }

  private static isValidLegacyQuizStats(legacy: LegacyQuizStatsAggregate | null): boolean {
    if (legacy === null || !LocalLearningRepository.isNonNegativeInteger(legacy.totalQuestions) ||
      !Number.isFinite(legacy.accuracy) || legacy.accuracy < 0 || legacy.accuracy > 1 ||
      !Array.isArray(legacy.studyDates) || typeof legacy.updatedAt !== 'string' ||
      Number.isNaN(new Date(legacy.updatedAt).getTime())) return false;
    return legacy.studyDates.every((date: string): boolean => typeof date === 'string');
  }

  private static isValidLegacyTopicMastery(item: TopicMastery): boolean {
    return item !== null && typeof item === 'object' && typeof item.courseId === 'string' &&
      typeof item.topic === 'string' && LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) &&
      LocalLearningRepository.isNonNegativeInteger(item.attempts) &&
      LocalLearningRepository.isNonNegativeInteger(item.totalQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(item.correctQuestions) &&
      item.correctQuestions <= item.totalQuestions &&
      (item.lastPracticedAt === undefined || !Number.isNaN(new Date(item.lastPracticedAt).getTime()));
  }

  private static isValidLegacyQuizResult(result: QuizResult): boolean {
    if (result === null || typeof result !== 'object' || typeof result.quizId !== 'string' ||
      result.quizId.trim().length === 0 || typeof result.courseId !== 'string' ||
      typeof result.topic !== 'string' || !LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic) ||
      typeof result.userId !== 'string' || typeof result.source !== 'string' ||
      (result.source !== 'ai' && result.source !== 'curated') ||
      (result.sourceQuizId !== undefined && typeof result.sourceQuizId !== 'string') ||
      (result.difficulty !== undefined && !LocalLearningRepository.isQuizDifficulty(result.difficulty)) ||
      !LocalLearningRepository.isNonNegativeInteger(result.totalQuestions) || result.totalQuestions === 0 ||
      !LocalLearningRepository.isNonNegativeInteger(result.correctCount) ||
      result.correctCount > result.totalQuestions || !Array.isArray(result.details) ||
      result.details.length !== result.totalQuestions || typeof result.submittedAt !== 'string' ||
      Number.isNaN(new Date(result.submittedAt).getTime()) || !Number.isFinite(result.accuracy) ||
      typeof result.evaluation !== 'string' || !LocalLearningRepository.isStringArray(result.weakTopics)) return false;
    const questionIds: string[] = [];
    let detailCorrectCount = 0;
    for (const detail of result.details) {
      if (detail === null || typeof detail !== 'object' || typeof detail.questionId !== 'string' ||
        detail.questionId.trim().length === 0 || questionIds.includes(detail.questionId) ||
        typeof detail.stem !== 'string' || typeof detail.userAnswer !== 'string' ||
        typeof detail.correctAnswer !== 'string' || typeof detail.isCorrect !== 'boolean' ||
        typeof detail.explanation !== 'string' ||
        !LocalLearningRepository.isStringArray(detail.options) ||
        !LocalLearningRepository.isStringArray(detail.tags) ||
        (detail.reviewItemId !== undefined && typeof detail.reviewItemId !== 'string') ||
        (detail.difficulty !== undefined && !LocalLearningRepository.isQuizDifficulty(detail.difficulty))) return false;
      questionIds.push(detail.questionId);
      if (detail.isCorrect) detailCorrectCount += 1;
    }
    const expectedAccuracy = detailCorrectCount / result.totalQuestions;
    return detailCorrectCount === result.correctCount && Math.abs(result.accuracy - expectedAccuracy) <= 0.0001;
  }

  private static isStringArray(value: string[] | undefined): boolean {
    if (value === undefined) return true;
    if (!Array.isArray(value)) return false;
    return value.every((item: string): boolean => typeof item === 'string');
  }

  private static isQuizDifficulty(value: string): boolean {
    return value === 'easy' || value === 'medium' || value === 'hard';
  }

  private static validateLegacyResultWindow(results: QuizResult[]): string[] {
    if (!Array.isArray(results) || results.length > 20) {
      throw new Error('旧测验结果窗口无效，无法安全迁移');
    }
    const resultIds: string[] = [];
    for (const result of results) {
      if (!LocalLearningRepository.isValidLegacyQuizResult(result) || resultIds.includes(result.quizId)) {
        throw new Error('旧测验结果窗口无效，无法安全迁移');
      }
      resultIds.push(result.quizId);
    }
    return resultIds;
  }

  private static buildLegacyHistorySnapshot(legacy: LegacyQuizStatsAggregate | null,
    mastery: TopicMastery[] | null, resultIds: string[]): LegacyQuizHistorySnapshot | null {
    if (legacy === null || !LocalLearningRepository.isValidLegacyQuizStats(legacy)) return null;
    const topicMastery: LegacyQuizTopicHistorySnapshot[] = [];
    const topicKeys: string[] = [];
    for (const item of mastery ?? []) {
      if (!LocalLearningRepository.isValidLegacyTopicMastery(item)) return null;
      const topicKey = JSON.stringify([item.courseId, item.topic]);
      if (topicKeys.includes(topicKey)) return null;
      topicKeys.push(topicKey);
      topicMastery.push({
        courseId: item.courseId,
        topic: item.topic,
        attempts: item.attempts,
        totalQuestions: item.totalQuestions,
        correctQuestions: item.correctQuestions,
        lastPracticedAt: item.lastPracticedAt
      });
    }
    return {
      updatedAt: legacy.updatedAt,
      totalQuestions: legacy.totalQuestions,
      correctQuestions: Math.round(legacy.totalQuestions * legacy.accuracy),
      resultIds: resultIds.slice(),
      topicMastery: topicMastery
    };
  }

  private static isValidLegacyHistorySnapshot(snapshot: LegacyQuizHistorySnapshot): boolean {
    if (snapshot === null || typeof snapshot !== 'object' || typeof snapshot.updatedAt !== 'string' ||
      Number.isNaN(new Date(snapshot.updatedAt).getTime()) ||
      !LocalLearningRepository.isNonNegativeInteger(snapshot.totalQuestions) ||
      !LocalLearningRepository.isNonNegativeInteger(snapshot.correctQuestions) ||
      snapshot.correctQuestions > snapshot.totalQuestions || !Array.isArray(snapshot.resultIds) ||
      snapshot.resultIds.length > 20 || !Array.isArray(snapshot.topicMastery)) return false;
    const resultIds: string[] = [];
    for (const resultId of snapshot.resultIds) {
      if (typeof resultId !== 'string' || resultId.trim().length === 0 || resultIds.includes(resultId)) return false;
      resultIds.push(resultId);
    }
    const topicKeys: string[] = [];
    for (const item of snapshot.topicMastery) {
      if (item === null || typeof item !== 'object' || typeof item.courseId !== 'string' ||
        typeof item.topic !== 'string' || !LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) ||
        !LocalLearningRepository.isNonNegativeInteger(item.attempts) ||
        !LocalLearningRepository.isNonNegativeInteger(item.totalQuestions) ||
        !LocalLearningRepository.isNonNegativeInteger(item.correctQuestions) ||
        item.correctQuestions > item.totalQuestions ||
        (item.lastPracticedAt !== undefined && Number.isNaN(new Date(item.lastPracticedAt).getTime()))) return false;
      const topicKey = JSON.stringify([item.courseId, item.topic]);
      if (topicKeys.includes(topicKey)) return false;
      topicKeys.push(topicKey);
    }
    return true;
  }

  private static legacyHistoryPrecedesState(state: QuizLearningState,
    legacy: LegacyQuizHistorySnapshot): boolean {
    let firstSubmittedAt = state.stats.firstSubmittedAt;
    for (const pending of state.pendingResults) {
      if (Number.isNaN(new Date(pending.submittedAt).getTime())) continue;
      if (firstSubmittedAt === undefined ||
        LocalLearningRepository.timestampPrecedes(pending.submittedAt, firstSubmittedAt)) {
        firstSubmittedAt = pending.submittedAt;
      }
    }
    return firstSubmittedAt !== undefined &&
      LocalLearningRepository.timestampPrecedes(legacy.updatedAt, firstSubmittedAt);
  }

  private static extractNewLegacyResultsWithoutSnapshot(state: QuizLearningState,
    currentResults: QuizResult[]): QuizResult[] {
    let firstAppliedIndex = -1;
    for (let index = 0; index < currentResults.length; index += 1) {
      if (state.appliedQuizIds.includes(currentResults[index].quizId)) {
        firstAppliedIndex = index;
        break;
      }
    }
    if (firstAppliedIndex < 0) {
      if (currentResults.length === 20) {
        throw new Error('旧测验结果窗口无法证明完整，无法安全迁移');
      }
      return currentResults.slice();
    }
    for (let index = firstAppliedIndex; index < currentResults.length; index += 1) {
      if (!state.appliedQuizIds.includes(currentResults[index].quizId)) {
        throw new Error('旧测验结果窗口顺序冲突，无法安全迁移');
      }
    }
    return currentResults.slice(0, firstAppliedIndex);
  }

  private static extractNewLegacyResults(state: QuizLearningState, previousResultIds: string[],
    currentResults: QuizResult[]): QuizResult[] {
    const currentResultIds = currentResults.map((result: QuizResult): string => result.quizId);
    if (previousResultIds.length === 0) {
      if (currentResultIds.length === 20) {
        throw new Error('旧测验结果窗口无法证明完整，无法安全迁移');
      }
      for (const resultId of currentResultIds) {
        if (state.appliedQuizIds.includes(resultId)) {
          throw new Error('旧测验结果窗口与已应用记录冲突，无法安全迁移');
        }
      }
      return currentResults.slice();
    }
    let overlapIndex = -1;
    for (let index = 0; index < currentResultIds.length; index += 1) {
      if (previousResultIds.includes(currentResultIds[index])) {
        overlapIndex = index;
        break;
      }
    }
    if (overlapIndex < 0) {
      throw new Error('旧测验结果窗口无法证明完整，无法安全迁移');
    }
    const overlapLength = currentResultIds.length - overlapIndex;
    if (overlapLength > previousResultIds.length ||
      (currentResultIds.length < 20 && overlapLength !== previousResultIds.length)) {
      throw new Error('旧测验结果窗口顺序冲突，无法安全迁移');
    }
    for (let index = 0; index < overlapLength; index += 1) {
      if (currentResultIds[overlapIndex + index] !== previousResultIds[index]) {
        throw new Error('旧测验结果窗口顺序冲突，无法安全迁移');
      }
    }
    const newResults = currentResults.slice(0, overlapIndex);
    for (const result of newResults) {
      if (state.appliedQuizIds.includes(result.quizId)) {
        throw new Error('旧测验结果窗口与已应用记录冲突，无法安全迁移');
      }
    }
    return newResults;
  }

  private static validateLegacyHistoryProgress(state: QuizLearningState,
    previous: LegacyQuizHistorySnapshot, current: LegacyQuizHistorySnapshot,
    newResults: QuizResult[]): void {
    if (current.totalQuestions < previous.totalQuestions || current.correctQuestions < previous.correctQuestions) {
      throw new Error('旧测验累计统计发生回退，无法安全迁移');
    }
    const totalQuestionsDelta = current.totalQuestions - previous.totalQuestions;
    const correctQuestionsDelta = current.correctQuestions - previous.correctQuestions;
    if (correctQuestionsDelta > totalQuestionsDelta) {
      throw new Error('旧测验累计统计增量不一致，无法安全迁移');
    }
    let resultQuestionTotal = 0;
    let resultCorrectTotal = 0;
    for (const result of newResults) {
      resultQuestionTotal += result.totalQuestions;
      resultCorrectTotal += result.correctCount;
    }
    if (totalQuestionsDelta > resultQuestionTotal || correctQuestionsDelta > resultCorrectTotal) {
      throw new Error('旧测验累计统计与结果窗口不一致，无法安全迁移');
    }
    for (const previousTopic of previous.topicMastery) {
      const currentTopic = current.topicMastery.find((item: LegacyQuizTopicHistorySnapshot): boolean =>
        item.courseId === previousTopic.courseId && item.topic === previousTopic.topic);
      if (currentTopic === undefined || currentTopic.attempts < previousTopic.attempts ||
        currentTopic.totalQuestions < previousTopic.totalQuestions ||
        currentTopic.correctQuestions < previousTopic.correctQuestions) {
        throw new Error('旧测验 Topic 累计发生回退，无法安全迁移');
      }
      const target = state.topicMastery.find((item: TopicMastery): boolean =>
        item.courseId === previousTopic.courseId && item.topic === previousTopic.topic);
      if (target === undefined) throw new Error('旧测验 Topic 迁移基线缺失，无法安全迁移');
    }

    for (const source of current.topicMastery) {
      const baseline = previous.topicMastery.find((item: LegacyQuizTopicHistorySnapshot): boolean =>
        item.courseId === source.courseId && item.topic === source.topic);
      const attemptsDelta = source.attempts - (baseline?.attempts ?? 0);
      const topicQuestionsDelta = source.totalQuestions - (baseline?.totalQuestions ?? 0);
      const topicCorrectDelta = source.correctQuestions - (baseline?.correctQuestions ?? 0);
      if (attemptsDelta < 0 || topicQuestionsDelta < 0 || topicCorrectDelta < 0 ||
        topicCorrectDelta > topicQuestionsDelta) {
        throw new Error('旧测验 Topic 累计增量不一致，无法安全迁移');
      }
      let resultAttempts = 0;
      let resultQuestions = 0;
      let resultCorrect = 0;
      for (const result of newResults) {
        if (result.courseId !== source.courseId || result.topic !== source.topic) continue;
        resultAttempts += 1;
        resultQuestions += result.totalQuestions;
        resultCorrect += result.correctCount;
      }
      if (attemptsDelta > resultAttempts || topicQuestionsDelta > resultQuestions ||
        topicCorrectDelta > resultCorrect) {
        throw new Error('旧测验 Topic 累计与结果窗口不一致，无法安全迁移');
      }
    }
  }

  private static recoverLegacyResults(state: QuizLearningState, newResults: QuizResult[],
    pendingResults: QuizResult[]): void {
    const orderedResults = newResults.map((result: QuizResult, index: number): [QuizResult, number] =>
      [result, index]).sort((left: [QuizResult, number], right: [QuizResult, number]): number => {
      const timestampOrder = new Date(left[0].submittedAt).getTime() - new Date(right[0].submittedAt).getTime();
      return timestampOrder !== 0 ? timestampOrder : right[1] - left[1];
    });
    for (const entry of orderedResults) {
      const result = entry[0];
      const pending = pendingResults.find((item: QuizResult): boolean => item.quizId === result.quizId);
      if (pending !== undefined) {
        if (!LocalLearningRepository.quizResultsEquivalent(pending, result)) {
          throw new Error('旧测验结果窗口与 pending 内容冲突，无法安全迁移');
        }
        if (!state.appliedQuizIds.includes(result.quizId)) {
          throw new Error('旧测验 pending 结果未完成归并，无法安全迁移');
        }
        continue;
      }
      if (state.appliedQuizIds.includes(result.quizId)) {
        throw new Error('旧测验结果窗口与已应用记录冲突，无法安全迁移');
      }
      QuizLearningStateReducer.applyMigratedResult(state, result, false, false);
    }
  }

  private static quizResultsEquivalent(left: QuizResult, right: QuizResult): boolean {
    return JSON.stringify(left) === JSON.stringify(right);
  }

  private static isQuizEventForResult(event: StudyEvent, result: QuizResult): boolean {
    if (event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted') return false;
    const eventTime = new Date(event.timestamp).getTime();
    const resultTime = new Date(result.submittedAt).getTime();
    return !Number.isNaN(eventTime) && eventTime === resultTime && event.courseId === result.courseId &&
      event.topic === result.topic && event.source === result.source && event.difficulty === result.difficulty &&
      event.totalQuestions === result.totalQuestions && event.correctCount === result.correctCount;
  }

  private static legacyResultInclusion(snapshot: LegacyQuizHistorySnapshot | null, result: QuizResult,
    resultIndex: number, resultsRow: StoredValue<QuizResult[]> | null,
    statsRow: StoredValue<LegacyQuizStatsAggregate> | null,
    masteryRow: StoredValue<TopicMastery[]> | null): LegacyResultInclusion {
    const notIncluded: LegacyResultInclusion = {
      statsAlreadyIncluded: false,
      topicAlreadyIncluded: false
    };
    if (snapshot === null) return notIncluded;
    if (resultsRow === null || !LocalLearningRepository.isStoredUpdateTime(resultsRow.updatedAt)) {
      throw new Error('旧测验结果写入阶段无效，无法安全迁移');
    }
    if (statsRow === null || !LocalLearningRepository.isStoredUpdateTime(statsRow.updatedAt) ||
      (masteryRow !== null && !LocalLearningRepository.isStoredUpdateTime(masteryRow.updatedAt))) {
      throw new Error('旧测验累计写入阶段无效，无法安全迁移');
    }

    const statsMarkerIndexes: number[] = [];
    for (let index = 0; index < resultsRow.value.length; index += 1) {
      if (resultsRow.value[index].submittedAt === statsRow.value.updatedAt) statsMarkerIndexes.push(index);
    }
    if (statsMarkerIndexes.length > 1) {
      throw new Error('旧测验同一提交时间的写入阶段无法区分，无法安全迁移');
    }
    const statsMarkerIndex = statsMarkerIndexes.length === 1 ? statsMarkerIndexes[0] : -1;
    if (statsMarkerIndex < 0) {
      if (statsRow.updatedAt >= resultsRow.updatedAt) {
        throw new Error('旧测验累计写入阶段与最新结果不一致，无法安全迁移');
      }
    } else if ((statsMarkerIndex === 0 && statsRow.updatedAt <= resultsRow.updatedAt) ||
      (statsMarkerIndex > 0 && statsRow.updatedAt >= resultsRow.updatedAt)) {
      throw new Error('旧测验累计写入阶段无法区分，无法安全迁移');
    }
    if (statsMarkerIndex >= 0 && statsMarkerIndex < resultsRow.value.length - 1) {
      throw new Error('旧测验累计结果前缀无法证明，无法安全迁移');
    }

    let latestTopicMarkerIndex = -1;
    for (const snapshotTopic of snapshot.topicMastery) {
      if (snapshotTopic.lastPracticedAt === undefined) continue;
      const markerIndexes: number[] = [];
      for (let index = 0; index < resultsRow.value.length; index += 1) {
        const item = resultsRow.value[index];
        if (item.courseId === snapshotTopic.courseId && item.topic === snapshotTopic.topic &&
          item.submittedAt === snapshotTopic.lastPracticedAt) markerIndexes.push(index);
      }
      if (markerIndexes.length > 1) {
        throw new Error('旧测验同一提交时间的写入阶段无法区分，无法安全迁移');
      }
      if (markerIndexes.length === 1 &&
        (latestTopicMarkerIndex < 0 || markerIndexes[0] < latestTopicMarkerIndex)) {
        latestTopicMarkerIndex = markerIndexes[0];
      }
    }
    if (masteryRow !== null) {
      if (latestTopicMarkerIndex < 0) {
        if (masteryRow.updatedAt >= resultsRow.updatedAt) {
          throw new Error('旧测验 Topic 写入阶段与最新结果不一致，无法安全迁移');
        }
      } else if ((latestTopicMarkerIndex === 0 && masteryRow.updatedAt <= resultsRow.updatedAt) ||
        (latestTopicMarkerIndex > 0 && masteryRow.updatedAt >= resultsRow.updatedAt)) {
        throw new Error('旧测验 Topic 写入阶段无法区分，无法安全迁移');
      }
    }

    const topic = snapshot.topicMastery.find((item: LegacyQuizTopicHistorySnapshot): boolean =>
      item.courseId === result.courseId && item.topic === result.topic);
    let topicMarkerIndex = -1;
    if (topic !== undefined && topic.lastPracticedAt !== undefined) {
      for (let index = 0; index < resultsRow.value.length; index += 1) {
        const item = resultsRow.value[index];
        if (item.courseId === result.courseId && item.topic === result.topic &&
          item.submittedAt === topic.lastPracticedAt) topicMarkerIndex = index;
      }
    }
    if (topicMarkerIndex >= 0) {
      for (let index = topicMarkerIndex + 1; index < resultsRow.value.length; index += 1) {
        const item = resultsRow.value[index];
        if (item.courseId === result.courseId && item.topic === result.topic) {
          throw new Error('旧测验 Topic 结果前缀无法证明，无法安全迁移');
        }
      }
    }

    const statsIncluded = statsMarkerIndex === resultIndex;
    const topicIncluded = masteryRow !== null && topicMarkerIndex === resultIndex;
    if (topicIncluded && !statsIncluded) {
      throw new Error('旧测验累计写入顺序无效，无法安全迁移');
    }
    return {
      statsAlreadyIncluded: statsIncluded,
      topicAlreadyIncluded: topicIncluded
    };
  }

  private static isStoredUpdateTime(value: number): boolean {
    return Number.isFinite(value) && value >= 0 && Math.floor(value) === value;
  }

  private static seedLegacyAggregateBaseline(state: QuizLearningState,
    snapshot: LegacyQuizHistorySnapshot | null, mastery: TopicMastery[] | null,
    stats: LegacyQuizStatsAggregate | null, entries: LegacyReplayEntry[]): void {
    if (snapshot === null || stats === null) return;
    const residualMastery: TopicMastery[] = (mastery ?? []).map((item: TopicMastery): TopicMastery => {
      return {
        courseId: item.courseId,
        topic: item.topic,
        attempts: item.attempts,
        totalQuestions: item.totalQuestions,
        correctQuestions: item.correctQuestions,
        accuracy: item.accuracy,
        mastered: item.mastered,
        lastPracticedAt: item.lastPracticedAt
      };
    });
    let residualQuestions = snapshot.totalQuestions;
    let residualCorrect = snapshot.correctQuestions;
    for (const entry of entries) {
      if (entry.inclusion.statsAlreadyIncluded) {
        residualQuestions -= entry.result.totalQuestions;
        residualCorrect -= entry.result.correctCount;
      }
      if (!entry.inclusion.topicAlreadyIncluded) continue;
      const target = residualMastery.find((item: TopicMastery): boolean =>
        item.courseId === entry.result.courseId && item.topic === entry.result.topic);
      if (target === undefined) throw new Error('旧测验 Topic 累计缺少历史结果，无法安全迁移');
      target.attempts -= 1;
      target.totalQuestions -= entry.result.totalQuestions;
      target.correctQuestions -= entry.result.correctCount;
      if (target.lastPracticedAt === entry.result.submittedAt) target.lastPracticedAt = undefined;
    }
    if (residualQuestions < 0 || residualCorrect < 0 || residualCorrect > residualQuestions) {
      throw new Error('旧测验累计无法扣除结果窗口，无法安全迁移');
    }
    for (const item of residualMastery) {
      if (item.attempts < 0 || item.totalQuestions < 0 || item.correctQuestions < 0 ||
        item.correctQuestions > item.totalQuestions) {
        throw new Error('旧测验 Topic 累计无法扣除结果窗口，无法安全迁移');
      }
      item.accuracy = item.totalQuestions > 0 ? item.correctQuestions / item.totalQuestions : 0;
      item.mastered = QuizLearningStateReducer.isTopicMastered(item.correctQuestions, item.totalQuestions);
    }
    const masteryStats = QuizLearningStateReducer.masteryTotals(residualMastery);
    state.topicMastery = residualMastery;
    state.stats.totalAttempts = masteryStats.totalAttempts;
    state.stats.totalQuestions = residualQuestions;
    state.stats.correctQuestions = residualCorrect;
    state.stats.quizDates = stats.studyDates.slice();
    state.stats.firstSubmittedAt = masteryStats.firstSubmittedAt;
    state.legacyHistorySnapshot = snapshot;
  }

  private static unmatchedLegacyEvents(state: QuizLearningState, legacyEvents: StudyEvent[],
    results: QuizResult[]): StudyEvent[] {
    const seenQuizEvents: StudyEvent[] = [];
    const duplicateIndexes: number[] = [];
    for (let index = 0; index < legacyEvents.length; index += 1) {
      const event = legacyEvents[index];
      if (event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted') continue;
      const duplicate = seenQuizEvents.find((item: StudyEvent): boolean => item.id === event.id);
      if (duplicate !== undefined && !LocalLearningRepository.sameStudyEvent(duplicate, event)) {
        throw new Error('旧测验事件 ID 与已保存内容冲突，无法安全迁移');
      }
      if (duplicate === undefined) seenQuizEvents.push(event);
      else duplicateIndexes.push(index);
      const stateEvent = state.quizEvents.find((item: StudyEvent): boolean => item.id === event.id);
      if (stateEvent !== undefined && !LocalLearningRepository.sameStudyEvent(stateEvent, event)) {
        throw new Error('旧测验事件 ID 与统一状态内容冲突，无法安全迁移');
      }
    }

    const consumedIndexes: number[] = [];
    for (const result of results) {
      const canonical = state.quizEvents.find((event: StudyEvent): boolean => event.id === 'quiz_' + result.quizId);
      if (canonical === undefined) continue;
      if (!LocalLearningRepository.isQuizEventForResult(canonical, result)) {
        throw new Error('旧测验结果与统一事件内容冲突，无法安全迁移');
      }
      const matchIndex = legacyEvents.findIndex((event: StudyEvent, index: number): boolean =>
        !consumedIndexes.includes(index) && LocalLearningRepository.isQuizEventForResult(event, result));
      if (matchIndex >= 0) consumedIndexes.push(matchIndex);
    }
    return legacyEvents.filter((_event: StudyEvent, index: number): boolean =>
      !duplicateIndexes.includes(index) && !consumedIndexes.includes(index));
  }

  private static mergeLegacyQuizStats(state: QuizLearningState, legacy: LegacyQuizStatsAggregate | null,
    appendLegacyHistory: boolean): void {
    if (legacy === null || !LocalLearningRepository.isValidLegacyQuizStats(legacy)) return;
    const legacyCorrectQuestions = Math.round(legacy.totalQuestions * legacy.accuracy);
    if (appendLegacyHistory) {
      state.stats.totalQuestions += legacy.totalQuestions;
      state.stats.correctQuestions += legacyCorrectQuestions;
    } else if (legacy.totalQuestions >= state.stats.totalQuestions) {
      state.stats.totalQuestions = legacy.totalQuestions;
      state.stats.correctQuestions = legacyCorrectQuestions;
    }
    for (const date of legacy.studyDates) {
      if (date.length > 0 && !state.stats.quizDates.includes(date)) state.stats.quizDates.push(date);
    }
  }

  private static mergeLegacyTopicMastery(state: QuizLearningState, legacy: TopicMastery[] | null,
    appendLegacyHistory: boolean): void {
    if (legacy === null) return;
    const validLegacy = legacy.filter((item: TopicMastery): boolean =>
      LocalLearningRepository.isValidLegacyTopicMastery(item));
    let addedAttempts = 0;
    for (const source of validLegacy) {
      if (appendLegacyHistory && source.lastPracticedAt !== undefined) {
        LocalLearningRepository.mergeFirstSubmittedAt(state, source.lastPracticedAt);
      }
      const index = state.topicMastery.findIndex((item: TopicMastery): boolean =>
        item.courseId === source.courseId && item.topic === source.topic);
      if (index < 0) {
        state.topicMastery.push(source);
        addedAttempts += source.attempts;
        continue;
      }
      const target = state.topicMastery[index];
      if (appendLegacyHistory) {
        target.attempts += source.attempts;
        target.totalQuestions += source.totalQuestions;
        target.correctQuestions += source.correctQuestions;
        target.accuracy = target.totalQuestions > 0 ? target.correctQuestions / target.totalQuestions : 0;
        target.mastered = QuizLearningStateReducer.isTopicMastered(
          target.correctQuestions, target.totalQuestions);
        if (target.lastPracticedAt === undefined ||
          (source.lastPracticedAt !== undefined &&
            LocalLearningRepository.timestampPrecedes(target.lastPracticedAt, source.lastPracticedAt))) {
          target.lastPracticedAt = source.lastPracticedAt;
        }
        addedAttempts += source.attempts;
      } else if (source.totalQuestions >= target.totalQuestions) {
        state.topicMastery[index] = source;
      }
    }
    if (appendLegacyHistory) {
      state.stats.totalAttempts += addedAttempts;
    } else {
      const legacyTotals = QuizLearningStateReducer.masteryTotals(validLegacy);
      if (legacyTotals.totalQuestions >= QuizLearningStateReducer.masteryTotals(state.topicMastery).totalQuestions) {
        state.stats.totalAttempts = Math.max(state.stats.totalAttempts, legacyTotals.totalAttempts);
      }
    }
  }

  private static mergeLegacyRecentResults(state: QuizLearningState, legacy: QuizResult[]): void {
    for (const result of legacy) {
      if (!LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic)) continue;
      LocalLearningRepository.mergeFirstSubmittedAt(state, result.submittedAt);
      if (!state.appliedQuizIds.includes(result.quizId)) state.appliedQuizIds.push(result.quizId);
      if (!state.recentResults.some((item: QuizResult): boolean => item.quizId === result.quizId)) {
        state.recentResults.push(result);
      }
    }
    state.recentResults.sort((left: QuizResult, right: QuizResult): number =>
      new Date(right.submittedAt).getTime() - new Date(left.submittedAt).getTime());
    state.recentResults = state.recentResults.slice(0, 20);
  }

  private static mergeLegacyReviewItems(state: QuizLearningState, legacy: ReviewItem[] | null): void {
    if (legacy === null) return;
    for (const item of legacy) {
      if (!LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic)) continue;
      const existing = state.reviewItems.find((current: ReviewItem): boolean =>
        current.id === item.id || (current.courseId === item.courseId && current.topic === item.topic &&
          current.questionId === item.questionId && current.stem === item.stem));
      if (existing === undefined) {
        state.reviewItems.push(item);
      } else if ((existing.options ?? []).length === 0 && (item.options ?? []).length > 0) {
        existing.options = item.options;
        existing.quizId = item.quizId;
      }
    }
  }

  private static mergeLegacyQuizEvents(state: QuizLearningState, legacy: StudyEvent[]): void {
    QuizLearningStateReducer.mergeQuizEvents(state, legacy.filter((event: StudyEvent): boolean =>
      event.type === 'quiz_mastered' || event.type === 'quiz_submitted'));
    for (const event of state.quizEvents) {
      LocalLearningRepository.mergeFirstSubmittedAt(state, event.timestamp);
    }
  }

  private static async ensureDefaults(): Promise<void> {
    if ((await LocalLearningRepository.getProfile()) === null) {
      const profile: UserProfile = {
        userId: 'demo',
        name: '演示同学',
        stage: '本科二年级',
        weakTopics: [],
        strongTopics: [],
        learningStyle: '视觉型',
        stats: { totalQuestions: 0, accuracy: 0, studyDays: 0, streakDays: 0 }
      };
      await LocalLearningRepository.saveProfile(profile);
    }
    if ((await LocalLearningRepository.getCourses()) === null) {
      const courses: Course[] = [
        { id: 'cs101', title: '数据结构', progress: 0, docCount: 52, topics: ['二叉树', '图的遍历', '动态规划'] },
        { id: 'cs102', title: '操作系统', progress: 0, docCount: 48, topics: ['进程调度', '内存管理', '文件系统'] },
        { id: 'cs103', title: '计算机网络', progress: 0, docCount: 47, topics: ['TCP/IP', 'HTTP', '路由协议'] }
      ];
      await LocalLearningRepository.saveCourses(courses);
    }
  }

  private static requireStore(): relationalStore.RdbStore {
    if (LocalLearningRepository.store === null) {
      throw new Error('LocalLearningRepository 尚未初始化');
    }
    return LocalLearningRepository.store;
  }

  private static runQuizStateTask<T>(task: () => Promise<T>): Promise<T> {
    const running: Promise<T> = LocalLearningRepository.quizStateQueue.then((): Promise<T> => task());
    LocalLearningRepository.quizStateQueue = running.then((): void => {}, (): void => {});
    return running;
  }

  private static runLessonProgressTask<T>(task: () => Promise<T>): Promise<T> {
    const running: Promise<T> = LocalLearningRepository.lessonProgressQueue.then((): Promise<T> => task());
    LocalLearningRepository.lessonProgressQueue = running.then((): void => {}, (): void => {});
    return running;
  }

  private static runPlanTask<T>(task: () => Promise<T>): Promise<T> {
    const running: Promise<T> = LocalLearningRepository.planQueue.then((): Promise<T> => task());
    LocalLearningRepository.planQueue = running.then((): void => {}, (): void => {});
    return running;
  }

  private static isExactCourseTopic(courseId: string, topic: string): boolean {
    return LearningContentRepository.getTopics(courseId).includes(topic);
  }

  private static isValidCompletedLessonProgress(item: LessonProgress): boolean {
    return item.completedAt !== undefined && !Number.isNaN(new Date(item.completedAt).getTime()) &&
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic);
  }

  private static isValidStoredStudyEvent(event: StudyEvent): boolean {
    if (event === null || typeof event !== 'object' || typeof event.id !== 'string' ||
      event.id.trim().length === 0 || typeof event.type !== 'string' || event.type.trim().length === 0 ||
      typeof event.timestamp !== 'string' || Number.isNaN(new Date(event.timestamp).getTime()) ||
      (event.source !== undefined && typeof event.source !== 'string') ||
      (event.difficulty !== undefined && !LocalLearningRepository.isQuizDifficulty(event.difficulty)) ||
      !LocalLearningRepository.isStringArray(event.tags) ||
      (event.totalQuestions !== undefined &&
        !LocalLearningRepository.isNonNegativeInteger(event.totalQuestions)) ||
      (event.correctCount !== undefined &&
        !LocalLearningRepository.isNonNegativeInteger(event.correctCount)) ||
      (event.totalQuestions !== undefined && event.correctCount !== undefined &&
        event.correctCount > event.totalQuestions)) return false;
    if (event.courseId === undefined && event.topic === undefined) return true;
    if (typeof event.courseId !== 'string' || typeof event.topic !== 'string') return false;
    return LocalLearningRepository.isExactCourseTopic(event.courseId, event.topic);
  }

  private static prepareQuizLearningStateContainers(state: QuizLearningState): boolean {
    let changed = false;
    if (!Array.isArray(state.pendingResults)) {
      state.pendingResults = [];
      changed = true;
    }
    if (!Array.isArray(state.appliedQuizIds)) {
      state.appliedQuizIds = [];
      changed = true;
    }
    if (!Array.isArray(state.appliedInsightEventIds)) {
      state.appliedInsightEventIds = [];
      changed = true;
    }
    if (!Array.isArray(state.recentResults)) {
      state.recentResults = [];
      changed = true;
    }
    if (!Array.isArray(state.reviewItems)) {
      state.reviewItems = [];
      changed = true;
    }
    if (!Array.isArray(state.topicMastery)) {
      state.topicMastery = [];
      changed = true;
    }
    if (!Array.isArray(state.tagInsights)) {
      state.tagInsights = [];
      changed = true;
    }
    if (!Array.isArray(state.quizEvents)) {
      state.quizEvents = [];
      changed = true;
    }
    if (!Array.isArray(state.masteryMilestones)) {
      state.masteryMilestones = [];
      changed = true;
    }
    if (!Array.isArray(state.weakTopics)) {
      state.weakTopics = [];
      changed = true;
    }
    if (!Array.isArray(state.strongTopics)) {
      state.strongTopics = [];
      changed = true;
    }
    if (state.stats === null || typeof state.stats !== 'object' || Array.isArray(state.stats)) {
      state.stats = {
        totalAttempts: 0,
        totalQuestions: 0,
        correctQuestions: 0,
        quizDates: []
      };
      changed = true;
    }
    if (LocalLearningRepository.normalizeStoredIds(state.appliedQuizIds)) changed = true;
    if (LocalLearningRepository.normalizeStoredIds(state.appliedInsightEventIds)) changed = true;
    return changed;
  }

  private static normalizeStoredIds(ids: string[]): boolean {
    const normalized: string[] = [];
    for (const id of ids) {
      if (typeof id === 'string' && id.trim().length > 0 && !normalized.includes(id)) normalized.push(id);
    }
    if (normalized.length === ids.length && normalized.every((id: string, index: number): boolean =>
      id === ids[index])) return false;
    ids.splice(0, ids.length);
    for (const id of normalized) ids.push(id);
    return true;
  }

  private static sanitizeQuizLearningState(state: QuizLearningState): boolean {
    const statsWereValid = LocalLearningRepository.isValidQuizLearningStats(state);
    const previousWeakTopics = state.weakTopics.slice();
    const previousStrongTopics = state.strongTopics.slice();
    const originalItemCount = state.pendingResults.length + state.recentResults.length +
      state.reviewItems.length + state.topicMastery.length + state.tagInsights.length +
      state.quizEvents.length + state.masteryMilestones.length;
    const originalStatsSourceCount = state.recentResults.length + state.topicMastery.length + state.quizEvents.length;
    state.pendingResults = state.pendingResults.filter((result: QuizResult): boolean =>
      LocalLearningRepository.isValidLegacyQuizResult(result));
    state.recentResults = state.recentResults.filter((result: QuizResult): boolean =>
      LocalLearningRepository.isValidLegacyQuizResult(result));
    state.reviewItems = state.reviewItems.filter((item: ReviewItem): boolean =>
      LocalLearningRepository.isValidStoredReviewItem(item));
    state.topicMastery = state.topicMastery.filter((item: TopicMastery): boolean =>
      LocalLearningRepository.isValidStoredTopicMastery(item));
    state.tagInsights = state.tagInsights.filter((item: TagInsight): boolean =>
      LocalLearningRepository.isValidStoredTagInsight(item));
    state.quizEvents = state.quizEvents.filter((event: StudyEvent): boolean =>
      LocalLearningRepository.isValidStoredStudyEvent(event));
    state.masteryMilestones = state.masteryMilestones.filter((item: TopicMasteryMilestone): boolean =>
      LocalLearningRepository.isValidStoredMasteryMilestone(item));

    const retainedItemCount = state.pendingResults.length + state.recentResults.length +
      state.reviewItems.length + state.topicMastery.length + state.tagInsights.length +
      state.quizEvents.length + state.masteryMilestones.length;
    const retainedStatsSourceCount = state.recentResults.length + state.topicMastery.length + state.quizEvents.length;
    if (!statsWereValid || retainedStatsSourceCount !== originalStatsSourceCount) {
      const totals = QuizLearningStateReducer.masteryTotals(state.topicMastery);
      state.stats.totalAttempts = totals.totalAttempts;
      state.stats.totalQuestions = totals.totalQuestions;
      state.stats.correctQuestions = totals.correctQuestions;
      state.stats.quizDates = totals.quizDates;
      state.stats.firstSubmittedAt = totals.firstSubmittedAt;
      for (const event of state.quizEvents) {
        const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
        if (!state.stats.quizDates.includes(date)) state.stats.quizDates.push(date);
        LocalLearningRepository.mergeFirstSubmittedAt(state, event.timestamp);
      }
    }
    QuizLearningStateReducer.refreshProfileTopics(state);
    return retainedItemCount !== originalItemCount || !statsWereValid ||
      !LocalLearningRepository.sameStringArray(previousWeakTopics, state.weakTopics) ||
      !LocalLearningRepository.sameStringArray(previousStrongTopics, state.strongTopics);
  }

  private static isValidQuizLearningStats(state: QuizLearningState): boolean {
    const stats = state.stats;
    return stats !== null && typeof stats === 'object' &&
      LocalLearningRepository.isNonNegativeInteger(stats.totalAttempts) &&
      LocalLearningRepository.isNonNegativeInteger(stats.totalQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(stats.correctQuestions) &&
      stats.correctQuestions <= stats.totalQuestions && LocalLearningRepository.isStringArray(stats.quizDates) &&
      (stats.firstSubmittedAt === undefined ||
        (typeof stats.firstSubmittedAt === 'string' && !Number.isNaN(new Date(stats.firstSubmittedAt).getTime())));
  }

  private static isValidStoredTopicMastery(item: TopicMastery): boolean {
    return item !== null && typeof item === 'object' && typeof item.courseId === 'string' &&
      typeof item.topic === 'string' && LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) &&
      LocalLearningRepository.isValidLegacyTopicMastery(item);
  }

  private static isValidStoredReviewItem(item: ReviewItem): boolean {
    return item !== null && typeof item === 'object' && typeof item.id === 'string' &&
      typeof item.questionId === 'string' && typeof item.courseId === 'string' && typeof item.topic === 'string' &&
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) && typeof item.source === 'string' &&
      typeof item.stem === 'string' && typeof item.userAnswer === 'string' &&
      typeof item.correctAnswer === 'string' && typeof item.explanation === 'string' &&
      LocalLearningRepository.isNonNegativeInteger(item.attempts) && typeof item.resolved === 'boolean' &&
      LocalLearningRepository.isNonNegativeInteger(item.intervalDays) && typeof item.nextReviewAt === 'string' &&
      !Number.isNaN(new Date(item.nextReviewAt).getTime()) && typeof item.updatedAt === 'string' &&
      !Number.isNaN(new Date(item.updatedAt).getTime()) && LocalLearningRepository.isStringArray(item.options) &&
      LocalLearningRepository.isStringArray(item.tags) &&
      (item.quizId === undefined || typeof item.quizId === 'string') &&
      (item.difficulty === undefined || LocalLearningRepository.isQuizDifficulty(item.difficulty));
  }

  private static isValidStoredTagInsight(item: TagInsight): boolean {
    return item !== null && typeof item === 'object' && typeof item.tag === 'string' &&
      typeof item.courseId === 'string' && typeof item.topic === 'string' &&
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) &&
      LocalLearningRepository.isNonNegativeInteger(item.totalQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(item.correctQuestions) &&
      item.correctQuestions <= item.totalQuestions && LocalLearningRepository.isNonNegativeInteger(item.wrongQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(item.easyQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(item.mediumQuestions) &&
      LocalLearningRepository.isNonNegativeInteger(item.hardQuestions) && typeof item.lastPracticedAt === 'string' &&
      !Number.isNaN(new Date(item.lastPracticedAt).getTime()) &&
      LocalLearningRepository.isQuizDifficulty(item.lastDifficulty) && typeof item.masteryLevel === 'string' &&
      Number.isFinite(item.masteryPoints) && typeof item.weakReason === 'string' && typeof item.nextStep === 'string';
  }

  private static isValidStoredMasteryMilestone(item: TopicMasteryMilestone): boolean {
    return item !== null && typeof item === 'object' && typeof item.courseId === 'string' &&
      typeof item.topic === 'string' && LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic) &&
      typeof item.masteredAt === 'string' && !Number.isNaN(new Date(item.masteredAt).getTime());
  }

  private static sameStringArray(left: string[], right: string[]): boolean {
    return left.length === right.length && left.every((item: string, index: number): boolean => item === right[index]);
  }

  private static async getStoredValue<T>(key: string): Promise<StoredValue<T> | null> {
    const store = LocalLearningRepository.requireStore();
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await store.querySql(
        'SELECT payload, updated_at FROM ' + TABLE_NAME + ' WHERE state_key = ?',
        [key]
      );
      if (!resultSet.goToFirstRow()) return null;
      const payload = resultSet.getString(0);
      const value: T = JSON.parse(payload);
      return { value: value, updatedAt: resultSet.getLong(1) };
    } catch (error) {
      throw new Error('读取本地学习状态失败: ' + String(error));
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close();
        } catch (_) {
        }
      }
    }
  }

  private static async getValue<T>(key: string): Promise<T | null> {
    const store = LocalLearningRepository.requireStore();
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await store.querySql(
        'SELECT payload FROM ' + TABLE_NAME + ' WHERE state_key = ?',
        [key]
      );
      if (!resultSet.goToFirstRow()) return null;
      const payload = resultSet.getString(0);
      const value: T = JSON.parse(payload);
      return value;
    } catch (error) {
      throw new Error('读取本地学习状态失败: ' + String(error));
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close();
        } catch (_) {
        }
      }
    }
  }

  private static async putValue<T>(key: string, value: T): Promise<void> {
    const store = LocalLearningRepository.requireStore();
    try {
      await store.executeSql(
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (state_key, payload, updated_at) VALUES (?, ?, ?)',
        [key, JSON.stringify(value), Date.now()]
      );
    } catch (error) {
      throw new Error('保存本地学习状态失败: ' + String(error));
    }
  }

  private static async loadQuizLearningStateUnlocked(): Promise<QuizLearningState> {
    const storedState = await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE);
    const hasStoredStateObject = storedState !== null && typeof storedState === 'object' &&
      !Array.isArray(storedState);
    const state = hasStoredStateObject ? storedState! : QuizLearningStateReducer.createEmptyState();
    let changed = storedState !== null && !hasStoredStateObject;
    if (LocalLearningRepository.prepareQuizLearningStateContainers(state)) changed = true;
    if (LocalLearningRepository.sanitizeQuizLearningState(state)) changed = true;
    if (QuizLearningStateReducer.preparePersistentState(state)) changed = true;
    const storedEventValue = await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS);
    const storedEvents = Array.isArray(storedEventValue) ? storedEventValue : [];
    for (const event of storedEvents) {
      if (LocalLearningRepository.isValidStoredStudyEvent(event) &&
        QuizLearningStateReducer.applyLearningInsightEvent(state, event)) changed = true;
    }
    if (changed) {
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
    }
    return state;
  }

  private static async getQuizLearningState(): Promise<QuizLearningState> {
    return LocalLearningRepository.runQuizStateTask(async (): Promise<QuizLearningState> => {
      const state = await LocalLearningRepository.loadQuizLearningStateUnlocked();
      if (state.pendingResults.length > 0) {
        QuizLearningStateReducer.applyPendingResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      return state;
    });
  }

  static async getProfile(): Promise<UserProfile | null> {
    const profile = await LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
    if (profile === null) return null;
    const state = await LocalLearningRepository.getQuizLearningState();
    const studyDates: string[] = state.stats.quizDates.slice();
    const events = await LocalLearningRepository.getStudyEvents();
    for (const event of events) {
      const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
      if (!studyDates.includes(date)) studyDates.push(date);
    }
    const lessonProgress = await LocalLearningRepository.loadLessonProgressUnlocked();
    for (const item of lessonProgress) {
      const completedAt = item.completedAt;
      if (completedAt === undefined || !LocalLearningRepository.isValidCompletedLessonProgress(item)) continue;
      const date = LocalLearningRepository.localDateKey(new Date(completedAt));
      if (!studyDates.includes(date)) studyDates.push(date);
    }
    profile.weakTopics = state.weakTopics.slice();
    profile.strongTopics = state.strongTopics.slice();
    profile.stats = {
      totalQuestions: state.stats.totalQuestions,
      accuracy: state.stats.totalQuestions > 0 ? state.stats.correctQuestions / state.stats.totalQuestions : 0,
      studyDays: studyDates.length,
      streakDays: LocalLearningRepository.calculateStreakDays(studyDates)
    };
    return profile;
  }

  static async saveProfile(profile: UserProfile): Promise<void> {
    await LocalLearningRepository.putValue<UserProfile>(KEY_PROFILE, profile);
  }

  static async getCourses(): Promise<Course[] | null> {
    const courses = await LocalLearningRepository.getValue<Course[]>(KEY_COURSES);
    if (courses === null) return null;
    const events = await LocalLearningRepository.getStudyEvents();
    const lessonProgress = await LocalLearningRepository.loadLessonProgressUnlocked();
    const state = await LocalLearningRepository.getQuizLearningState();
    return courses.map((course: Course): Course => {
      const completedTopics: string[] = [];
      for (const item of lessonProgress) {
        if (item.courseId !== course.id || !LocalLearningRepository.isValidCompletedLessonProgress(item) ||
          !course.topics.includes(item.topic) || completedTopics.includes(item.topic)) continue;
        completedTopics.push(item.topic);
      }
      for (const event of events) {
        if (event.courseId !== course.id || event.topic === undefined || !course.topics.includes(event.topic)) continue;
        if (event.type !== 'lesson_completed') continue;
        if (!completedTopics.includes(event.topic)) completedTopics.push(event.topic);
      }
      for (const item of state.masteryMilestones) {
        if (item.courseId !== course.id || !course.topics.includes(item.topic)) continue;
        if (!completedTopics.includes(item.topic)) completedTopics.push(item.topic);
      }
      return {
        id: course.id,
        title: course.title,
        progress: Math.min(completedTopics.length / Math.max(course.topics.length, 1), 1),
        docCount: course.docCount,
        topics: course.topics
      };
    });
  }

  static async syncCourseCatalog(catalog: Course[]): Promise<void> {
    const stored = await LocalLearningRepository.getValue<Course[]>(KEY_COURSES) ?? [];
    const merged: Course[] = catalog.map((item: Course): Course => {
      const previous = stored.find((course: Course): boolean => course.id === item.id);
      return {
        id: item.id,
        title: item.title,
        progress: previous?.progress ?? 0,
        docCount: item.docCount,
        topics: item.topics
      };
    });
    await LocalLearningRepository.putValue<Course[]>(KEY_COURSES, merged);
  }

  static async saveCourses(courses: Course[]): Promise<void> {
    await LocalLearningRepository.putValue<Course[]>(KEY_COURSES, courses);
  }

  static async getPlan(): Promise<StudyPlan | null> {
    return LocalLearningRepository.runPlanTask((): Promise<StudyPlan | null> =>
      LocalLearningRepository.getValue<StudyPlan>(KEY_PLAN));
  }

  static async savePlan(plan: StudyPlan): Promise<void> {
    return LocalLearningRepository.runPlanTask((): Promise<void> =>
      LocalLearningRepository.putValue<StudyPlan>(KEY_PLAN, plan));
  }

  static async updatePlanTask(taskId: string, done: boolean): Promise<PlanTaskUpdateReceipt> {
    const normalizedTaskId = taskId.trim();
    if (normalizedTaskId.length === 0) throw new Error('计划任务标识无效');
    return LocalLearningRepository.runPlanTask(async (): Promise<PlanTaskUpdateReceipt> => {
      const plan = await LocalLearningRepository.getValue<StudyPlan>(KEY_PLAN);
      if (plan === null) throw new Error('本地计划不存在');
      const task = plan.tasks.find((item): boolean => item.id === normalizedTaskId);
      if (task === undefined) throw new Error('本地计划任务不存在');
      const changed = Boolean(task.done) !== done;
      task.done = done;
      if (changed) await LocalLearningRepository.putValue<StudyPlan>(KEY_PLAN, plan);
      return { plan: plan, task: task, changed: changed };
    });
  }

  static async getFormIds(): Promise<string[]> {
    return (await LocalLearningRepository.getValue<string[]>(KEY_FORM_IDS)) ?? [];
  }

  static async registerFormId(formId: string): Promise<void> {
    const ids = await LocalLearningRepository.getFormIds();
    if (!ids.includes(formId)) {
      ids.push(formId);
      await LocalLearningRepository.putValue<string[]>(KEY_FORM_IDS, ids);
    }
  }

  static async removeFormId(formId: string): Promise<void> {
    const ids = await LocalLearningRepository.getFormIds();
    await LocalLearningRepository.putValue<string[]>(KEY_FORM_IDS,
      ids.filter((id: string): boolean => id !== formId));
  }

  static async getQuizResults(): Promise<QuizResult[]> {
    const state = await LocalLearningRepository.getQuizLearningState();
    return state.recentResults;
  }

  static async appendQuizResult(result: QuizResult): Promise<QuizWriteReceipt> {
    LocalLearningRepository.validateQuizResult(result);
    return LocalLearningRepository.runQuizStateTask(async (): Promise<QuizWriteReceipt> => {
      const state = await LocalLearningRepository.loadQuizLearningStateUnlocked();
      if (state.pendingResults.length > 0) {
        QuizLearningStateReducer.applyPendingResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      if (state.appliedQuizIds.includes(result.quizId)) {
        const receipt = QuizLearningStateReducer.createReceipt(state, result, false);
        return LocalLearningRepository.withCourseProgress(receipt, state, result.courseId);
      }

      QuizLearningStateReducer.enqueueResult(state, result);
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      const applied = QuizLearningStateReducer.applyPendingResults(state) > 0;
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      const receipt = QuizLearningStateReducer.createReceipt(state, result, applied);
      return LocalLearningRepository.withCourseProgress(receipt, state, result.courseId);
    });
  }

  private static async withCourseProgress(receipt: QuizWriteReceipt, state: QuizLearningState,
    courseId: string): Promise<QuizWriteReceipt> {
    const courses = (await LocalLearningRepository.getValue<Course[]>(KEY_COURSES)) ?? [];
    const course = courses.find((item: Course): boolean => item.id === courseId);
    if (course === undefined) return receipt;
    const storedEvents = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
    const lessonProgress = (await LocalLearningRepository.getValue<LessonProgress[]>(KEY_LESSON_PROGRESS)) ?? [];
    const completedTopics: string[] = [];
    for (const item of lessonProgress) {
      if (item.courseId !== courseId || !LocalLearningRepository.isValidCompletedLessonProgress(item) ||
        !course.topics.includes(item.topic) || completedTopics.includes(item.topic)) continue;
      completedTopics.push(item.topic);
    }
    for (const event of storedEvents) {
      if (event.type !== 'lesson_completed' || event.courseId !== courseId || event.topic === undefined ||
        !course.topics.includes(event.topic) || completedTopics.includes(event.topic)) continue;
      completedTopics.push(event.topic);
    }
    for (const milestone of state.masteryMilestones) {
      if (milestone.courseId !== courseId || !course.topics.includes(milestone.topic) ||
        completedTopics.includes(milestone.topic)) continue;
      completedTopics.push(milestone.topic);
    }
    receipt.courseProgress = Math.min(completedTopics.length / Math.max(course.topics.length, 1), 1);
    return receipt;
  }

  private static validateQuizResult(result: QuizResult): void {
    if (result.quizId.trim().length === 0) throw new Error('答题记录缺少 quizId');
    if (result.source === 'ai' && (result.sourceQuizId ?? '').trim().length === 0) {
      throw new Error('AI 答题记录缺少 sourceQuizId');
    }
    if (!LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic)) {
      throw new Error('答题记录 Topic 不属于当前课程');
    }
    if (result.source !== 'ai' && result.source !== 'curated') {
      throw new Error('答题记录来源无效');
    }
    if (result.totalQuestions <= 0 || result.details.length !== result.totalQuestions) {
      throw new Error('答题记录题目数量不一致');
    }
    const correctCount = result.details.filter((detail: QuizResultDetail): boolean => detail.isCorrect).length;
    if (correctCount !== result.correctCount) throw new Error('答题记录正确数不一致');
    const expectedAccuracy = correctCount / result.totalQuestions;
    if (!Number.isFinite(result.accuracy) || Math.abs(result.accuracy - expectedAccuracy) > 0.0001) {
      throw new Error('答题记录正确率不一致');
    }
    if (Number.isNaN(new Date(result.submittedAt).getTime())) throw new Error('答题记录时间无效');
    const questionIds: string[] = [];
    for (const detail of result.details) {
      if (detail.questionId.trim().length === 0 || questionIds.includes(detail.questionId)) {
        throw new Error('答题记录题目标识无效');
      }
      questionIds.push(detail.questionId);
      const options = detail.options ?? [];
      if (detail.stem.trim().length === 0 || detail.explanation.trim().length === 0 ||
        !LocalLearningRepository.validAnswerOptions(options) ||
        !options.includes(detail.userAnswer) || !options.includes(detail.correctAnswer)) {
        throw new Error('答题记录题目内容不完整');
      }
    }
  }

  private static validAnswerOptions(options: string[]): boolean {
    const labels: string[] = ['A', 'B', 'C', 'D'];
    if (options.length !== labels.length) return false;
    for (let index = 0; index < options.length; index += 1) {
      const option = options[index].trim().toUpperCase();
      if (option.length === 0 || !option.startsWith(labels[index] + '.')) return false;
    }
    return true;
  }

  static async getReviewItems(activeOnly: boolean = true): Promise<ReviewItem[]> {
    const state = await LocalLearningRepository.getQuizLearningState();
    const items = state.reviewItems;
    return activeOnly ? items.filter((item: ReviewItem): boolean => !item.resolved) : items;
  }

  static async getReviewQueue(now: Date = new Date()): Promise<ReviewQueueSnapshot> {
    const state = await LocalLearningRepository.getQuizLearningState();
    const activeItems = state.reviewItems.filter((item: ReviewItem): boolean => !item.resolved);
    const nowTime = now.getTime();
    const dueItems = activeItems.filter((item: ReviewItem): boolean =>
      LocalLearningRepository.isReviewDueAt(item, nowTime));
    dueItems.sort((left: ReviewItem, right: ReviewItem): number =>
      LocalLearningRepository.compareReviewSchedule(left, right));
    return {
      activeItems: activeItems,
      dueItems: dueItems
    };
  }

  static async getDueReviewItems(now: Date = new Date()): Promise<ReviewItem[]> {
    const queue = await LocalLearningRepository.getReviewQueue(now);
    return queue.dueItems;
  }

  private static isReviewDueAt(item: ReviewItem, nowTime: number): boolean {
    const reviewTime = new Date(item.nextReviewAt).getTime();
    return Number.isNaN(reviewTime) || reviewTime <= nowTime;
  }

  private static compareReviewSchedule(left: ReviewItem, right: ReviewItem): number {
    const leftTime = new Date(left.nextReviewAt).getTime();
    const rightTime = new Date(right.nextReviewAt).getTime();
    if (Number.isNaN(leftTime) && Number.isNaN(rightTime)) return right.attempts - left.attempts;
    if (Number.isNaN(leftTime)) return -1;
    if (Number.isNaN(rightTime)) return 1;
    const timeGap = leftTime - rightTime;
    return timeGap !== 0 ? timeGap : right.attempts - left.attempts;
  }

  static async getLessonProgress(courseId?: string): Promise<LessonProgress[]> {
    const items = await LocalLearningRepository.loadLessonProgressUnlocked();
    return courseId === undefined ? items : items.filter((item: LessonProgress): boolean => item.courseId === courseId);
  }

  private static async loadLessonProgressUnlocked(): Promise<LessonProgress[]> {
    return (await LocalLearningRepository.getValue<LessonProgress[]>(KEY_LESSON_PROGRESS)) ?? [];
  }

  private static buildLessonCompletionEventId(courseId: string, topic: string): string {
    return 'lesson_completed:v1:' + courseId.length + ':' + courseId + ':' + topic.length + ':' + topic;
  }

  private static async flushPendingLessonCompletionEvents(): Promise<void> {
    return LocalLearningRepository.runLessonProgressTask(async (): Promise<void> => {
      const items = await LocalLearningRepository.loadLessonProgressUnlocked();
      for (const item of items) {
        if (!LocalLearningRepository.isValidCompletedLessonProgress(item) ||
          item.completionEventSyncedAt !== undefined) continue;
        await LocalLearningRepository.flushLessonCompletionEventUnlocked(items, item);
      }
    });
  }

  private static async flushLessonCompletionEventUnlocked(items: LessonProgress[],
    item: LessonProgress): Promise<void> {
    if (item.completedAt === undefined) return;
    const storedEventId = item.completionEventId;
    const eventId = storedEventId !== undefined && storedEventId.trim().length > 0 ? storedEventId :
      LocalLearningRepository.buildLessonCompletionEventId(item.courseId, item.topic);
    if (storedEventId !== eventId) {
      item.completionEventId = eventId;
      await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, items);
    }
    await LocalLearningRepository.appendStudyEvent({
      id: eventId,
      type: 'lesson_completed',
      timestamp: item.completedAt,
      courseId: item.courseId,
      topic: item.topic
    });
    item.completionEventSyncedAt = new Date().toISOString();
    await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, items);
  }

  static async completeLessonChunk(courseId: string, topic: string, chunkId: string,
    topicChunkCount: number): Promise<void> {
    if (!LocalLearningRepository.isExactCourseTopic(courseId, topic)) {
      throw new Error('课程进度 Topic 不属于当前课程');
    }
    if (chunkId.trim().length === 0 || topicChunkCount <= 0) {
      throw new Error('课程进度分块参数无效');
    }
    return LocalLearningRepository.runLessonProgressTask(async (): Promise<void> => {
      const items = await LocalLearningRepository.loadLessonProgressUnlocked();
      const index = items.findIndex((item: LessonProgress): boolean =>
        item.courseId === courseId && item.topic === topic);
      const now = new Date().toISOString();
      const item: LessonProgress = index >= 0 ? items[index] : {
        courseId: courseId,
        topic: topic,
        completedChunkIds: [],
        updatedAt: now
      };
      if (!item.completedChunkIds.includes(chunkId)) item.completedChunkIds.push(chunkId);
      item.updatedAt = now;
      if (item.completedAt === undefined && item.completedChunkIds.length >= topicChunkCount) {
        item.completedAt = now;
        item.completionEventId = LocalLearningRepository.buildLessonCompletionEventId(courseId, topic);
      }
      if (index >= 0) items[index] = item;
      else items.push(item);
      await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, items);
      if (item.completedAt !== undefined && item.completionEventSyncedAt === undefined) {
        await LocalLearningRepository.flushLessonCompletionEventUnlocked(items, item);
      }
    });
  }

  static async getTopicMastery(courseId?: string): Promise<TopicMastery[]> {
    const state = await LocalLearningRepository.getQuizLearningState();
    const mastery = state.topicMastery;
    if (courseId !== undefined) {
      return mastery.filter((item: TopicMastery): boolean => item.courseId === courseId);
    }
    return mastery;
  }

  static async getTagInsights(limit: number = 6): Promise<TagInsight[]> {
    const insights = await LocalLearningRepository.getAllTagInsights();
    return insights.slice(0, Math.max(0, limit));
  }

  static async getAllTagInsights(): Promise<TagInsight[]> {
    const state = await LocalLearningRepository.getQuizLearningState();
    const insights: TagInsight[] = state.tagInsights.map((item: TagInsight): TagInsight => {
      return LocalLearningRepository.cloneTagInsight(item);
    });
    return insights.sort((left: TagInsight, right: TagInsight): number => {
      const wrongDelta = right.wrongQuestions - left.wrongQuestions;
      if (wrongDelta !== 0) return wrongDelta;
      const totalDelta = right.totalQuestions - left.totalQuestions;
      if (totalDelta !== 0) return totalDelta;
      return left.accuracy - right.accuracy;
    });
  }

  private static cloneTagInsight(item: TagInsight): TagInsight {
    return {
      tag: item.tag,
      courseId: item.courseId,
      topic: item.topic,
      totalQuestions: item.totalQuestions,
      correctQuestions: item.correctQuestions,
      accuracy: item.accuracy,
      wrongQuestions: item.wrongQuestions,
      lastPracticedAt: item.lastPracticedAt,
      easyQuestions: item.easyQuestions,
      mediumQuestions: item.mediumQuestions,
      hardQuestions: item.hardQuestions,
      lastDifficulty: item.lastDifficulty,
      masteryLevel: item.masteryLevel,
      masteryPoints: item.masteryPoints,
      weakReason: item.weakReason,
      nextStep: item.nextStep
    };
  }

  static async getChatHistory(): Promise<ChatMessage[]> {
    return (await LocalLearningRepository.getValue<ChatMessage[]>(KEY_CHAT_HISTORY)) ?? [];
  }

  static async saveChatHistory(history: ChatMessage[]): Promise<void> {
    await LocalLearningRepository.putValue<ChatMessage[]>(KEY_CHAT_HISTORY, history.slice(-24));
  }

  static async getStudyEvents(): Promise<StudyEvent[]> {
    return LocalLearningRepository.runQuizStateTask(async (): Promise<StudyEvent[]> => {
      const storedValue = await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS);
      const stored = Array.isArray(storedValue) ? storedValue : [];
      const events = stored.filter((event: StudyEvent): boolean =>
        LocalLearningRepository.isValidStoredStudyEvent(event) &&
        event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted');
      const state = await LocalLearningRepository.loadQuizLearningStateUnlocked();
      if (state.pendingResults.length > 0) {
        QuizLearningStateReducer.applyPendingResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      return events.concat(state.quizEvents).sort((left: StudyEvent, right: StudyEvent): number => {
        const timestampOrder = LocalLearningRepository.compareTimestamps(left.timestamp, right.timestamp);
        return timestampOrder !== 0 ? timestampOrder : left.id.localeCompare(right.id);
      });
    });
  }

  static async appendStudyEvent(event: StudyEvent): Promise<void> {
    if (event.type === 'quiz_mastered' || event.type === 'quiz_submitted') {
      throw new Error('测验活动必须随答题结果统一写回');
    }
    LocalLearningRepository.validateStudyEvent(event);
    return LocalLearningRepository.runQuizStateTask(async (): Promise<void> => {
      const state = await LocalLearningRepository.loadQuizLearningStateUnlocked();
      if (state.pendingResults.length > 0) {
        QuizLearningStateReducer.applyPendingResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      const storedValue = await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS);
      const stored = Array.isArray(storedValue) ? storedValue : [];
      const events = stored.filter((item: StudyEvent): boolean =>
        LocalLearningRepository.isValidStoredStudyEvent(item) &&
        item.type !== 'quiz_mastered' && item.type !== 'quiz_submitted');
      const existing = events.find((item: StudyEvent): boolean => item.id === event.id);
      if (existing !== undefined && !LocalLearningRepository.sameStudyEvent(existing, event)) {
        throw new Error('学习活动 ID 与已保存内容冲突');
      }
      const persistedEvent = existing ?? event;
      const alreadyAggregated = event.type === 'lesson_activity' &&
        state.appliedInsightEventIds.includes(event.id);
      if (existing === undefined && !alreadyAggregated) {
        events.push(event);
        await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, events.slice(-500));
      }
      if (QuizLearningStateReducer.applyLearningInsightEvent(state, persistedEvent)) {
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
    });
  }

  private static validateStudyEvent(event: StudyEvent): void {
    if (event.id.trim().length === 0 || event.type.trim().length === 0) {
      throw new Error('学习活动标识无效');
    }
    if (Number.isNaN(new Date(event.timestamp).getTime())) throw new Error('学习活动时间无效');
    if (event.type !== 'lesson_activity') return;
    const courseId = event.courseId ?? '';
    const topic = event.topic ?? '';
    if (!LocalLearningRepository.isExactCourseTopic(courseId, topic)) {
      throw new Error('课程互动 Topic 不属于当前课程');
    }
    const tags = (event.tags ?? []).filter((tag: string): boolean => tag.trim().length > 0);
    if (tags.length === 0) throw new Error('课程互动缺少标签');
    if (event.source === 'lesson_self_assessment') return;
    const totalQuestions = event.totalQuestions ?? 1;
    const correctCount = event.correctCount ?? 0;
    if (totalQuestions <= 0 || correctCount < 0 || correctCount > totalQuestions) {
      throw new Error('课程互动计数无效');
    }
  }

  private static sameStudyEvent(left: StudyEvent, right: StudyEvent): boolean {
    if (left.id !== right.id || left.type !== right.type || left.timestamp !== right.timestamp ||
      left.courseId !== right.courseId || left.topic !== right.topic || left.taskId !== right.taskId ||
      left.totalQuestions !== right.totalQuestions || left.correctCount !== right.correctCount ||
      left.source !== right.source || left.difficulty !== right.difficulty || left.accuracy !== right.accuracy) {
      return false;
    }
    const leftTags = left.tags ?? [];
    const rightTags = right.tags ?? [];
    if (leftTags.length !== rightTags.length) return false;
    for (let index = 0; index < leftTags.length; index += 1) {
      if (leftTags[index] !== rightTags[index]) return false;
    }
    return true;
  }

  static async getAchievements(): Promise<AchievementProgress[]> {
    const events = await LocalLearningRepository.getStudyEvents();
    const state = await LocalLearningRepository.getQuizLearningState();
    const completedTasks = LocalLearningRepository.uniqueEvents(events, 'task_completed', true);
    const masteredTopics = state.masteryMilestones.slice()
      .sort((left: TopicMasteryMilestone, right: TopicMasteryMilestone): number => {
        const timestampOrder = LocalLearningRepository.compareTimestamps(left.masteredAt, right.masteredAt);
        if (timestampOrder !== 0) return timestampOrder;
        const courseOrder = left.courseId.localeCompare(right.courseId);
        return courseOrder !== 0 ? courseOrder : left.topic.localeCompare(right.topic);
      });
    const lessonActivities = LocalLearningRepository.uniqueEvents(events, 'lesson_activity', true);
    return [
      LocalLearningRepository.achievement('first_quiz', '初次练习', '完成第一次练习',
        state.stats.totalAttempts, 1, state.stats.firstSubmittedAt),
      LocalLearningRepository.achievement('active_learning_3', '主动学习', '完成 3 个课程互动练习',
        lessonActivities.length, 3, lessonActivities.length >= 3 ? lessonActivities[2].timestamp : undefined),
      LocalLearningRepository.achievement('task_5', '稳步前进', '完成 5 项学习任务', completedTasks.length, 5,
        completedTasks.length >= 5 ? completedTasks[4].timestamp : undefined),
      LocalLearningRepository.achievement('mastery_3', '掌握新知', '掌握 3 个知识点', masteredTopics.length, 3,
        masteredTopics.length >= 3 ? masteredTopics[2].masteredAt : undefined)
    ];
  }

  private static uniqueEvents(events: StudyEvent[], type: string, byTask: boolean): StudyEvent[] {
    const unique: StudyEvent[] = [];
    const keys: string[] = [];
    for (const event of events) {
      if (event.type !== type) continue;
      const key = byTask ? (event.taskId ?? event.id) : (event.courseId ?? '') + ':' + (event.topic ?? '');
      if (!keys.includes(key)) {
        keys.push(key);
        unique.push(event);
      }
    }
    return unique;
  }

  private static achievement(id: string, title: string, description: string, current: number,
    target: number, unlockedAt?: string): AchievementProgress {
    return {
      id: id,
      title: title,
      description: description,
      current: Math.min(current, target),
      target: target,
      unlockedAt: unlockedAt
    };
  }

  private static localDateKey(date: Date): string {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private static calculateStreakDays(studyDates: string[]): number {
    if (studyDates.length === 0) return 0;
    const today = new Date();
    const todayKey = LocalLearningRepository.localDateKey(today);
    const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
    let cursor = studyDates.includes(todayKey) ? today : yesterday;
    if (!studyDates.includes(LocalLearningRepository.localDateKey(cursor))) return 0;
    let streak = 0;
    while (studyDates.includes(LocalLearningRepository.localDateKey(cursor))) {
      streak += 1;
      cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1);
    }
    return streak;
  }
}
