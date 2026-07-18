// 数据资产桶导出
// 汇总所有课程的知识切片、题库题目和外部资源索引
// 供 db.ts 种子数据和 quiz-agent 回退使用

export { cs101KnowledgeChunks } from "./cs101-knowledge";
export { cs102KnowledgeChunks } from "./cs102-knowledge";
export { cs103KnowledgeChunks } from "./cs103-knowledge";
export { cs101Quizzes, cs102Quizzes, cs103Quizzes } from "./quizzes";
export { courseCatalog } from "./course-catalog";
export type { CourseId } from "./course-catalog";
export {
  accountingExternalResources,
  accountingKnowledgeChunks,
  accountingLessonExperiences,
  accountingQuizzes,
  accountingTopicRelations,
} from "./accounting";

import { cs101KnowledgeChunks } from "./cs101-knowledge";
import { cs102KnowledgeChunks } from "./cs102-knowledge";
import { cs103KnowledgeChunks } from "./cs103-knowledge";
import { cs101Quizzes, cs102Quizzes, cs103Quizzes } from "./quizzes";
import { externalResources as computerScienceExternalResources } from "./external-resources";
import { courseCatalog } from "./course-catalog";
import type { CourseId } from "./course-catalog";
import {
  accountingExternalResources,
  accountingKnowledgeChunks,
  accountingQuizzes,
} from "./accounting";

export const COURSE_IDS: readonly CourseId[] = courseCatalog.map((course) => course.id);
export const EXTERNAL_RESOURCE_TYPES = [
  "textbook",
  "documentation",
  "course",
  "standard",
  "tool",
] as const;

export function isCourseId(value: string): boolean {
  return COURSE_IDS.some((courseId) => courseId === value);
}

export function isExternalResourceType(
  value: string
): value is (typeof EXTERNAL_RESOURCE_TYPES)[number] {
  return EXTERNAL_RESOURCE_TYPES.some((type) => type === value);
}

// 全部知识切片（147条）
export const allKnowledgeChunks = [
  ...cs101KnowledgeChunks,
  ...cs102KnowledgeChunks,
  ...cs103KnowledgeChunks,
  ...accountingKnowledgeChunks,
];

// 全部题库（33个Quiz对象，186道题目）
export const allQuizzes = [
  ...cs101Quizzes,
  ...cs102Quizzes,
  ...cs103Quizzes,
  ...accountingQuizzes,
];

export const externalResources = [
  ...computerScienceExternalResources,
  ...accountingExternalResources,
];

// 按课程ID获取题库
export function getQuizzesByCourse(courseId: string) {
  return allQuizzes.filter((quiz) => quiz.courseId === courseId);
}

export function isCourseTopic(courseId: string, topic: string): boolean {
  return getQuizzesByCourse(courseId).some((quiz) => quiz.topic === topic);
}
