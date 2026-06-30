// 数据资产桶导出
// 汇总所有课程的知识切片、题库题目和外部资源索引
// 供 db.ts 种子数据和 quiz-agent 回退使用

export { cs101KnowledgeChunks } from "./cs101-knowledge";
export { cs102KnowledgeChunks } from "./cs102-knowledge";
export { cs103KnowledgeChunks } from "./cs103-knowledge";
export { cs101Quizzes, cs102Quizzes, cs103Quizzes } from "./quizzes";
export { externalResources } from "./external-resources";

import { cs101KnowledgeChunks } from "./cs101-knowledge";
import { cs102KnowledgeChunks } from "./cs102-knowledge";
import { cs103KnowledgeChunks } from "./cs103-knowledge";
import { cs101Quizzes, cs102Quizzes, cs103Quizzes } from "./quizzes";
import { externalResources } from "./external-resources";

export const COURSE_IDS = ["cs101", "cs102", "cs103"] as const;
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
];

// 全部题库（25个Quiz对象，70道题目）
export const allQuizzes = [
  ...cs101Quizzes,
  ...cs102Quizzes,
  ...cs103Quizzes,
];

// 按课程ID获取题库
export function getQuizzesByCourse(courseId: string) {
  switch (courseId) {
    case "cs101":
      return cs101Quizzes;
    case "cs102":
      return cs102Quizzes;
    case "cs103":
      return cs103Quizzes;
    default:
      return [];
  }
}
