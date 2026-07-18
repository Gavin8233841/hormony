import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
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
  AppliedQuizProof,
  AiQuizDraft,
  CuratedPracticeDraft,
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail,
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight,
  QuizLearningState,
  QuizWriteReceipt,
  TopicMasteryMilestone
} from '../model/LearningMetadataModels';
import { LearningContentRepository } from './LearningContentRepository';
import { QuizLearningStateReducer } from './QuizLearningStateReducer';

const STORE_NAME: string = 'hongxueban_learning.db';
const TABLE_NAME: string = 'app_state';
const SCHEMA_VERSION: number = 13;

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
const KEY_AI_QUIZ_DRAFTS: string = 'ai_quiz_drafts';
const KEY_CURATED_PRACTICE_DRAFTS: string = 'curated_practice_drafts';

const ANSWER_DRAFT_SCHEMA_VERSION: number = 1;
const ANSWER_DRAFT_LIMIT: number = 12;
const QUIZ_RESULT_FINGERPRINT_VERSION: number = 1;

interface LegacyQuizStatsAggregate {
  totalQuestions: number;
  accuracy: number;
  studyDates: string[];
  updatedAt: string;
}

export interface ReviewQueueSnapshot {
  activeItems: ReviewItem[];
  dueItems: ReviewItem[];
}

export class AnswerDraftClearedError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class QuizResultConflictError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class QuizResultVerificationUnavailableError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class LocalLearningRepository {
  private static store: relationalStore.RdbStore | null = null;
  private static initializationTask: Promise<void> | null = null;
  private static quizStateQueue: Promise<void> = Promise.resolve();
  private static lessonProgressQueue: Promise<void> = Promise.resolve();
  private static planQueue: Promise<void> = Promise.resolve();
  private static answerDraftQueue: Promise<void> = Promise.resolve();
  private static answerDraftAttemptCounter: number = 0;

  static createAnswerDraftAttemptId(prefix: string): string {
    const normalizedPrefix = prefix.trim();
    if (normalizedPrefix.length === 0 || prefix !== normalizedPrefix) {
      throw new Error('草稿标识前缀无效');
    }
    LocalLearningRepository.answerDraftAttemptCounter += 1;
    return normalizedPrefix + '-' + Date.now().toString() + '-' +
      LocalLearningRepository.answerDraftAttemptCounter.toString();
  }

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
      for (const result of results.slice().reverse()) {
        QuizLearningStateReducer.applyResult(state, result,
          LocalLearningRepository.createAppliedQuizProof(result));
      }
      await LocalLearningRepository.putValue<TopicMastery[]>(KEY_TOPIC_MASTERY, state.topicMastery);
    }
    if (previousVersion < 11) {
      await LocalLearningRepository.migrateQuizLearningState();
    }
    if (previousVersion < 12) {
      await LocalLearningRepository.migrateLessonCompletionOutbox();
    }
    if (previousVersion < 13) {
      await LocalLearningRepository.migrateQuizResultProofs();
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

  private static async migrateQuizResultProofs(): Promise<void> {
    return LocalLearningRepository.runQuizStateTask(async (): Promise<void> => {
      const state = await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE);
      if (state === null) return;
      let changed = QuizLearningStateReducer.preparePersistentState(state);
      if (LocalLearningRepository.upgradeAppliedQuizProofs(state)) changed = true;
      if (changed) await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
    });
  }

  private static async migrateQuizLearningState(): Promise<void> {
    return LocalLearningRepository.runQuizStateTask(async (): Promise<void> => {
      const existing = await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE);
      const legacyEvents = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
      const validLegacyEvents = legacyEvents.filter((event: StudyEvent): boolean =>
        LocalLearningRepository.isValidStoredStudyEvent(event));
      const retainedStudyEvents = validLegacyEvents.filter((event: StudyEvent): boolean =>
        event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted').slice(-500);
      if (existing !== null) {
        QuizLearningStateReducer.preparePersistentState(existing);
        LocalLearningRepository.sanitizeQuizLearningState(existing);
        const legacyStats = await LocalLearningRepository.getValue<LegacyQuizStatsAggregate>(KEY_QUIZ_STATS);
        const appendLegacyHistory = LocalLearningRepository.legacyHistoryPrecedesState(existing, legacyStats);
        const legacyMastery = await LocalLearningRepository.getValue<TopicMastery[]>(KEY_TOPIC_MASTERY);
        LocalLearningRepository.mergeLegacyTopicMastery(existing, legacyMastery, appendLegacyHistory);
        const legacyResults = (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
        LocalLearningRepository.mergeLegacyRecentResults(existing, legacyResults);
        const legacyReviews = await LocalLearningRepository.getValue<ReviewItem[]>(KEY_REVIEW_ITEMS);
        LocalLearningRepository.mergeLegacyReviewItems(existing, legacyReviews);
        LocalLearningRepository.mergeLegacyQuizEvents(existing, validLegacyEvents);
        LocalLearningRepository.applyPendingQuizResults(existing);
        for (const event of validLegacyEvents) QuizLearningStateReducer.applyLearningInsightEvent(existing, event);
        LocalLearningRepository.mergeLegacyQuizStats(existing, legacyStats, appendLegacyHistory);
        QuizLearningStateReducer.refreshProfileTopics(existing);
        LocalLearningRepository.upgradeAppliedQuizProofs(existing);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, existing);
        await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, retainedStudyEvents);
        return;
      }

      const state = QuizLearningStateReducer.createEmptyState();
      const legacyResults = (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
      for (const result of legacyResults.slice().reverse()) {
        if (LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic)) {
          QuizLearningStateReducer.applyResult(state, result,
            LocalLearningRepository.createAppliedQuizProof(result));
        }
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

      const legacyMastery = await LocalLearningRepository.getValue<TopicMastery[]>(KEY_TOPIC_MASTERY);
      if (legacyMastery !== null) {
        const validLegacyMastery = legacyMastery.filter((item: TopicMastery): boolean =>
          LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
        const legacyStats = QuizLearningStateReducer.masteryTotals(validLegacyMastery);
        if (legacyStats.totalQuestions >= state.stats.totalQuestions) {
          state.topicMastery = validLegacyMastery;
          state.stats.totalAttempts = legacyStats.totalAttempts;
          state.stats.totalQuestions = legacyStats.totalQuestions;
          state.stats.correctQuestions = legacyStats.correctQuestions;
          state.stats.quizDates = legacyStats.quizDates;
          state.stats.firstSubmittedAt = legacyStats.firstSubmittedAt;
        }
      }

      const generatedEvents = state.quizEvents.slice();
      state.masteryMilestones = [];
      state.quizEvents = validLegacyEvents.filter((event: StudyEvent): boolean =>
        event.type === 'quiz_mastered' || event.type === 'quiz_submitted');
      QuizLearningStateReducer.mergeQuizEvents(state, generatedEvents);
      for (const event of state.quizEvents) {
        const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
        if (!state.stats.quizDates.includes(date)) state.stats.quizDates.push(date);
        if (state.stats.firstSubmittedAt === undefined || event.timestamp < state.stats.firstSubmittedAt) {
          state.stats.firstSubmittedAt = event.timestamp;
        }
      }
      for (const event of validLegacyEvents) QuizLearningStateReducer.applyLearningInsightEvent(state, event);
      QuizLearningStateReducer.refreshProfileTopics(state);
      const legacyStats = await LocalLearningRepository.getValue<LegacyQuizStatsAggregate>(KEY_QUIZ_STATS);
      LocalLearningRepository.mergeLegacyQuizStats(state, legacyStats, false);
      LocalLearningRepository.upgradeAppliedQuizProofs(state);
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, retainedStudyEvents);
    });
  }

  private static legacyHistoryPrecedesState(state: QuizLearningState,
    legacy: LegacyQuizStatsAggregate | null): boolean {
    if (legacy === null || state.stats.firstSubmittedAt === undefined || legacy.updatedAt.length === 0) return false;
    const legacyUpdatedAt = new Date(legacy.updatedAt).getTime();
    const currentFirstSubmittedAt = new Date(state.stats.firstSubmittedAt).getTime();
    return !Number.isNaN(legacyUpdatedAt) && !Number.isNaN(currentFirstSubmittedAt) &&
      legacyUpdatedAt < currentFirstSubmittedAt;
  }

  private static mergeLegacyQuizStats(state: QuizLearningState, legacy: LegacyQuizStatsAggregate | null,
    appendLegacyHistory: boolean): void {
    if (legacy === null || !Number.isFinite(legacy.totalQuestions) || legacy.totalQuestions < 0 ||
      !Number.isFinite(legacy.accuracy) || legacy.accuracy < 0 || legacy.accuracy > 1) return;
    const legacyCorrectQuestions = Math.round(legacy.totalQuestions * legacy.accuracy);
    if (appendLegacyHistory) {
      state.stats.totalQuestions += legacy.totalQuestions;
      state.stats.correctQuestions += legacyCorrectQuestions;
      state.stats.firstSubmittedAt = legacy.updatedAt;
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
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
    let addedAttempts = 0;
    for (const source of validLegacy) {
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
          (source.lastPracticedAt !== undefined && source.lastPracticedAt > target.lastPracticedAt)) {
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
      if (!state.appliedQuizIds.includes(result.quizId)) state.appliedQuizIds.push(result.quizId);
      if (!state.recentResults.some((item: QuizResult): boolean => item.quizId === result.quizId)) {
        state.recentResults.push(result);
      }
    }
    state.recentResults.sort((left: QuizResult, right: QuizResult): number =>
      right.submittedAt.localeCompare(left.submittedAt));
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

  private static runAnswerDraftTask<T>(task: () => Promise<T>): Promise<T> {
    const running: Promise<T> = LocalLearningRepository.answerDraftQueue.then((): Promise<T> => task());
    LocalLearningRepository.answerDraftQueue = running.then((): void => {}, (): void => {});
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
    if (event.courseId === undefined && event.topic === undefined) return true;
    if (event.courseId === undefined || event.topic === undefined) return false;
    return LocalLearningRepository.isExactCourseTopic(event.courseId, event.topic);
  }

  private static sanitizeQuizLearningState(state: QuizLearningState): void {
    const originalStatsSourceCount = state.recentResults.length + state.topicMastery.length + state.quizEvents.length;
    state.pendingResults = state.pendingResults.filter((result: QuizResult): boolean =>
      LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic));
    state.recentResults = state.recentResults.filter((result: QuizResult): boolean =>
      LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic));
    state.reviewItems = state.reviewItems.filter((item: ReviewItem): boolean =>
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
    state.topicMastery = state.topicMastery.filter((item: TopicMastery): boolean =>
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
    state.tagInsights = state.tagInsights.filter((item: TagInsight): boolean =>
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));
    state.quizEvents = state.quizEvents.filter((event: StudyEvent): boolean =>
      LocalLearningRepository.isValidStoredStudyEvent(event));
    state.masteryMilestones = state.masteryMilestones.filter((item: TopicMasteryMilestone): boolean =>
      LocalLearningRepository.isExactCourseTopic(item.courseId, item.topic));

    const retainedStatsSourceCount = state.recentResults.length + state.topicMastery.length + state.quizEvents.length;
    if (retainedStatsSourceCount !== originalStatsSourceCount) {
      const totals = QuizLearningStateReducer.masteryTotals(state.topicMastery);
      state.stats.totalAttempts = totals.totalAttempts;
      state.stats.totalQuestions = totals.totalQuestions;
      state.stats.correctQuestions = totals.correctQuestions;
      state.stats.quizDates = totals.quizDates;
      state.stats.firstSubmittedAt = totals.firstSubmittedAt;
      for (const event of state.quizEvents) {
        const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
        if (!state.stats.quizDates.includes(date)) state.stats.quizDates.push(date);
        if (state.stats.firstSubmittedAt === undefined || event.timestamp < state.stats.firstSubmittedAt) {
          state.stats.firstSubmittedAt = event.timestamp;
        }
      }
    }
    QuizLearningStateReducer.refreshProfileTopics(state);
  }

  private static upgradeAppliedQuizProofs(state: QuizLearningState): boolean {
    const next: AppliedQuizProof[] = [];
    for (const quizId of state.appliedQuizIds) {
      if (next.some((item: AppliedQuizProof): boolean => item.quizId === quizId)) continue;
      const existing = state.appliedQuizProofs.find((item: AppliedQuizProof): boolean => item.quizId === quizId);
      if (existing !== undefined && existing.verification === 'verified' &&
        LocalLearningRepository.validAppliedQuizProof(existing)) {
        next.push(existing);
        continue;
      }
      const result = state.recentResults.find((item: QuizResult): boolean => item.quizId === quizId);
      if (result !== undefined) {
        next.push(LocalLearningRepository.createAppliedQuizProof(result));
        continue;
      }
      if (existing !== undefined && LocalLearningRepository.validAppliedQuizProof(existing)) {
        next.push(existing);
      } else {
        next.push({
          quizId: quizId,
          verification: 'legacy-unverifiable',
          fingerprintVersion: 0,
          payloadSha256: ''
        });
      }
    }
    if (LocalLearningRepository.sameAppliedQuizProofs(state.appliedQuizProofs, next)) return false;
    state.appliedQuizProofs = next;
    return true;
  }

  private static validAppliedQuizProof(proof: AppliedQuizProof): boolean {
    if (proof.quizId.trim().length === 0) return false;
    if (proof.verification === 'legacy-unverifiable') {
      return proof.fingerprintVersion === 0 && proof.payloadSha256.length === 0;
    }
    if (proof.verification !== 'verified' || proof.fingerprintVersion !== QUIZ_RESULT_FINGERPRINT_VERSION ||
      proof.payloadSha256.length !== 64) return false;
    const hex = '0123456789abcdef';
    for (const character of proof.payloadSha256) {
      if (!hex.includes(character)) return false;
    }
    return true;
  }

  private static sameAppliedQuizProofs(left: AppliedQuizProof[], right: AppliedQuizProof[]): boolean {
    if (left.length !== right.length) return false;
    for (let index = 0; index < left.length; index += 1) {
      if (left[index].quizId !== right[index].quizId ||
        left[index].verification !== right[index].verification ||
        left[index].fingerprintVersion !== right[index].fingerprintVersion ||
        left[index].payloadSha256 !== right[index].payloadSha256) return false;
    }
    return true;
  }

  private static createAppliedQuizProof(result: QuizResult): AppliedQuizProof {
    return {
      quizId: result.quizId,
      verification: 'verified',
      fingerprintVersion: QUIZ_RESULT_FINGERPRINT_VERSION,
      payloadSha256: LocalLearningRepository.sha256(
        LocalLearningRepository.quizResultFingerprintPayload(result))
    };
  }

  private static quizResultFingerprintPayload(result: QuizResult): string {
    const parts: string[] = [];
    LocalLearningRepository.appendFingerprintField(parts, 'quiz-result-v1');
    LocalLearningRepository.appendFingerprintField(parts, result.quizId);
    LocalLearningRepository.appendOptionalFingerprintField(parts, result.sourceQuizId);
    LocalLearningRepository.appendFingerprintField(parts, result.userId);
    LocalLearningRepository.appendFingerprintField(parts, result.courseId);
    LocalLearningRepository.appendFingerprintField(parts, result.topic);
    LocalLearningRepository.appendFingerprintField(parts, result.source);
    LocalLearningRepository.appendOptionalFingerprintField(parts, result.difficulty);
    LocalLearningRepository.appendFingerprintField(parts, result.totalQuestions.toString());
    LocalLearningRepository.appendFingerprintField(parts, result.correctCount.toString());
    LocalLearningRepository.appendFingerprintField(parts, result.accuracy.toString());
    LocalLearningRepository.appendFingerprintField(parts, result.evaluation);
    LocalLearningRepository.appendFingerprintField(parts, result.submittedAt);
    LocalLearningRepository.appendFingerprintArray(parts, result.weakTopics);
    LocalLearningRepository.appendFingerprintField(parts, result.details.length.toString());
    for (const detail of result.details) {
      LocalLearningRepository.appendFingerprintField(parts, detail.questionId);
      LocalLearningRepository.appendFingerprintField(parts, detail.stem);
      LocalLearningRepository.appendFingerprintArray(parts, detail.options ?? []);
      LocalLearningRepository.appendFingerprintField(parts, detail.userAnswer);
      LocalLearningRepository.appendFingerprintField(parts, detail.correctAnswer);
      LocalLearningRepository.appendFingerprintField(parts, detail.isCorrect ? '1' : '0');
      LocalLearningRepository.appendFingerprintField(parts, detail.explanation);
      LocalLearningRepository.appendOptionalFingerprintField(parts, detail.difficulty);
      LocalLearningRepository.appendFingerprintArray(parts, detail.tags ?? []);
      LocalLearningRepository.appendOptionalFingerprintField(parts, detail.reviewItemId);
    }
    return parts.join('');
  }

  private static appendFingerprintField(parts: string[], value: string): void {
    parts.push(value.length.toString() + ':' + value);
  }

  private static appendOptionalFingerprintField(parts: string[], value: string | undefined): void {
    if (value === undefined) {
      LocalLearningRepository.appendFingerprintField(parts, '0');
      return;
    }
    LocalLearningRepository.appendFingerprintField(parts, '1');
    LocalLearningRepository.appendFingerprintField(parts, value);
  }

  private static appendFingerprintArray(parts: string[], values: string[]): void {
    LocalLearningRepository.appendFingerprintField(parts, values.length.toString());
    for (const value of values) LocalLearningRepository.appendFingerprintField(parts, value);
  }

  private static sha256(value: string): string {
    try {
      const digest = cryptoFramework.createMd('SHA256');
      const encoder = new util.TextEncoder('utf-8');
      digest.updateSync({ data: encoder.encodeInto(value) });
      const bytes = digest.digestSync().data;
      const hex = '0123456789abcdef';
      let result = '';
      for (const byte of bytes) {
        const high = (byte >> 4) & 15;
        const low = byte & 15;
        result += hex.substring(high, high + 1) + hex.substring(low, low + 1);
      }
      return result;
    } catch (error) {
      throw new Error('生成答题记录完整性摘要失败: ' + String(error));
    }
  }

  private static applyPendingQuizResults(state: QuizLearningState): number {
    const proofs = state.pendingResults.map((result: QuizResult): AppliedQuizProof =>
      LocalLearningRepository.createAppliedQuizProof(result));
    return QuizLearningStateReducer.applyPendingResults(state, proofs);
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

  private static getValueSync<T>(key: string): T | null {
    const store = LocalLearningRepository.requireStore();
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = store.querySqlSync(
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

  private static putValueSync<T>(key: string, value: T): void {
    const store = LocalLearningRepository.requireStore();
    try {
      store.executeSync(
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (state_key, payload, updated_at) VALUES (?, ?, ?)',
        [key, JSON.stringify(value), Date.now()]
      );
    } catch (error) {
      throw new Error('保存本地学习状态失败: ' + String(error));
    }
  }

  private static runAnswerDraftCreateTransaction(task: () => void, isCurrent: () => boolean): boolean {
    if (!isCurrent()) return false;
    const store = LocalLearningRepository.requireStore();
    let transactionStarted = false;
    try {
      store.beginTransaction();
      transactionStarted = true;
      task();
      if (!isCurrent()) {
        store.rollBack();
        transactionStarted = false;
        return false;
      }
      store.commit();
      transactionStarted = false;
      return true;
    } catch (error) {
      if (transactionStarted) {
        try {
          store.rollBack();
        } catch (rollbackError) {
          throw new Error('本地草稿事务回滚失败: ' + String(rollbackError));
        }
      }
      if (error instanceof Error) throw error;
      throw new Error(String(error));
    }
  }

  private static async loadQuizLearningStateUnlocked(): Promise<QuizLearningState> {
    const state = (await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE)) ??
      QuizLearningStateReducer.createEmptyState();
    let changed = QuizLearningStateReducer.preparePersistentState(state);
    if (LocalLearningRepository.upgradeAppliedQuizProofs(state)) changed = true;
    const storedEvents = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
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
        LocalLearningRepository.applyPendingQuizResults(state);
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

  static async getAiQuizDraft(courseId: string, topic: string, focusTag: string): Promise<AiQuizDraft | null> {
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<AiQuizDraft | null> => {
      const drafts = (await LocalLearningRepository.getValue<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS)) ?? [];
      const draft = drafts.find((item: AiQuizDraft): boolean => item.courseId === courseId &&
        item.topic === topic && item.focusTag === focusTag);
      if (draft === undefined || !LocalLearningRepository.validAiQuizDraft(draft)) return null;
      const cloned: AiQuizDraft = JSON.parse(JSON.stringify(draft));
      return cloned;
    });
  }

  static async createAiQuizDraft(draft: AiQuizDraft, isCurrent: () => boolean): Promise<boolean> {
    if (!LocalLearningRepository.validAiQuizDraft(draft)) throw new Error('AI 测验草稿结构无效');
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<boolean> =>
      LocalLearningRepository.runAnswerDraftCreateTransaction((): void => {
        const drafts = LocalLearningRepository.getValueSync<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS) ?? [];
        const storedCurrent = drafts.find((item: AiQuizDraft): boolean => item.courseId === draft.courseId &&
          item.topic === draft.topic && item.focusTag === draft.focusTag);
        const current = storedCurrent !== undefined && LocalLearningRepository.validAiQuizDraft(storedCurrent) ?
          storedCurrent : undefined;
        if (current !== undefined) {
          if (current.attemptId !== draft.attemptId) {
            throw new AnswerDraftClearedError('AI 测验已有其他页面创建的草稿');
          }
          if (JSON.stringify(current) !== JSON.stringify(draft)) {
            throw new AnswerDraftClearedError('AI 测验草稿创建载荷冲突');
          }
          return;
        }
        const retained = drafts.filter((item: AiQuizDraft): boolean =>
          !(item.courseId === draft.courseId && item.topic === draft.topic && item.focusTag === draft.focusTag));
        const cloned: AiQuizDraft = JSON.parse(JSON.stringify(draft));
        retained.push(cloned);
        LocalLearningRepository.putValueSync<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS,
          retained.slice(-ANSWER_DRAFT_LIMIT));
      }, isCurrent));
  }

  static async saveAiQuizDraft(draft: AiQuizDraft): Promise<void> {
    if (!LocalLearningRepository.validAiQuizDraft(draft)) throw new Error('AI 测验草稿结构无效');
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<void> => {
      const drafts = (await LocalLearningRepository.getValue<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS)) ?? [];
      const storedCurrent = drafts.find((item: AiQuizDraft): boolean => item.courseId === draft.courseId &&
        item.topic === draft.topic && item.focusTag === draft.focusTag);
      const current = storedCurrent !== undefined && LocalLearningRepository.validAiQuizDraft(storedCurrent) ?
        storedCurrent : undefined;
      if (current === undefined || current.attemptId !== draft.attemptId) {
        throw new AnswerDraftClearedError('AI 测验草稿已被其他页面结束');
      }
      const retained = drafts.filter((item: AiQuizDraft): boolean =>
        !(item.courseId === draft.courseId && item.topic === draft.topic && item.focusTag === draft.focusTag));
      const cloned: AiQuizDraft = JSON.parse(JSON.stringify(draft));
      retained.push(cloned);
      await LocalLearningRepository.putValue<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS,
        retained.slice(-ANSWER_DRAFT_LIMIT));
    });
  }

  static async clearAiQuizDraft(attemptId: string): Promise<void> {
    const normalizedAttemptId = attemptId.trim();
    if (normalizedAttemptId.length === 0 || attemptId !== normalizedAttemptId) {
      throw new Error('AI 测验草稿标识无效');
    }
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<void> => {
      const drafts = (await LocalLearningRepository.getValue<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS)) ?? [];
      const retained = drafts.filter((item: AiQuizDraft): boolean => item.attemptId !== normalizedAttemptId);
      if (retained.length !== drafts.length) {
        await LocalLearningRepository.putValue<AiQuizDraft[]>(KEY_AI_QUIZ_DRAFTS, retained);
      }
    });
  }

  static async getCuratedPracticeDraft(courseId: string, topic: string,
    selectedReviewItemId: string): Promise<CuratedPracticeDraft | null> {
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<CuratedPracticeDraft | null> => {
      const drafts = (await LocalLearningRepository.getValue<CuratedPracticeDraft[]>(
        KEY_CURATED_PRACTICE_DRAFTS)) ?? [];
      const draft = drafts.find((item: CuratedPracticeDraft): boolean => item.courseId === courseId &&
        item.topic === topic && item.selectedReviewItemId === selectedReviewItemId);
      if (draft === undefined || !LocalLearningRepository.validCuratedPracticeDraft(draft)) return null;
      const cloned: CuratedPracticeDraft = JSON.parse(JSON.stringify(draft));
      return cloned;
    });
  }

  static async createCuratedPracticeDraft(draft: CuratedPracticeDraft,
    isCurrent: () => boolean): Promise<boolean> {
    if (!LocalLearningRepository.validCuratedPracticeDraft(draft)) {
      throw new Error('精选练习草稿结构无效');
    }
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<boolean> =>
      LocalLearningRepository.runAnswerDraftCreateTransaction((): void => {
        const drafts = LocalLearningRepository.getValueSync<CuratedPracticeDraft[]>(
          KEY_CURATED_PRACTICE_DRAFTS) ?? [];
        const storedCurrent = drafts.find((item: CuratedPracticeDraft): boolean =>
          item.courseId === draft.courseId && item.topic === draft.topic &&
            item.selectedReviewItemId === draft.selectedReviewItemId);
        const current = storedCurrent !== undefined &&
          LocalLearningRepository.validCuratedPracticeDraft(storedCurrent) ? storedCurrent : undefined;
        if (current !== undefined) {
          if (current.attemptId !== draft.attemptId) {
            throw new AnswerDraftClearedError('精选练习已有其他页面创建的草稿');
          }
          if (JSON.stringify(current) !== JSON.stringify(draft)) {
            throw new AnswerDraftClearedError('精选练习草稿创建载荷冲突');
          }
          return;
        }
        const retained = drafts.filter((item: CuratedPracticeDraft): boolean =>
          !(item.courseId === draft.courseId && item.topic === draft.topic &&
            item.selectedReviewItemId === draft.selectedReviewItemId));
        const cloned: CuratedPracticeDraft = JSON.parse(JSON.stringify(draft));
        retained.push(cloned);
        LocalLearningRepository.putValueSync<CuratedPracticeDraft[]>(KEY_CURATED_PRACTICE_DRAFTS,
          retained.slice(-ANSWER_DRAFT_LIMIT));
      }, isCurrent));
  }

  static async saveCuratedPracticeDraft(draft: CuratedPracticeDraft): Promise<void> {
    if (!LocalLearningRepository.validCuratedPracticeDraft(draft)) {
      throw new Error('精选练习草稿结构无效');
    }
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<void> => {
      const drafts = (await LocalLearningRepository.getValue<CuratedPracticeDraft[]>(
        KEY_CURATED_PRACTICE_DRAFTS)) ?? [];
      const storedCurrent = drafts.find((item: CuratedPracticeDraft): boolean =>
        item.courseId === draft.courseId && item.topic === draft.topic &&
          item.selectedReviewItemId === draft.selectedReviewItemId);
      const current = storedCurrent !== undefined &&
        LocalLearningRepository.validCuratedPracticeDraft(storedCurrent) ? storedCurrent : undefined;
      if (current === undefined || current.attemptId !== draft.attemptId) {
        throw new AnswerDraftClearedError('精选练习草稿已被其他页面结束');
      }
      const retained = drafts.filter((item: CuratedPracticeDraft): boolean =>
        !(item.courseId === draft.courseId && item.topic === draft.topic &&
          item.selectedReviewItemId === draft.selectedReviewItemId));
      const cloned: CuratedPracticeDraft = JSON.parse(JSON.stringify(draft));
      retained.push(cloned);
      await LocalLearningRepository.putValue<CuratedPracticeDraft[]>(KEY_CURATED_PRACTICE_DRAFTS,
        retained.slice(-ANSWER_DRAFT_LIMIT));
    });
  }

  static async clearCuratedPracticeDraft(attemptId: string): Promise<void> {
    const normalizedAttemptId = attemptId.trim();
    if (normalizedAttemptId.length === 0 || attemptId !== normalizedAttemptId) {
      throw new Error('精选练习草稿标识无效');
    }
    return LocalLearningRepository.runAnswerDraftTask(async (): Promise<void> => {
      const drafts = (await LocalLearningRepository.getValue<CuratedPracticeDraft[]>(
        KEY_CURATED_PRACTICE_DRAFTS)) ?? [];
      const retained = drafts.filter((item: CuratedPracticeDraft): boolean =>
        item.attemptId !== normalizedAttemptId);
      if (retained.length !== drafts.length) {
        await LocalLearningRepository.putValue<CuratedPracticeDraft[]>(KEY_CURATED_PRACTICE_DRAFTS, retained);
      }
    });
  }

  private static validAiQuizDraft(draft: AiQuizDraft): boolean {
    if (draft.schemaVersion !== ANSWER_DRAFT_SCHEMA_VERSION || draft.attemptId.trim().length === 0 ||
      draft.attemptId !== draft.attemptId.trim() ||
      draft.sourceQuizId.trim().length === 0 || !LocalLearningRepository.isExactCourseTopic(
        draft.courseId, draft.topic) || draft.courseTitle.trim().length === 0 ||
      (draft.difficulty !== 'easy' && draft.difficulty !== 'medium' && draft.difficulty !== 'hard') ||
      ![5, 10, 15].includes(draft.questionCount) || draft.focusTag.length > 12 ||
      draft.questions.length !== draft.questionCount || draft.questions.length !== draft.grading.length ||
      draft.answers.length !== draft.questions.length || draft.currentIndex < 0 ||
      draft.currentIndex >= draft.questions.length || Number.isNaN(new Date(draft.updatedAt).getTime()) ||
      (draft.attemptSubmittedAt !== undefined && Number.isNaN(new Date(draft.attemptSubmittedAt).getTime()))) {
      return false;
    }
    const questionIds: string[] = [];
    for (let index = 0; index < draft.questions.length; index += 1) {
      const question = draft.questions[index];
      const options = question.options ?? [];
      const answer = draft.answers[index];
      if (question.id.trim().length === 0 || questionIds.includes(question.id) || question.stem.trim().length === 0 ||
        !LocalLearningRepository.validAnswerOptions(options) || (answer.length > 0 && !options.includes(answer))) {
        return false;
      }
      questionIds.push(question.id);
    }
    const gradingIds: string[] = [];
    for (const grading of draft.grading) {
      if (!questionIds.includes(grading.questionId) || gradingIds.includes(grading.questionId) ||
        !['A', 'B', 'C', 'D'].includes(
        grading.answer.trim().toUpperCase()) || grading.explanation.trim().length === 0) {
        return false;
      }
      gradingIds.push(grading.questionId);
    }
    return true;
  }

  private static validCuratedPracticeDraft(draft: CuratedPracticeDraft): boolean {
    if (draft.schemaVersion !== ANSWER_DRAFT_SCHEMA_VERSION || draft.attemptId.trim().length === 0 ||
      draft.attemptId !== draft.attemptId.trim() ||
      !LocalLearningRepository.isExactCourseTopic(draft.courseId, draft.topic) ||
      draft.courseTitle.trim().length === 0 || draft.questions.length === 0 ||
      draft.questions.length > 5 ||
      draft.reviewItemIds.length !== draft.questions.length || draft.answers.length !== draft.questions.length ||
      draft.currentIndex < 0 || draft.currentIndex >= draft.questions.length ||
      Number.isNaN(new Date(draft.updatedAt).getTime()) ||
      (draft.attemptSubmittedAt !== undefined && Number.isNaN(new Date(draft.attemptSubmittedAt).getTime()))) {
      return false;
    }
    const questionIds: string[] = [];
    for (let index = 0; index < draft.questions.length; index += 1) {
      const question = draft.questions[index];
      const answer = draft.answers[index];
      if (question.id.trim().length === 0 || questionIds.includes(question.id) ||
        question.courseId !== draft.courseId || question.topic !== draft.topic || question.question.trim().length === 0 ||
        question.explanation.trim().length === 0 || !LocalLearningRepository.validAnswerOptions(question.options) ||
        !['A', 'B', 'C', 'D'].includes(question.answer.trim().toUpperCase()) ||
        (answer.length > 0 && !question.options.includes(answer))) {
        return false;
      }
      questionIds.push(question.id);
    }
    return true;
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
        LocalLearningRepository.applyPendingQuizResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      if (state.appliedQuizIds.includes(result.quizId)) {
        const proof = state.appliedQuizProofs.find((item: AppliedQuizProof): boolean => item.quizId === result.quizId);
        if (proof === undefined || proof.verification === 'legacy-unverifiable' ||
          proof.fingerprintVersion !== QUIZ_RESULT_FINGERPRINT_VERSION) {
          throw new QuizResultVerificationUnavailableError('历史答题记录缺少可验证摘要');
        }
        const expected = LocalLearningRepository.createAppliedQuizProof(result);
        if (proof.payloadSha256 !== expected.payloadSha256) {
          throw new QuizResultConflictError('答题记录 ID 与已保存内容冲突');
        }
        const receipt = QuizLearningStateReducer.createReceipt(state, result, false);
        return LocalLearningRepository.withCourseProgress(receipt, state, result.courseId);
      }

      QuizLearningStateReducer.enqueueResult(state, result);
      await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      const applied = LocalLearningRepository.applyPendingQuizResults(state) > 0;
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
      const stored = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
      const events = stored.filter((event: StudyEvent): boolean =>
        event.type !== 'quiz_mastered' && event.type !== 'quiz_submitted' &&
        LocalLearningRepository.isValidStoredStudyEvent(event));
      const state = await LocalLearningRepository.loadQuizLearningStateUnlocked();
      if (state.pendingResults.length > 0) {
        LocalLearningRepository.applyPendingQuizResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      return events.concat(state.quizEvents).sort((left: StudyEvent, right: StudyEvent): number =>
        left.timestamp.localeCompare(right.timestamp));
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
        LocalLearningRepository.applyPendingQuizResults(state);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state);
      }
      const stored = (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
      const events = stored.filter((item: StudyEvent): boolean =>
        item.type !== 'quiz_mastered' && item.type !== 'quiz_submitted' &&
        LocalLearningRepository.isValidStoredStudyEvent(item));
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
      .sort((left: TopicMasteryMilestone, right: TopicMasteryMilestone): number =>
        left.masteredAt.localeCompare(right.masteredAt));
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
