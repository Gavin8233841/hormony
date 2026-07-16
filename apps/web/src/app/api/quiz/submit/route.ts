// POST /api/quiz/submit — 提交测验答案，自动评分 + 薄弱点分析

import { store } from "@/lib/store/db";
import { runEvaluatorAgent } from "@/lib/agents/evaluator-agent";
import { retrieve } from "@/lib/rag";
import type { QuizSubmission, QuizResult, QuizResultDetail } from "@/lib/types";
import { isJsonObject, readJsonObject } from "@/lib/request-json";
import { readUserId } from "@/lib/api-validation";
import { runSafetyAgent, validateUserInput } from "@/lib/agents/safety-agent";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  try {
    const parsed = await readJsonObject<QuizSubmission>(req);
    if (!parsed.ok) return parsed.response;
    const body = parsed.body;

    if (body.quizId !== undefined && typeof body.quizId !== "string") {
      return Response.json({ error: "quizId 必须是字符串", code: "INVALID_QUIZ_ID" }, { status: 400 });
    }
    const quizId = body.quizId?.trim() ?? "";
    const userId = readUserId(body.userId);
    if (!userId.ok) return userId.response;
    if (body.answers !== undefined && !Array.isArray(body.answers)) {
      return Response.json({ error: "answers 必须是数组", code: "INVALID_ANSWERS" }, { status: 400 });
    }
    const answers = body.answers ?? [];

    if (!quizId) {
      return Response.json({ error: "缺少 quizId 字段", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (quizId.length > 100) {
      return Response.json({ error: "quizId 长度不能超过 100 字符", code: "INVALID_QUIZ_ID" }, { status: 400 });
    }
    if (answers.length === 0) {
      return Response.json({ error: "答案不能为空", code: "EMPTY_ANSWERS" }, { status: 400 });
    }
    if (answers.length > 50) {
      return Response.json({ error: "答案数量超出上限（50 题）", code: "TOO_MANY_ANSWERS" }, { status: 400 });
    }
    if (!answers.every(isJsonObject)) {
      return Response.json(
        { error: "答案列表必须只包含对象", code: "INVALID_ANSWERS" },
        { status: 400 }
      );
    }
    for (const answer of answers) {
      if (typeof answer.questionId !== "string" || answer.questionId.trim().length === 0) {
        return Response.json(
          { error: "答案缺少 questionId", code: "INVALID_ANSWERS" },
          { status: 400 }
        );
      }
      if (answer.questionId.length > 100) {
        return Response.json(
          { error: "questionId 长度不能超过 100 字符", code: "INVALID_ANSWERS" },
          { status: 400 }
        );
      }
      if (typeof answer.userAnswer !== "string" || answer.userAnswer.length > 200) {
        return Response.json(
          { error: "答案内容必须是 200 字符以内字符串", code: "INVALID_ANSWERS" },
          { status: 400 }
        );
      }
    }
    if (
      validateUserInput([
        quizId,
        ...answers.flatMap((answer) => [answer.questionId, answer.userAnswer]),
      ].join("\n")).length > 0
    ) {
      return Response.json(
        { error: "答案内容不符合安全要求", code: "INPUT_REJECTED" },
        { status: 400 }
      );
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
        tags: question.tags && question.tags.length > 0 ? question.tags : [quiz.topic.slice(0, 12)],
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
      const evalResult = await runEvaluatorAgent(userId.value, evaluatorInput);
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
      userId: userId.value,
      totalQuestions,
      correctCount,
      accuracy,
      details,
      evaluation,
      weakTopics,
      submittedAt: new Date().toISOString(),
    };

    const outputSafety = await runSafetyAgent([
      result.evaluation,
      ...result.weakTopics,
      ...result.details.flatMap((detail) => [
        detail.stem,
        detail.userAnswer,
        detail.correctAnswer,
        detail.explanation,
        ...(detail.tags ?? []),
      ]),
    ].join("\n"), []);
    if (!outputSafety.passed) {
      return Response.json(
        { error: "评分结果未通过安全审核", code: "SAFETY_BLOCKED" },
        { status: 502 }
      );
    }

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
