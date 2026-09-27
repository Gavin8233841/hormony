// Evaluator Agent：错题分析、薄弱点诊断与学习建议
// 支持两种模式：基于答题记录分析 / 基于用户画像分析

import { callModel } from "./model";
import { retrieve } from "@/lib/rag";
import type { AgentResult, Citation, LearningProfileSnapshot } from "@/lib/types";

interface AnswerRecord {
  question: string;
  userAnswer: string;
  correctAnswer: string;
}

export async function runEvaluatorAgent(
  answers: AnswerRecord[],
  profile?: LearningProfileSnapshot,
  signal?: AbortSignal,
  courseId?: string,
  studentQuestion?: string
): Promise<AgentResult> {
  // 模式 1：有答题记录 → 针对实际作答反馈
  if (answers.length > 0) {
    return analyzeAnswers(answers, signal, courseId, studentQuestion);
  }

  // 模式 2：无答题记录 → 基于画像的薄弱点分析
  return analyzeProfile(profile, signal);
}

// 基于答题记录反馈
async function analyzeAnswers(
  answers: AnswerRecord[],
  signal?: AbortSignal,
  courseId?: string,
  studentQuestion?: string
): Promise<AgentResult> {
  const correct = answers.filter((a) => a.userAnswer.trim().toUpperCase() === a.correctAnswer.trim().toUpperCase()).length;
  const accuracy = answers.length > 0 ? correct / answers.length : 0;
  const wrongAnswers = answers.filter((a) => a.userAnswer.trim().toUpperCase() !== a.correctAnswer.trim().toUpperCase());

  // 从错题中提取关键词，检索相关知识
  let relatedKnowledge = "";
  let citations: Citation[] = [];
  if (wrongAnswers.length > 0) {
    const wrongTexts = wrongAnswers.map((a) => a.question).join(" ");
    const chunks = retrieve(wrongTexts, courseId, 3)
      .filter((chunk) => courseId === undefined || chunk.courseId === courseId);
    if (chunks.length > 0) {
      relatedKnowledge = chunks.map((c) => `• ${c.source}：${c.text.slice(0, 100)}...`).join("\n");
      citations = chunks.map((chunk) => ({ doc: chunk.source, snippet: chunk.text.slice(0, 120) }));
    }
  }

  // CMU 15-210, Question 13.32: https://www.cs.cmu.edu/afs/cs/academic/class/15210-s14/www/lectures/shortest-path.pdf
  const dijkstraExample = wrongAnswers.some((answer) =>
    /Dijkstra/i.test(answer.question) && /负权/.test(answer.question))
    ? "\n如需举数值反例，只用已核对的有向图：s→A=3、s→B=2、A→B=-2；B 会先以 2 被确定，但经 A 到 B 的路径权重为 1。先核对顶点确定顺序和每次松弛，再写进回答。"
    : "";

  const systemPrompt = `你是大学课程学伴。根据实际作答，用自然、简短的中文回应学生。
单题先回答学生的问题，指出答案中一个具体差异及原因，再给一个能立刻完成的练习。多题只归纳最重要的一个共性问题，举一道题说明，再给一个练习。全部正确时说明做对的关键点，并给一个进阶练习。
只依据题目条件、作答和提供的资料判断；数值例子必须先核对运算与步骤，无法核对就解释概念，不编造例子。不要推测学生的学习能力或心理，也不要编造教材章节。最多三句话，不写标题、报告、分类、百分比或建议清单。${dijkstraExample}`;

  const userPrompt = `${studentQuestion ? `学生的问题：${studentQuestion}\n\n` : ""}本次答对 ${correct}/${answers.length} 题。
答题记录：
${answers.map((a, i) => {
  const isCorrect = a.userAnswer.trim().toUpperCase() === a.correctAnswer.trim().toUpperCase();
  return `第${i + 1}题：${a.question}\n  学生答案：${a.userAnswer || "（未作答）"}\n  正确答案：${a.correctAnswer}\n  结果：${isCorrect ? "✓ 正确" : "✗ 错误"}`;
}).join("\n\n")}

${relatedKnowledge ? `相关参考资料：\n${relatedKnowledge}` : ""}`;

  const content = await callModel(systemPrompt, userPrompt, {
    temperature: 0.3,
    maxTokens: 512,
    signal,
  });

  return {
    agent: "Evaluator",
    content,
    citations,
    metadata: { accuracy, correct, total: answers.length, wrongCount: wrongAnswers.length },
  };
}

// 基于用户画像的薄弱点分析（无答题记录时）
async function analyzeProfile(
  profile?: LearningProfileSnapshot,
  signal?: AbortSignal
): Promise<AgentResult> {
  if (!profile) {
    return {
      agent: "Evaluator",
      content: "暂无用户画像数据，无法生成学习诊断。请先进行答题练习。",
    };
  }

  const systemPrompt = `你是一位学习顾问，根据用户的学习画像生成个性化学习建议。

请按以下结构输出：

【画像概览】
学习阶段、学习风格、当前正确率。

【薄弱知识点分析】
针对每个薄弱知识点，分析可能的原因和改进方向。

【优势知识点】
肯定用户已掌握的知识，鼓励保持。

【推荐学习路径】
基于薄弱点，推荐接下来 1-2 周的学习重点和顺序。

【练习建议】
推荐适合的练习类型和难度。`;

  const userPrompt = `用户画像：
- 阶段：${profile.stage}
- 学习风格：${profile.learningStyle}
- 累计答题：${profile.stats.totalQuestions} 题
- 正确率：${(profile.stats.accuracy * 100).toFixed(0)}%
- 学习天数：${profile.stats.studyDays} 天
- 薄弱知识点：${profile.weakTopics.join("、") || "暂无"}
- 已掌握知识点：${profile.strongTopics.join("、") || "暂无"}`;

  const content = await callModel(systemPrompt, userPrompt, {
    temperature: 0.4,
    maxTokens: 1536,
    signal,
  });

  return {
    agent: "Evaluator",
    content: `## 个性化学习建议\n\n${content}`,
    metadata: {
      accuracy: profile.stats.accuracy,
      totalQuestions: profile.stats.totalQuestions,
      weakTopics: profile.weakTopics,
    },
  };
}
