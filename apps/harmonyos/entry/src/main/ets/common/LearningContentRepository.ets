import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import {
  CuratedKnowledgeChunk,
  ExternalLearningResource,
  LessonExperience,
  TopicRelation
} from '../model/DataModels';
import { LearningCuratedQuestion as CuratedQuestion } from '../model/LearningMetadataModels';

const KNOWLEDGE_PATH: string = 'learning/knowledge-chunks.json';
const QUIZZES_PATH: string = 'learning/quizzes.json';
const RESOURCES_PATH: string = 'learning/external-resources.json';
const TOPIC_RELATIONS_PATH: string = 'learning/topic-relations.json';
const LESSON_EXPERIENCES_PATH: string = 'learning/lesson-experiences.json';

export class LearningContentRepository {
  private static manager: resourceManager.ResourceManager | null = null;
  private static knowledge: CuratedKnowledgeChunk[] = [];
  private static questions: CuratedQuestion[] = [];
  private static resources: ExternalLearningResource[] = [];
  private static topicRelations: TopicRelation[] = [];
  private static lessonExperiences: LessonExperience[] = [];

  static async initialize(manager: resourceManager.ResourceManager): Promise<void> {
    if (LearningContentRepository.manager !== null) return;
    LearningContentRepository.manager = manager;
    LearningContentRepository.knowledge = await LearningContentRepository.readJson<CuratedKnowledgeChunk[]>(KNOWLEDGE_PATH);
    LearningContentRepository.questions = await LearningContentRepository.readJson<CuratedQuestion[]>(QUIZZES_PATH);
    LearningContentRepository.resources = await LearningContentRepository.readJson<ExternalLearningResource[]>(RESOURCES_PATH);
    LearningContentRepository.topicRelations =
      await LearningContentRepository.readJson<TopicRelation[]>(TOPIC_RELATIONS_PATH);
    LearningContentRepository.lessonExperiences =
      await LearningContentRepository.readJson<LessonExperience[]>(LESSON_EXPERIENCES_PATH);
  }

  private static async readJson<T>(path: string): Promise<T> {
    if (LearningContentRepository.manager === null) {
      throw new Error('LearningContentRepository 尚未初始化');
    }
    try {
      const bytes = await LearningContentRepository.manager.getRawFileContent(path);
      const decoder = util.TextDecoder.create('utf-8');
      const value: T = JSON.parse(decoder.decodeToString(bytes));
      return value;
    } catch (error) {
      throw new Error('课程内容资产读取失败: ' + path + '，' + String(error));
    }
  }

  static getKnowledge(courseId: string, topic?: string): CuratedKnowledgeChunk[] {
    return LearningContentRepository.knowledge.filter((item: CuratedKnowledgeChunk): boolean => {
      return item.courseId === courseId && (topic === undefined || topic.length === 0 || item.topic === topic);
    });
  }

  static getQuestions(courseId: string, topic?: string): CuratedQuestion[] {
    return LearningContentRepository.questions.filter((item: CuratedQuestion): boolean => {
      return item.courseId === courseId && (topic === undefined || topic.length === 0 || item.topic === topic);
    });
  }

  static getResources(courseId: string): ExternalLearningResource[] {
    return LearningContentRepository.resources.filter((item: ExternalLearningResource): boolean => {
      return item.courseId === courseId;
    });
  }

  static getTopics(courseId: string): string[] {
    const topics: string[] = [];
    for (const item of LearningContentRepository.knowledge) {
      if (item.courseId === courseId && !topics.includes(item.topic)) topics.push(item.topic);
    }
    return topics;
  }

  static getTopicRelations(courseId: string): TopicRelation[] {
    return LearningContentRepository.topicRelations.filter((item: TopicRelation): boolean => item.courseId === courseId);
  }

  static getLessonExperience(courseId: string, topic: string): LessonExperience | null {
    return LearningContentRepository.lessonExperiences.find((item: LessonExperience): boolean =>
      item.courseId === courseId && item.topic === topic) ?? null;
  }
}
