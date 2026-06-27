// POST /api/quiz/submit — 提交测验答案，自动评分 + 薄弱点分析

import { store } from "@/lib/store/db";
import { runEvaluatorAgent } from "@/lib/agents/evaluator-agent";
import { retrieve } from "@/lib/rag";
import { sanitizeUserId } from "@/lib/utils";
import type { QuizSubmission, QuizResult, QuizResultDetail } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
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

  // 评分
  const details: QuizResultDetail[] = [];
  let correctCount = 0;

  for (const ans of answers) {
    const question = quiz.questions.find((q) => q.id === String(ans.questionId ?? ""));
    if (!question) continue;

    const userAnswer = String(ans.userAnswer ?? "").trim();
    const isCorrect = userAnswer.toUpperCase() === question.answer.trim().toUpperCase();
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

    // 从错题中提取薄弱主题（基于检索匹配）
    const wrongQuestions = details.filter((d) => !d.isCorrect);
    if (wrongQuestions.length > 0) {
      const wrongTexts = wrongQuestions.map((d) => d.stem).join(" ");
      const relatedChunks = retrieve(wrongTexts, quiz.courseId, 3);
      weakTopics = relatedChunks
        .map((c) => c.source.replace(/\.pdf$|\.docx?$|\.txt$/i, ""))
        .filter((v, i, arr) => arr.indexOf(v) === i)
        .slice(0, 5);
    }
  } catch (err) {
    console.error("[quiz/submit] evaluator error:", err instanceof Error ? err.message : String(err));
    evaluation = `正确率：${(accuracy * 100).toFixed(0)}%（${correctCount}/${totalQuestions}）。评估服务暂不可用。`;
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
}
