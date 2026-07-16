import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import type { QuizQuestion } from "@/lib/types";
import {
  COURSE_IDS,
  EXTERNAL_RESOURCE_TYPES,
  allKnowledgeChunks,
  allQuizzes,
  externalResources,
} from "@/lib/data";
import { balanceChoiceOptions } from "./quizzes";

const MINIMUM_COUNTS = {
  cs101: { chunks: 40, questions: 20, choices: 20 },
  cs102: { chunks: 40, questions: 20, choices: 20 },
  cs103: { chunks: 40, questions: 20, choices: 20 },
};

const ANSWER_LABELS = ["A", "B", "C", "D"] as const;
const QUIZ_DIFFICULTIES = ["easy", "medium", "hard"] as const;

type AnswerLabel = typeof ANSWER_LABELS[number];
type QuizDifficulty = typeof QUIZ_DIFFICULTIES[number];

interface RawQuizQuestion {
  id: string;
  courseId: string;
  topic: string;
  question: string;
  options?: string[];
  answer: string;
  explanation: string;
  difficulty: string;
  tags: string[];
}

interface TopicRelation {
  courseId: string;
  topic: string;
}

const harmonyResourceUrl = (fileName: string) =>
  new URL(
    `../../../../harmonyos/entry/src/main/resources/rawfile/learning/${fileName}`,
    import.meta.url
  );

const rawQuizQuestions = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("quizzes.json")), "utf8")
) as RawQuizQuestion[];

const topicRelations = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("topic-relations.json")), "utf8")
) as TopicRelation[];

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
        expect(["easy", "medium", "hard"]).toContain(question.difficulty);
        expect(question.tags?.length ?? 0).toBeGreaterThan(0);
        question.tags?.forEach((tag) => {
          expect(tag.trim().length).toBeGreaterThan(0);
          expect(tag.length).toBeLessThanOrEqual(12);
        });

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

  it("选项轮换应保持正确答案正文和选项正文集合不变", () => {
    const sourceQuestion: QuizQuestion = {
      id: "rotation_fixture",
      type: "choice",
      stem: "固定轮换输入",
      options: ["A. alpha", "B. beta", "C. gamma", "D. delta"],
      answer: "B",
      explanation: "beta 是固定正确答案。轮换只能改变位置标签，不能改变任何选项正文。",
    };
    const sourceSnapshot = structuredClone(sourceQuestion);
    const sourceBodies = sourceQuestion.options?.map((option) => option.slice(3)) ?? [];
    const correctBody = sourceBodies[1];

    ANSWER_LABELS.forEach((answer, targetIndex) => {
      const rotated = balanceChoiceOptions(sourceQuestion, targetIndex);
      const rotatedBodies = rotated.options?.map((option) => option.slice(3)) ?? [];
      const answerIndex = ANSWER_LABELS.indexOf(rotated.answer as AnswerLabel);

      expect(rotated.answer).toBe(answer);
      expect(rotatedBodies[answerIndex]).toBe(correctBody);
      expect(rotatedBodies.slice().sort()).toEqual(sourceBodies.slice().sort());
      expect(rotated.stem).toBe(sourceQuestion.stem);
      expect(rotated.explanation).toBe(sourceQuestion.explanation);
    });

    expect(sourceQuestion).toEqual(sourceSnapshot);
  });

  it("选择题答案位置应均衡且全局难度分布应受控", () => {
    const choices = allQuizzes.flatMap((quiz) =>
      quiz.questions
        .filter((question) => question.type === "choice")
        .map((question) => ({ courseId: quiz.courseId, question }))
    );
    expect(choices).toHaveLength(165);
    expect(allQuizzes).toHaveLength(33);

    const answerCounts: Record<AnswerLabel, number> = { A: 0, B: 0, C: 0, D: 0 };
    const globalDifficultyCounts: Record<QuizDifficulty, number> = { easy: 0, medium: 0, hard: 0 };
    for (const { question } of choices) {
      answerCounts[question.answer as AnswerLabel] += 1;
      globalDifficultyCounts[question.difficulty as QuizDifficulty] += 1;
    }
    const globalAnswerCounts = Object.values(answerCounts);
    expect(Math.max(...globalAnswerCounts) - Math.min(...globalAnswerCounts))
      .toBeLessThanOrEqual(10);
    for (const count of globalAnswerCounts) {
      expect(count / choices.length).toBeGreaterThanOrEqual(0.2);
      expect(count / choices.length).toBeLessThanOrEqual(0.3);
    }
    expect(globalDifficultyCounts.easy / choices.length).toBeGreaterThanOrEqual(0.4);
    expect(globalDifficultyCounts.easy / choices.length).toBeLessThanOrEqual(0.5);
    expect(globalDifficultyCounts.medium / choices.length).toBeGreaterThanOrEqual(0.35);
    expect(globalDifficultyCounts.medium / choices.length).toBeLessThanOrEqual(0.45);
    expect(globalDifficultyCounts.hard / choices.length).toBeGreaterThanOrEqual(0.1);
    expect(globalDifficultyCounts.hard / choices.length).toBeLessThanOrEqual(0.2);

    for (const quiz of allQuizzes) {
      const topicChoices = quiz.questions.filter((question) => question.type === "choice");
      const topicAnswerCounts: Record<AnswerLabel, number> = { A: 0, B: 0, C: 0, D: 0 };
      expect(topicChoices).toHaveLength(5);

      for (const question of topicChoices) {
        topicAnswerCounts[question.answer as AnswerLabel] += 1;
      }
      for (const answer of ANSWER_LABELS) {
        expect(topicAnswerCounts[answer]).toBeGreaterThanOrEqual(1);
        expect(topicAnswerCounts[answer]).toBeLessThanOrEqual(2);
      }
    }

    for (const courseId of COURSE_IDS) {
      const courseQuestions = choices
        .filter((entry) => entry.courseId === courseId)
        .map((entry) => entry.question);
      const courseAnswerCounts: Record<AnswerLabel, number> = { A: 0, B: 0, C: 0, D: 0 };

      for (const question of courseQuestions) {
        courseAnswerCounts[question.answer as AnswerLabel] += 1;
      }

      const answerPositions = Object.values(courseAnswerCounts);
      expect(Math.max(...answerPositions) - Math.min(...answerPositions))
        .toBeLessThanOrEqual(5);
    }
  });

  it("Web 与 HarmonyOS 题库应同源并完整覆盖 33 个 Topic", () => {
    const webQuestions: RawQuizQuestion[] = allQuizzes.flatMap((quiz) =>
      quiz.questions
        .filter((q) => q.type === "choice")
        .map((question) => ({
          id: question.id,
          courseId: quiz.courseId,
          topic: quiz.topic,
          question: question.stem,
          ...(question.options ? { options: question.options } : {}),
          answer: question.answer,
          explanation: question.explanation,
          difficulty: question.difficulty ?? "",
          tags: question.tags ?? [],
        }))
    );

    expect(rawQuizQuestions).toEqual(webQuestions);

    const relationTopics = topicRelations.map(
      (relation) => `${relation.courseId}:${relation.topic}`
    ).sort();
    const rawTopics = Array.from(new Set(rawQuizQuestions.map(
      (question) => `${question.courseId}:${question.topic}`
    ))).sort();
    const webTopics = Array.from(new Set(webQuestions.map(
      (question) => `${question.courseId}:${question.topic}`
    ))).sort();

    expect(rawTopics).toEqual(relationTopics);
    expect(webTopics).toEqual(relationTopics);

    for (const relation of topicRelations) {
      const topicQuestions = webQuestions.filter(
        (question) =>
          question.courseId === relation.courseId &&
          question.topic === relation.topic
      );
      const choiceQuestions = topicQuestions.filter(
        (question) => question.options?.length === 4
      );
      expect(choiceQuestions.length).toBe(5);

      for (const question of choiceQuestions) {
        expect(question.options).toHaveLength(4);
        question.options?.forEach((option, index) => {
          expect(option).toMatch(new RegExp(`^${String.fromCharCode(65 + index)}\\.`));
        });
        expect(["A", "B", "C", "D"]).toContain(question.answer);
        expect(["easy", "medium", "hard"]).toContain(question.difficulty);
        expect(question.tags.length).toBeGreaterThan(0);
        expect(question.explanation.match(/[^。！？.!?]+[。！？.!?]/g)?.length ?? 0)
          .toBeGreaterThanOrEqual(2);
      }
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
