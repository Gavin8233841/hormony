import { describe, expect, it } from "vitest";
import {
  COURSE_IDS,
  EXTERNAL_RESOURCE_TYPES,
  allKnowledgeChunks,
  allQuizzes,
  externalResources,
} from "@/lib/data";

const MINIMUM_COUNTS = {
  cs101: { chunks: 40, questions: 20, choices: 20 },
  cs102: { chunks: 40, questions: 20, choices: 20 },
  cs103: { chunks: 40, questions: 20, choices: 20 },
};

describe("课程数据资产完整性", () => {
  it("知识切片应满足课程覆盖、长度和唯一性约束", () => {
    const ids = new Set<string>();

    for (const chunk of allKnowledgeChunks) {
      expect(ids.has(chunk.id)).toBe(false);
      ids.add(chunk.id);
      expect(COURSE_IDS).toContain(chunk.courseId);
      expect(chunk.topic?.trim().length).toBeGreaterThan(0);
      expect(chunk.source.trim().length).toBeGreaterThan(0);
      expect(chunk.text.trim().length).toBeGreaterThanOrEqual(100);
    }

    for (const courseId of COURSE_IDS) {
      const count = allKnowledgeChunks.filter(
        (chunk) => chunk.courseId === courseId
      ).length;
      expect(count).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].chunks);
    }
  });

  it("题库应满足课程题量、题目唯一性和答案约束", () => {
    const quizIds = new Set<string>();
    const questionIds = new Set<string>();
    const stems = new Set<string>();

    for (const quiz of allQuizzes) {
      expect(quizIds.has(quiz.quizId)).toBe(false);
      quizIds.add(quiz.quizId);
      expect(COURSE_IDS).toContain(quiz.courseId);
      expect(quiz.topic.trim().length).toBeGreaterThan(0);

      for (const question of quiz.questions) {
        expect(questionIds.has(question.id)).toBe(false);
        questionIds.add(question.id);
        expect(question.stem.trim().length).toBeGreaterThan(0);
        // 题干全局唯一
        const stemKey = question.stem.trim();
        expect(stems.has(stemKey)).toBe(false);
        stems.add(stemKey);
        expect(question.answer.trim().length).toBeGreaterThan(0);
        expect(question.explanation.trim().length).toBeGreaterThan(0);

        if (question.type === "choice") {
          expect(question.options).toHaveLength(4);
          expect(["A", "B", "C", "D"]).toContain(question.answer);
          const answerIndex = question.answer.charCodeAt(0) - "A".charCodeAt(0);
          expect(question.options?.[answerIndex]).toMatch(
            new RegExp(`^${question.answer}\\.`)
          );
        }
      }
    }

    for (const courseId of COURSE_IDS) {
      const count = allQuizzes
        .filter((quiz) => quiz.courseId === courseId)
        .reduce((sum, quiz) => sum + quiz.questions.length, 0);
      expect(count).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].questions);
    }
  });

  it("每门课程选择题数量应不少于 20 道", () => {
    for (const courseId of COURSE_IDS) {
      const choiceCount = allQuizzes
        .filter((quiz) => quiz.courseId === courseId)
        .flatMap((quiz) => quiz.questions)
        .filter((question) => question.type === "choice").length;
      expect(choiceCount).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].choices);
    }
  });

  it("外部资源应使用受支持类型、HTTPS 地址和有效课程关联", () => {
    const ids = new Set<string>();
    const titles = new Set<string>();
    const urls = new Set<string>();

    for (const resource of externalResources) {
      expect(ids.has(resource.id)).toBe(false);
      ids.add(resource.id);
      // 标题全局唯一
      const titleKey = resource.title.trim();
      expect(titles.has(titleKey)).toBe(false);
      titles.add(titleKey);
      // URL 全局唯一
      const urlKey = resource.url.trim();
      expect(urls.has(urlKey)).toBe(false);
      urls.add(urlKey);
      expect(EXTERNAL_RESOURCE_TYPES).toContain(resource.type);
      expect(new URL(resource.url).protocol).toBe("https:");
      expect(resource.description.trim().length).toBeGreaterThanOrEqual(30);
      expect(resource.tags.length).toBeGreaterThan(0);
      if (resource.courseId) {
        expect(COURSE_IDS).toContain(resource.courseId);
      }
    }

    for (const type of EXTERNAL_RESOURCE_TYPES) {
      expect(externalResources.some((resource) => resource.type === type)).toBe(true);
    }
  });
});
