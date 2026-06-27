// Evaluator Agent：错题分析、薄弱点诊断与学习建议
// 支持两种模式：基于答题记录分析 / 基于用户画像分析

import { callModel } from "./model";
import { store } from "@/lib/store/db";
import { retrieve } from "@/lib/rag";
import type { AgentResult } from "@/lib/types";

interface AnswerRecord {
  question: string;
  userAnswer: string;
  correctAnswer: string;
}

export async function runEvaluatorAgent(
  userId: string,
  answers: AnswerRecord[]
): Promise<AgentResult> {
  // 模式 1：有答题记录 → 详细错题分析
  if (answers.length > 0) {
    return analyzeAnswers(userId, answers);
  }

  // 模式 2：无答题记录 → 基于画像的薄弱点分析
  return analyzeProfile(userId);
}

// 基于答题记录的详细分析
async function analyzeAnswers(userId: string, answers: AnswerRecord[]): Promise<AgentResult> {
  const correct = answers.filter((a) => a.userAnswer.trim().toUpperCase() === a.correctAnswer.trim().toUpperCase()).length;
  const accuracy = answers.length > 0 ? correct / answers.length : 0;
  const wrongAnswers = answers.filter((a) => a.userAnswer.trim().toUpperCase() !== a.correctAnswer.trim().toUpperCase());

  // 从错题中提取关键词，检索相关知识
  let relatedKnowledge = "";
  if (wrongAnswers.length > 0) {
    const wrongTexts = wrongAnswers.map((a) => a.question).join(" ");
    const chunks = retrieve(wrongTexts, undefined, 3);
    if (chunks.length > 0) {
      relatedKnowledge = chunks.map((c) => `• ${c.source}：${c.text.slice(0, 100)}...`).join("\n");
    }
  }

  const systemPrompt = `你是一位资深学习诊断专家，擅长分析学生的错题模式并给出精准的改进建议。

请按以下结构输出分析报告：

【总体表现】
正确率评价和总体表现描述。

【错题分类】
将错题分为以下类别：
- 概念误解：对核心概念理解有偏差
- 粗心失误：思路正确但执行出错
- 知识盲区：完全未掌握的知识点
- 混淆易错：相似概念混淆

【薄弱知识点】
列出需要重点复习的知识点（2-5个）。

【复习建议】
针对每个薄弱知识点给出具体的复习建议，包括：
1. 推荐复习的资料章节
2. 建议练习的题型
3. 学习方法建议

【下一步行动】
给出 2-3 个可操作的下一步学习行动。`;

  const userPrompt = `学生ID：${userId}
正确率：${(accuracy * 100).toFixed(0)}%（${correct}/${answers.length}）

答题记录：
${answers.map((a, i) => {
  const isCorrect = a.userAnswer.trim().toUpperCase() === a.correctAnswer.trim().toUpperCase();
  return `第${i + 1}题：${a.question}\n  学生答案：${a.userAnswer || "（未作答）"}\n  正确答案：${a.correctAnswer}\n  结果：${isCorrect ? "✓ 正确" : "✗ 错误"}`;
}).join("\n\n")}

${relatedKnowledge ? `相关参考资料：\n${relatedKnowledge}` : ""}`;

  const content = await callModel(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 2048 });

  return {
    agent: "Evaluator",
    content: `## 学习诊断报告\n\n正确率：${(accuracy * 100).toFixed(0)}%（${correct}/${answers.length}）\n\n${content}`,
    metadata: { accuracy, correct, total: answers.length, wrongCount: wrongAnswers.length },
  };
}

// 基于用户画像的薄弱点分析（无答题记录时）
async function analyzeProfile(userId: string): Promise<AgentResult> {
  const profile = store.getProfile(userId);

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
- 姓名：${profile.name}
- 阶段：${profile.stage}
- 学习风格：${profile.learningStyle}
- 累计答题：${profile.stats.totalQuestions} 题
- 正确率：${(profile.stats.accuracy * 100).toFixed(0)}%
- 学习天数：${profile.stats.studyDays} 天
- 薄弱知识点：${profile.weakTopics.join("、") || "暂无"}
- 已掌握知识点：${profile.strongTopics.join("、") || "暂无"}`;

  const content = await callModel(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 1536 });

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
