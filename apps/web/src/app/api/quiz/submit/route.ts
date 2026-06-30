// POST /api/quiz/submit — 提交测验答案，自动评分 + 薄弱点分析

import { store } from "@/lib/store/db";
import { runEvaluatorAgent } from "@/lib/agents/evaluator-agent";
import { retrieve } from "@/lib/rag";
import { sanitizeUserId } from "@/lib/utils";
import type { QuizSubmission, QuizResult, QuizResultDetail } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  try {
    let body: QuizSubmission;
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
    }

    const quizId = String(body.quizId ?? "").trim();
    const userId = sanitizeUserId(body.userId);
    const answers = Array.isArray(body.answers) ? body.answers : [];

    if (!quizId) {
      return Response.json({ error: "缺少 quizId 字段", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (answers.length === 0) {
      return Response.json({ error: "答案不能为空", code: "EMPTY_ANSWERS" }, { status: 400 });
    }
    if (answers.length > 50) {
      return Response.json({ error: "答案数量超出上限（50 题）", code: "TOO_MANY_ANSWERS" }, { status: 400 });
    }

    const quiz = store.getQuiz(quizId);
    if (!quiz) {
      return Response.json({ error: "测验不存在或已过期", code: "QUIZ_NOT_FOUND" }, { status: 404 });
    }

    // 评分：始终覆盖整份测验，缺失答案按未作答处理。
    const details: QuizResultDetail[] = [];
    let correctCount = 0;
    const answerMap = new Map(
      answers.map((answer) => [String(answer.questionId ?? ""), String(answer.userAnswer ?? "")])
    );

    for (const question of quiz.questions) {
      const userAnswer = (answerMap.get(question.id) ?? "").trim();
      const isCorrect = answersMatch(question, userAnswer);
      if (isCorrect) correctCount++;

      details.push({
        questionId: question.id,
        stem: question.stem,
        userAnswer,
        correctAnswer: question.answer,
        isCorrect,
        explanation: question.explanation,
      });
    }

    const totalQuestions = details.length;
    const accuracy = totalQuestions > 0 ? correctCount / totalQuestions : 0;

    // 调用评估 Agent 生成诊断报告
    const evaluatorInput = details.map((d) => ({
      question: d.stem,
      userAnswer: d.userAnswer,
      correctAnswer: d.correctAnswer,
    }));

    let evaluation = "";
    let weakTopics: string[] = [];
    try {
      const evalResult = await runEvaluatorAgent(userId, evaluatorInput);
      evaluation = evalResult.content;
    } catch (err) {
      console.error("[quiz/submit] evaluator error:", err instanceof Error ? err.message : String(err));
      evaluation = `正确率：${(accuracy * 100).toFixed(0)}%（${correctCount}/${totalQuestions}）。评估服务暂不可用。`;
    }

    // 薄弱主题来自本地知识库，不依赖模型评估服务是否可用。
    const wrongQuestions = details.filter((detail) => !detail.isCorrect);
    if (wrongQuestions.length > 0) {
      const wrongTexts = wrongQuestions.map((detail) => detail.stem).join(" ");
      const relatedChunks = retrieve(wrongTexts, quiz.courseId, 3);
      weakTopics = relatedChunks
        .map((chunk) =>
          chunk.topic ?? chunk.source.replace(/\.pdf$|\.docx?$|\.txt$/i, "")
        )
        .filter((value, index, values) => values.indexOf(value) === index)
        .slice(0, 5);
    }

    const result: QuizResult = {
      quizId,
      userId,
      totalQuestions,
      correctCount,
      accuracy,
      details,
      evaluation,
      weakTopics,
      submittedAt: new Date().toISOString(),
    };

    // 持久化结果
    store.recordQuizResult(result);

    return Response.json(result);
  } catch (err) {
    console.error("[quiz/submit] unhandled error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "服务器内部错误", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

function answersMatch(
  question: { type: "choice" | "short"; options?: string[]; answer: string },
  userAnswer: string
): boolean {
  const expected = question.answer.trim();
  if (question.type === "choice" && question.options) {
    const selectedIndex = question.options.indexOf(userAnswer);
    const selectedKey = selectedIndex >= 0
      ? String.fromCharCode("A".charCodeAt(0) + selectedIndex)
      : userAnswer;
    const expectedIndex = question.options.indexOf(expected);
    const expectedKey = expectedIndex >= 0
      ? String.fromCharCode("A".charCodeAt(0) + expectedIndex)
      : expected;
    return selectedKey.toUpperCase() === expectedKey.toUpperCase();
  }
  return userAnswer.toLocaleLowerCase() === expected.toLocaleLowerCase();
}
