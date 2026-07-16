import { describe, expect, it } from "vitest";
import type { QuizPackage } from "@/lib/types";
import {
  QuizPackageValidationError,
  parseQuizPackage,
  scoreQuizLocally,
} from "./local-scoring";

const quizPackage: QuizPackage = {
  quizId: "quiz-1",
  courseId: "cs101",
  topic: "二叉树与BST",
  questions: [
    {
      id: "q1",
      type: "choice",
      stem: "BST 中序遍历的结果是？",
      options: ["A. 降序", "B. 升序", "C. 随机", "D. 层序"],
      difficulty: "medium",
      tags: ["BST性质"],
    },
    {
      id: "q2",
      type: "short",
      stem: "根节点英文名？",
      tags: ["树结构"],
    },
  ],
  grading: [
    {
      questionId: "q1",
      answer: "B",
      explanation: "BST 的中序遍历为升序序列。",
      difficulty: "medium",
      tags: ["BST性质"],
    },
    {
      questionId: "q2",
      answer: "root",
      explanation: "根节点英文为 root。",
      tags: ["树结构"],
    },
  ],
};

describe("parseQuizPackage", () => {
  it("接受 questions/grading 一一对应的题组", () => {
    expect(parseQuizPackage(quizPackage)).toBe(quizPackage);
  });

  it("拒绝缺少 grading 或题目 ID 不匹配的响应", () => {
    expect(() => parseQuizPackage({ ...quizPackage, grading: undefined })).toThrow(
      QuizPackageValidationError,
    );
    expect(() => parseQuizPackage({
      ...quizPackage,
      grading: quizPackage.grading.map((item, index) => (
        index === 0 ? { ...item, questionId: "unknown" } : item
      )),
    })).toThrow(QuizPackageValidationError);
  });

  it("拒绝选项不是四项或评分答案不是 A-D 的选择题", () => {
    expect(() => parseQuizPackage({
      ...quizPackage,
      questions: quizPackage.questions.map((question, index) => (
        index === 0 ? { ...question, options: ["A. 一", "B. 二", "C. 三"] } : question
      )),
    })).toThrow(QuizPackageValidationError);
    expect(() => parseQuizPackage({
      ...quizPackage,
      grading: quizPackage.grading.map((item, index) => (
        index === 0 ? { ...item, answer: "Z" } : item
      )),
    })).toThrow(QuizPackageValidationError);
  });
});

describe("scoreQuizLocally", () => {
  it("使用独立 grading 数据评分选择题和简答题", () => {
    const result = scoreQuizLocally(
      quizPackage,
      { q1: "B. 升序", q2: "ROOT" },
      "demo",
      new Date("2026-07-17T08:00:00.000Z"),
    );

    expect(result.correctCount).toBe(2);
    expect(result.accuracy).toBe(1);
    expect(result.details[0]).toMatchObject({
      correctAnswer: "B. 升序",
      isCorrect: true,
      explanation: "BST 的中序遍历为升序序列。",
    });
    expect(result.evaluation).toBe("");
    expect(result.submittedAt).toBe("2026-07-17T08:00:00.000Z");
  });

  it("从答错题目的 grading 标签生成真实复习主题", () => {
    const result = scoreQuizLocally(quizPackage, { q1: "A. 降序", q2: "root" }, "demo");

    expect(result.correctCount).toBe(1);
    expect(result.weakTopics).toEqual(["BST性质"]);
    expect(result.details[0]).toMatchObject({ isCorrect: false, correctAnswer: "B. 升序" });
  });
});
