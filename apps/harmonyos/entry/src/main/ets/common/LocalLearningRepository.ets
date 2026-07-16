import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  ChatMessage,
  AchievementProgress,
  Course,
  LessonProgress,
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

export class LocalLearningRepository {
  private static store: relationalStore.RdbStore | null = null;
  private static initializationTask: Promise<void> | null = null;
  private static quizStateQueue: Promise<void> = Promise.resolve();
  private static lessonProgressQueue: Promise<void> = Promise.resolve();

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
        QuizLearningStateReducer.applyPendingResults(existing);
        for (const event of validLegacyEvents) QuizLearningStateReducer.applyLearningInsightEvent(existing, event);
        LocalLearningRepository.mergeLegacyQuizStats(existing, legacyStats, appendLegacyHistory);
        QuizLearningStateReducer.refreshProfileTopics(existing);
        await LocalLearningRepository.putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, existing);
        await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, retainedStudyEvents);
        return;
      }

      const state = QuizLearningStateReducer.createEmptyState();
      const legacyResults = (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
      for (const result of legacyResults.slice().reverse()) {
        if (LocalLearningRepository.isExactCourseTopic(result.courseId, result.topic)) {
          QuizLearningStateReducer.applyResult(state, result);
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
    const state = (await LocalLearningRepository.getValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE)) ??
      QuizLearningStateReducer.createEmptyState();
    let changed = QuizLearningStateReducer.preparePersistentState(state);
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
    return LocalLearningRepository.getValue<StudyPlan>(KEY_PLAN);
  }

  static async savePlan(plan: StudyPlan): Promise<void> {
    await LocalLearningRepository.putValue<StudyPlan>(KEY_PLAN, plan);
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

  static async getDueReviewItems(now: Date = new Date()): Promise<ReviewItem[]> {
    const items = await LocalLearningRepository.getReviewItems(true);
    const due = items.filter((item: ReviewItem): boolean => new Date(item.nextReviewAt).getTime() <= now.getTime());
    return due.sort((left: ReviewItem, right: ReviewItem): number =>
      new Date(left.nextReviewAt).getTime() - new Date(right.nextReviewAt).getTime());
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
        QuizLearningStateReducer.applyPendingResults(state);
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
        QuizLearningStateReducer.applyPendingResults(state);
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
