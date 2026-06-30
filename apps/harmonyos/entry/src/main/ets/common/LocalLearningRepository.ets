import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  ChatMessage,
  Course,
  QuizResult,
  StudyPlan,
  UserProfile
} from '../model/DataModels';

const STORE_NAME: string = 'hongxueban_learning.db';
const TABLE_NAME: string = 'app_state';
const SCHEMA_VERSION: number = 1;

const KEY_PROFILE: string = 'profile';
const KEY_COURSES: string = 'courses';
const KEY_PLAN: string = 'plan';
const KEY_QUIZ_RESULTS: string = 'quiz_results';
const KEY_CHAT_HISTORY: string = 'chat_history';

export class LocalLearningRepository {
  private static store: relationalStore.RdbStore | null = null;

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
    await LocalLearningRepository.putValue<number>('schema_version', SCHEMA_VERSION);
    await LocalLearningRepository.ensureDefaults();
  }

  private static async ensureDefaults(): Promise<void> {
    if ((await LocalLearningRepository.getProfile()) === null) {
      const profile: UserProfile = {
        userId: 'demo',
        name: '演示同学',
        stage: '本科二年级',
        weakTopics: ['树与图', '动态规划', '操作系统调度'],
        strongTopics: ['数组', '链表', '基础语法'],
        learningStyle: '视觉型',
        stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 }
      };
      await LocalLearningRepository.saveProfile(profile);
    }
    if ((await LocalLearningRepository.getCourses()) === null) {
      const courses: Course[] = [
        { id: 'cs101', title: '数据结构', progress: 0.65, docCount: 52, topics: ['二叉树', '图的遍历', '动态规划'] },
        { id: 'cs102', title: '操作系统', progress: 0.42, docCount: 48, topics: ['进程调度', '内存管理', '文件系统'] },
        { id: 'cs103', title: '计算机网络', progress: 0.30, docCount: 47, topics: ['TCP/IP', 'HTTP', '路由协议'] }
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

  static async getProfile(): Promise<UserProfile | null> {
    return LocalLearningRepository.getValue<UserProfile>(KEY_PROFILE);
  }

  static async saveProfile(profile: UserProfile): Promise<void> {
    await LocalLearningRepository.putValue<UserProfile>(KEY_PROFILE, profile);
  }

  static async getCourses(): Promise<Course[] | null> {
    return LocalLearningRepository.getValue<Course[]>(KEY_COURSES);
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

  static async getQuizResults(): Promise<QuizResult[]> {
    return (await LocalLearningRepository.getValue<QuizResult[]>(KEY_QUIZ_RESULTS)) ?? [];
  }

  static async appendQuizResult(result: QuizResult): Promise<void> {
    const results = await LocalLearningRepository.getQuizResults();
    results.unshift(result);
    await LocalLearningRepository.putValue<QuizResult[]>(KEY_QUIZ_RESULTS, results.slice(0, 20));
  }

  static async getChatHistory(): Promise<ChatMessage[]> {
    return (await LocalLearningRepository.getValue<ChatMessage[]>(KEY_CHAT_HISTORY)) ?? [];
  }

  static async saveChatHistory(history: ChatMessage[]): Promise<void> {
    await LocalLearningRepository.putValue<ChatMessage[]>(KEY_CHAT_HISTORY, history.slice(-24));
  }
}
