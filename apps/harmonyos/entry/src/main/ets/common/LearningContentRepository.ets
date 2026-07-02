import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import {
  CuratedKnowledgeChunk,
  CuratedQuestion,
  ExternalLearningResource,
  LessonExperience,
  TopicRelation
} from '../model/DataModels';

const KNOWLEDGE_PATH: string = 'learning/knowledge-chunks.json';
const QUIZZES_PATH: string = 'learning/quizzes.json';
const RESOURCES_PATH: string = 'learning/external-resources.json';
const TOPIC_RELATIONS_PATH: string = 'learning/topic-relations.json';
const LESSON_EXPERIENCES_PATH: string = 'learning/lesson-experiences.json';

interface CourseListIndex<T> {
  courseId: string;
  items: T[];
}

interface TopicListIndex<T> {
  courseId: string;
  topic: string;
  items: T[];
}

interface TopicNameIndex {
  courseId: string;
  topics: string[];
}

interface LessonExperienceIndex {
  courseId: string;
  topic: string;
  item: LessonExperience;
}

export class LearningContentRepository {
  private static manager: resourceManager.ResourceManager | null = null;
  private static knowledge: CuratedKnowledgeChunk[] = [];
  private static questions: CuratedQuestion[] = [];
  private static resources: ExternalLearningResource[] = [];
  private static topicRelations: TopicRelation[] = [];
  private static lessonExperiences: LessonExperience[] = [];
  private static knowledgeByCourse: CourseListIndex<CuratedKnowledgeChunk>[] = [];
  private static knowledgeByTopic: TopicListIndex<CuratedKnowledgeChunk>[] = [];
  private static questionsByCourse: CourseListIndex<CuratedQuestion>[] = [];
  private static questionsByTopic: TopicListIndex<CuratedQuestion>[] = [];
  private static resourcesByCourse: CourseListIndex<ExternalLearningResource>[] = [];
  private static topicsByCourse: TopicNameIndex[] = [];
  private static relationsByCourse: CourseListIndex<TopicRelation>[] = [];
  private static lessonExperienceByTopic: LessonExperienceIndex[] = [];

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
    LearningContentRepository.buildIndexes();
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

  private static buildIndexes(): void {
    LearningContentRepository.knowledgeByCourse = [];
    LearningContentRepository.knowledgeByTopic = [];
    LearningContentRepository.questionsByCourse = [];
    LearningContentRepository.questionsByTopic = [];
    LearningContentRepository.resourcesByCourse = [];
    LearningContentRepository.topicsByCourse = [];
    LearningContentRepository.relationsByCourse = [];
    LearningContentRepository.lessonExperienceByTopic = [];

    for (const item of LearningContentRepository.knowledge) {
      LearningContentRepository.appendCourseItem(
        LearningContentRepository.knowledgeByCourse,
        item.courseId,
        item
      );
      LearningContentRepository.appendTopicItem(
        LearningContentRepository.knowledgeByTopic,
        item.courseId,
        item.topic,
        item
      );
      LearningContentRepository.appendTopicName(item.courseId, item.topic);
    }

    for (const item of LearningContentRepository.questions) {
      LearningContentRepository.appendCourseItem(
        LearningContentRepository.questionsByCourse,
        item.courseId,
        item
      );
      LearningContentRepository.appendTopicItem(
        LearningContentRepository.questionsByTopic,
        item.courseId,
        item.topic,
        item
      );
    }

    for (const item of LearningContentRepository.resources) {
      LearningContentRepository.appendCourseItem(
        LearningContentRepository.resourcesByCourse,
        item.courseId,
        item
      );
    }

    for (const item of LearningContentRepository.topicRelations) {
      LearningContentRepository.appendCourseItem(
        LearningContentRepository.relationsByCourse,
        item.courseId,
        item
      );
    }

    for (const item of LearningContentRepository.lessonExperiences) {
      LearningContentRepository.lessonExperienceByTopic.push({
        courseId: item.courseId,
        topic: item.topic,
        item
      });
    }
  }

  private static appendCourseItem<T>(index: CourseListIndex<T>[], courseId: string, item: T): void {
    const bucket = index.find((entry: CourseListIndex<T>): boolean => entry.courseId === courseId);
    if (bucket !== undefined) {
      bucket.items.push(item);
      return;
    }
    index.push({ courseId, items: [item] });
  }

  private static appendTopicItem<T>(index: TopicListIndex<T>[], courseId: string, topic: string, item: T): void {
    const bucket = index.find((entry: TopicListIndex<T>): boolean =>
      entry.courseId === courseId && entry.topic === topic);
    if (bucket !== undefined) {
      bucket.items.push(item);
      return;
    }
    index.push({ courseId, topic, items: [item] });
  }

  private static appendTopicName(courseId: string, topic: string): void {
    const bucket = LearningContentRepository.topicsByCourse.find((entry: TopicNameIndex): boolean =>
      entry.courseId === courseId);
    if (bucket !== undefined) {
      if (!bucket.topics.includes(topic)) bucket.topics.push(topic);
      return;
    }
    LearningContentRepository.topicsByCourse.push({ courseId, topics: [topic] });
  }

  private static findCourseItems<T>(index: CourseListIndex<T>[], courseId: string): T[] {
    const bucket = index.find((entry: CourseListIndex<T>): boolean => entry.courseId === courseId);
    return bucket === undefined ? [] : bucket.items.slice();
  }

  private static findTopicItems<T>(index: TopicListIndex<T>[], courseId: string, topic: string): T[] {
    const bucket = index.find((entry: TopicListIndex<T>): boolean =>
      entry.courseId === courseId && entry.topic === topic);
    return bucket === undefined ? [] : bucket.items.slice();
  }

  static getKnowledge(courseId: string, topic?: string): CuratedKnowledgeChunk[] {
    if (topic !== undefined && topic.length > 0) {
      return LearningContentRepository.findTopicItems(
        LearningContentRepository.knowledgeByTopic,
        courseId,
        topic
      );
    }
    return LearningContentRepository.findCourseItems(LearningContentRepository.knowledgeByCourse, courseId);
  }

  static getQuestions(courseId: string, topic?: string): CuratedQuestion[] {
    if (topic !== undefined && topic.length > 0) {
      return LearningContentRepository.findTopicItems(
        LearningContentRepository.questionsByTopic,
        courseId,
        topic
      );
    }
    return LearningContentRepository.findCourseItems(LearningContentRepository.questionsByCourse, courseId);
  }

  static getResources(courseId: string): ExternalLearningResource[] {
    return LearningContentRepository.findCourseItems(LearningContentRepository.resourcesByCourse, courseId);
  }

  static getTopics(courseId: string): string[] {
    const bucket = LearningContentRepository.topicsByCourse.find((entry: TopicNameIndex): boolean =>
      entry.courseId === courseId);
    return bucket === undefined ? [] : bucket.topics.slice();
  }

  static getTopicRelations(courseId: string): TopicRelation[] {
    return LearningContentRepository.findCourseItems(LearningContentRepository.relationsByCourse, courseId);
  }

  static getLessonExperience(courseId: string, topic: string): LessonExperience | null {
    const bucket = LearningContentRepository.lessonExperienceByTopic.find((entry: LessonExperienceIndex): boolean =>
      entry.courseId === courseId && entry.topic === topic);
    return bucket === undefined ? null : bucket.item;
  }
}
