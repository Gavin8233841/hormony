import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  ChatMessage,
  AchievementProgress,
  Course,
  LessonProgress,
  QuizResult,
  ReviewItem,
  StudyPlan,
  StudyEvent,
  TagInsight,
  TopicMastery,
  UserProfile,
  UserStats
} from '../model/DataModels';

const STORE_NAME: string = 'hongxueban_learning.db';
const TABLE_NAME: string = 'app_state';
const SCHEMA_VERSION: number = 5;

const KEY_PROFILE: string = 'profile';
const KEY_COURSES: string = 'courses';
const KEY_PLAN: string = 'plan';
const KEY_QUIZ_RESULTS: string = 'quiz_results';
const KEY_CHAT_HISTORY: string = 'chat_history';
const KEY_STUDY_EVENTS: string = 'study_events';
const KEY_LESSON_PROGRESS: string = 'lesson_progress';
const KEY_REVIEW_ITEMS: string = 'review_items';
const KEY_FORM_IDS: string = 'form_ids';

interface CachedStatePayload {
  key: string;
  payload: string;
}

export interface ReviewQueues {
  dueItems: ReviewItem[];
  activeItems: ReviewItem[];
}

export interface ProfileSnapshot {
  profile: UserProfile | null;
  tagInsights: TagInsight[];
}

interface CourseTopicProgress {
  courseId: string;
  topics: string[];
}

export class LocalLearningRepository {
  private static store: relationalStore.RdbStore | null = null;
  private static valueCache: CachedStatePayload[] = [];

  static async initialize(context: common.Context): Promise<void> {
    if (LocalLearningRepository.store !== null) return;

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
    const previousVersion = await LocalLearningRepository.getValue<number>('schema_version') ?? 0;
    await LocalLearningRepository.migrate(previousVersion);
    await LocalLearningRepository.putValue<number>('schema_version', SCHEMA_VERSION);
    await LocalLearningRepository.ensureDefaults();
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

  private static async getValue<T>(key: string): Promise<T | null> {
    const cached = LocalLearningRepository.valueCache.find((item: CachedStatePayload): boolean => item.key === key);
    if (cached !== undefined) {
      const cachedValue: T = JSON.parse(cached.payload);
      return cachedValue;
    }

    const store = LocalLearningRepository.requireStore();
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await store.querySql(
        'SELECT payload FROM ' + TABLE_NAME + ' WHERE state_key = ?',
        [key]
      );
      if (!resultSet.goToFirstRow()) return null;
      const payload = resultSet.getString(0);
      LocalLearningRepository.setCachedPayload(key, payload);
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
      const payload = JSON.stringify(value);
      await store.executeSql(
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (state_key, payload, updated_at) VALUES (?, ?, ?)',
        [key, payload, Date.now()]
      );
      LocalLearningRepository.setCachedPayload(key, payload);
    } catch (error) {
      throw new Error('保存本地学习状态失败: ' + String(error));
    }
  }

  private static setCachedPayload(key: string, payload: string): void {
    const index = LocalLearningRepository.valueCache.findIndex((item: CachedStatePayload): boolean => item.key === key);
    if (index >= 0) {
      LocalLearningRepository.valueCache[index] = { key: key, payload: payload };
      return;
    }
    LocalLearningRepository.valueCache.push({ key: key, payload: payload });
  }

  static async getProfile(): Promise<UserProfile | null> {
    const profile = await LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
    if (profile === null) return null;
    const results = await LocalLearningRepository.getQuizResults();
    const events = await LocalLearningRepository.getStudyEvents();
    profile.stats = LocalLearningRepository.calculateProfileStats(results, events);
    return profile;
  }

  static getCachedProfile(): UserProfile | null {
    const cached = LocalLearningRepository.valueCache.find((item: CachedStatePayload): boolean => item.key === KEY_PROFILE);
    if (cached === undefined) return null;
    const profile: UserProfile = JSON.parse(cached.payload);
    return profile;
  }

  static async getProfileSnapshot(tagLimit: number = 6): Promise<ProfileSnapshot> {
    const profile = await LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
    const results = await LocalLearningRepository.getQuizResults();
    const events = await LocalLearningRepository.getStudyEvents();
    if (profile !== null) {
      profile.stats = LocalLearningRepository.calculateProfileStats(results, events);
    }
    return {
      profile: profile,
      tagInsights: LocalLearningRepository.buildTagInsights(results, tagLimit)
    };
  }

  private static calculateProfileStats(results: QuizResult[], events: StudyEvent[]): UserStats {
    let totalQuestions = 0;
    let correctQuestions = 0;
    const studyDates: string[] = [];
    for (const result of results) {
      totalQuestions += result.totalQuestions;
      correctQuestions += result.correctCount;
      const date = LocalLearningRepository.localDateKey(new Date(result.submittedAt));
      if (!studyDates.includes(date)) studyDates.push(date);
    }
    for (const event of events) {
      const date = LocalLearningRepository.localDateKey(new Date(event.timestamp));
      if (!studyDates.includes(date)) studyDates.push(date);
    }
    return {
      totalQuestions: totalQuestions,
      accuracy: totalQuestions > 0 ? correctQuestions / totalQuestions : 0,
      studyDays: studyDates.length,
      streakDays: LocalLearningRepository.calculateStreakDays(studyDates)
    };
  }

  static async saveProfile(profile: UserProfile): Promise<void> {
    await LocalLearningRepository.putValue<UserProfile>(KEY_PROFILE, profile);
  }

  static async getCourses(): Promise<Course[] | null> {
    const courses = await LocalLearningRepository.getValue<Course[]>(KEY_COURSES);
    if (courses === null) return null;
    const events = await LocalLearningRepository.getStudyEvents();
    const completedByCourse = LocalLearningRepository.buildCompletedTopicsByCourse(events);
    return courses.map((course: Course): Course => {
      const completedTopics = LocalLearningRepository.findCompletedCourseTopics(completedByCourse, course.id, course.topics);
      return {
        id: course.id,
        title: course.title,
        progress: Math.min(completedTopics.length / Math.max(course.topics.length, 1), 1),
        docCount: course.docCount,
        topics: course.topics
      };
    });
  }

  private static buildCompletedTopicsByCourse(events: StudyEvent[]): CourseTopicProgress[] {
    const progress: CourseTopicProgress[] = [];
    for (const event of events) {
      if (event.topic === undefined || event.courseId === undefined) continue;
      if (event.type !== 'lesson_completed' && event.type !== 'quiz_mastered') continue;
      let bucket = progress.find((item: CourseTopicProgress): boolean => item.courseId === event.courseId);
      if (bucket === undefined) {
        bucket = { courseId: event.courseId, topics: [] };
        progress.push(bucket);
      }
      if (!bucket.topics.includes(event.topic)) bucket.topics.push(event.topic);
    }
    return progress;
  }

  private static findCompletedCourseTopics(progress: CourseTopicProgress[], courseId: string, courseTopics: string[]): string[] {
    const bucket = progress.find((item: CourseTopicProgress): boolean => item.courseId === courseId);
    if (bucket === undefined) return [];
    return bucket.topics.filter((topic: string): boolean => courseTopics.includes(topic));
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
    return (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
  }

  static async appendQuizResult(result: QuizResult): Promise<void> {
    const results = await LocalLearningRepository.getQuizResults();
    results.unshift(result);
    await LocalLearningRepository.putValue<QuizResult[]>(KEY_QUIZ_RESULTS, results.slice(0, 20));
    const profile = await LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
    if (profile !== null) {
      for (const topic of result.weakTopics) {
        if (!profile.weakTopics.includes(topic)) profile.weakTopics.push(topic);
        const strongIndex = profile.strongTopics.indexOf(topic);
        if (strongIndex >= 0) profile.strongTopics.splice(strongIndex, 1);
      }
      if (result.accuracy >= 0.8 && !profile.strongTopics.includes(result.topic)) {
        profile.strongTopics.push(result.topic);
        const weakIndex = profile.weakTopics.indexOf(result.topic);
        if (weakIndex >= 0) profile.weakTopics.splice(weakIndex, 1);
      }
      await LocalLearningRepository.putValue<UserProfile>(KEY_PROFILE, profile);
    }
    await LocalLearningRepository.appendStudyEvent({
      id: 'event_' + Date.now().toString(),
      type: result.accuracy >= 0.8 ? 'quiz_mastered' : 'quiz_submitted',
      timestamp: result.submittedAt,
      courseId: result.courseId,
      topic: result.topic,
      totalQuestions: result.totalQuestions,
      correctCount: result.correctCount
    });
    await LocalLearningRepository.updateReviewItems(result);
  }

  private static async updateReviewItems(result: QuizResult): Promise<void> {
    const items = await LocalLearningRepository.getReviewItems(false);
    for (const detail of result.details) {
      const existingIndex = items.findIndex((item: ReviewItem): boolean => item.questionId === detail.questionId);
      if (detail.isCorrect) {
        if (existingIndex >= 0) {
          const previous = items[existingIndex];
          const nextInterval = LocalLearningRepository.nextReviewInterval(previous.intervalDays);
          items[existingIndex] = {
            id: previous.id,
            questionId: previous.questionId,
            courseId: previous.courseId,
            topic: previous.topic,
            source: previous.source,
            stem: detail.stem,
            userAnswer: detail.userAnswer,
            correctAnswer: detail.correctAnswer,
            explanation: detail.explanation,
            attempts: previous.attempts + 1,
            resolved: nextInterval === 0,
            intervalDays: nextInterval === 0 ? previous.intervalDays : nextInterval,
            nextReviewAt: nextInterval === 0 ? result.submittedAt :
              LocalLearningRepository.addDays(result.submittedAt, nextInterval),
            updatedAt: result.submittedAt,
            tags: detail.tags ?? previous.tags ?? []
          };
        }
        continue;
      }
      const next: ReviewItem = {
        id: existingIndex >= 0 ? items[existingIndex].id : 'review_' + detail.questionId,
        questionId: detail.questionId,
        courseId: result.courseId,
        topic: result.topic,
        source: result.source,
        stem: detail.stem,
        userAnswer: detail.userAnswer,
        correctAnswer: detail.correctAnswer,
        explanation: detail.explanation,
        attempts: existingIndex >= 0 ? items[existingIndex].attempts + 1 : 1,
        resolved: false,
        intervalDays: 1,
        nextReviewAt: LocalLearningRepository.addDays(result.submittedAt, 1),
        updatedAt: result.submittedAt,
        tags: detail.tags ?? []
      };
      if (existingIndex >= 0) items[existingIndex] = next;
      else items.push(next);
    }
    await LocalLearningRepository.putValue<ReviewItem[]>(KEY_REVIEW_ITEMS, items.slice(-200));
  }

  private static nextReviewInterval(currentIntervalDays: number): number {
    if (currentIntervalDays < 1) return 1;
    if (currentIntervalDays < 3) return 3;
    if (currentIntervalDays < 7) return 7;
    if (currentIntervalDays < 14) return 14;
    return 0;
  }

  static async getReviewItems(activeOnly: boolean = true): Promise<ReviewItem[]> {
    const items = (await LocalLearningRepository.getValue<ReviewItem[]>(KEY_REVIEW_ITEMS)) ?? [];
    return activeOnly ? items.filter((item: ReviewItem): boolean => !item.resolved) : items;
  }

  static async getDueReviewItems(now: Date = new Date()): Promise<ReviewItem[]> {
    const queues = await LocalLearningRepository.getReviewQueues(now);
    return queues.dueItems;
  }

  static async getReviewQueues(now: Date = new Date()): Promise<ReviewQueues> {
    const activeItems = await LocalLearningRepository.getReviewItems(true);
    const dueItems = activeItems
      .filter((item: ReviewItem): boolean => new Date(item.nextReviewAt).getTime() <= now.getTime())
      .sort((left: ReviewItem, right: ReviewItem): number =>
        new Date(left.nextReviewAt).getTime() - new Date(right.nextReviewAt).getTime());
    return { dueItems: dueItems, activeItems: activeItems };
  }

  static async getLessonProgress(courseId?: string): Promise<LessonProgress[]> {
    const items = (await LocalLearningRepository.getValue<LessonProgress[]>(KEY_LESSON_PROGRESS)) ?? [];
    return courseId === undefined ? items : items.filter((item: LessonProgress): boolean => item.courseId === courseId);
  }

  static async completeLessonChunk(courseId: string, topic: string, chunkId: string,
    topicChunkCount: number): Promise<void> {
    const items = await LocalLearningRepository.getLessonProgress();
    const index = items.findIndex((item: LessonProgress): boolean => item.courseId === courseId && item.topic === topic);
    const now = new Date().toISOString();
    const item: LessonProgress = index >= 0 ? items[index] : {
      courseId: courseId,
      topic: topic,
      completedChunkIds: [],
      updatedAt: now
    };
    const wasCompleted = item.completedAt !== undefined;
    if (!item.completedChunkIds.includes(chunkId)) item.completedChunkIds.push(chunkId);
    item.updatedAt = now;
    if (topicChunkCount > 0 && item.completedChunkIds.length >= topicChunkCount) item.completedAt = now;
    if (index >= 0) items[index] = item;
    else items.push(item);
    await LocalLearningRepository.putValue<LessonProgress[]>(KEY_LESSON_PROGRESS, items);
    if (!wasCompleted && item.completedAt !== undefined) {
      await LocalLearningRepository.appendStudyEvent({
        id: 'lesson_' + courseId + '_' + topic,
        type: 'lesson_completed',
        timestamp: item.completedAt,
        courseId: courseId,
        topic: topic
      });
    }
  }

  static async getTopicMastery(courseId?: string): Promise<TopicMastery[]> {
    const results = await LocalLearningRepository.getQuizResults();
    const mastery: TopicMastery[] = [];
    for (const result of results.slice().reverse()) {
      if (courseId !== undefined && result.courseId !== courseId) continue;
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
    return mastery;
  }

  static async getTagInsights(limit: number = 6): Promise<TagInsight[]> {
    const results = await LocalLearningRepository.getQuizResults();
    return LocalLearningRepository.buildTagInsights(results, limit);
  }

  private static buildTagInsights(results: QuizResult[], limit: number): TagInsight[] {
    const insights: TagInsight[] = [];
    for (const result of results.slice().reverse()) {
      for (const detail of result.details) {
        const tags = detail.tags ?? [];
        for (const tag of tags) {
          const normalized = tag.trim();
          if (normalized.length === 0) continue;
          let item = insights.find((value: TagInsight): boolean => value.tag === normalized);
          if (item === undefined) {
            item = {
              tag: normalized,
              totalQuestions: 0,
              correctQuestions: 0,
              accuracy: 0,
              wrongQuestions: 0,
              lastPracticedAt: result.submittedAt
            };
            insights.push(item);
          }
          item.totalQuestions += 1;
          if (detail.isCorrect) item.correctQuestions += 1;
          item.wrongQuestions = item.totalQuestions - item.correctQuestions;
          item.accuracy = item.totalQuestions > 0 ? item.correctQuestions / item.totalQuestions : 0;
          item.lastPracticedAt = result.submittedAt;
        }
      }
    }
    return insights.sort((left: TagInsight, right: TagInsight): number => {
      const wrongDelta = right.wrongQuestions - left.wrongQuestions;
      if (wrongDelta !== 0) return wrongDelta;
      const totalDelta = right.totalQuestions - left.totalQuestions;
      if (totalDelta !== 0) return totalDelta;
      return left.accuracy - right.accuracy;
    }).slice(0, limit);
  }

  static async getChatHistory(): Promise<ChatMessage[]> {
    return (await LocalLearningRepository.getValue<ChatMessage[]>(KEY_CHAT_HISTORY)) ?? [];
  }

  static async saveChatHistory(history: ChatMessage[]): Promise<void> {
    await LocalLearningRepository.putValue<ChatMessage[]>(KEY_CHAT_HISTORY, history.slice(-24));
  }

  static async getStudyEvents(): Promise<StudyEvent[]> {
    return (await LocalLearningRepository.getValue<StudyEvent[]>(KEY_STUDY_EVENTS)) ?? [];
  }

  static async appendStudyEvent(event: StudyEvent): Promise<void> {
    const events = await LocalLearningRepository.getStudyEvents();
    events.push(event);
    await LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS, events.slice(-500));
  }

  static async getAchievements(): Promise<AchievementProgress[]> {
    const events = await LocalLearningRepository.getStudyEvents();
    const results = await LocalLearningRepository.getQuizResults();
    const completedTasks = LocalLearningRepository.uniqueEvents(events, 'task_completed', true);
    const masteredTopics = LocalLearningRepository.uniqueEvents(events, 'quiz_mastered', false);
    return [
      LocalLearningRepository.achievement('first_quiz', '初次练习', '完成第一次练习', results.length, 1,
        results.length > 0 ? results[results.length - 1].submittedAt : undefined),
      LocalLearningRepository.achievement('task_5', '稳步前进', '完成 5 项学习任务', completedTasks.length, 5,
        completedTasks.length >= 5 ? completedTasks[4].timestamp : undefined),
      LocalLearningRepository.achievement('mastery_3', '掌握新知', '掌握 3 个知识点', masteredTopics.length, 3,
        masteredTopics.length >= 3 ? masteredTopics[2].timestamp : undefined)
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

  private static addDays(timestamp: string, days: number): string {
    const date = new Date(timestamp);
    date.setDate(date.getDate() + days);
    return date.toISOString();
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
