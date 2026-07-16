"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Brain, Loader2, CheckCircle2, XCircle, Target, TrendingDown, RefreshCw, History } from "lucide-react";
import type { QuizCatalogItem, QuizPackage, QuizResult } from "@/lib/types";
import { requestJson, getErrorMessage, isEndpointDisabled } from "@/lib/client-api";
import { DeviceDataNotice } from "@/components/device-data-notice";
import { parseQuizPackage, scoreQuizLocally } from "./local-scoring";

class QuizResponseContractError extends Error {
  constructor() {
    super("测验响应与请求的课程主题不一致");
    this.name = "QuizResponseContractError";
  }
}

function readQuizCatalog(value: unknown, courseId: string): QuizCatalogItem[] {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("题库目录响应格式无效");
  }
  const quizzes = (value as Record<string, unknown>).quizzes;
  if (!Array.isArray(quizzes)) {
    throw new Error("题库目录响应格式无效");
  }

  return quizzes.map((item) => {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      throw new Error("题库目录响应格式无效");
    }
    const record = item as Record<string, unknown>;
    if (
      typeof record.quizId !== "string" || record.quizId.trim().length === 0 ||
      record.courseId !== courseId ||
      typeof record.topic !== "string" || record.topic.trim().length === 0 ||
      record.topic !== record.topic.trim() ||
      typeof record.questionCount !== "number" ||
      !Number.isInteger(record.questionCount) ||
      record.questionCount < 0
    ) {
      throw new Error("题库目录响应格式无效");
    }
    return {
      quizId: record.quizId,
      courseId,
      topic: record.topic,
      questionCount: record.questionCount,
    };
  });
}

export default function QuizPage() {
  const [courseId, setCourseId] = useState("cs101");
  const [topic, setTopic] = useState("");
  const [focusTag, setFocusTag] = useState("");
  const [count, setCount] = useState(5);
  const [difficulty, setDifficulty] = useState<"easy" | "medium" | "hard">("medium");

  const [quiz, setQuiz] = useState<QuizPackage | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<QuizResult | null>(null);
  const [error, setError] = useState("");
  const [history, setHistory] = useState<QuizResult[]>([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState("");
  const [endpointDisabled, setEndpointDisabled] = useState(false);
  const [catalog, setCatalog] = useState<QuizCatalogItem[]>([]);
  const [catalogLoading, setCatalogLoading] = useState(true);
  const [catalogError, setCatalogError] = useState("");
  const [catalogRetryKey, setCatalogRetryKey] = useState(0);
  const catalogAbortRef = useRef<AbortController | null>(null);
  const generationAbortRef = useRef<AbortController | null>(null);

  const loadHistory = useCallback(async (signal?: AbortSignal) => {
    setHistoryLoading(true);
    setHistoryError("");
    setEndpointDisabled(false);
    try {
      const data = await requestJson<{ results: QuizResult[] }>("/api/quiz?userId=demo", undefined, signal);
      setHistory(data.results ?? []);
    } catch (e) {
      if (isEndpointDisabled(e)) {
        setEndpointDisabled(true);
        return;
      }
      const msg = getErrorMessage(e, "获取测验数据失败");
      if (msg === null) {
        // AbortError — 不显示错误
        return;
      }
      setHistoryError(msg);
    } finally {
      if (!signal?.aborted) {
        setHistoryLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    loadHistory(controller.signal);
    return () => controller.abort();
  }, [loadHistory]);

  useEffect(() => {
    return () => {
      generationAbortRef.current?.abort();
      generationAbortRef.current = null;
    };
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    catalogAbortRef.current = controller;
    setCatalogLoading(true);
    setCatalogError("");
    setCatalog([]);
    setTopic("");

    const loadCatalog = async () => {
      try {
        const data = await requestJson<unknown>(
          `/api/quiz?courseId=${encodeURIComponent(courseId)}`,
          undefined,
          controller.signal,
        );
        if (catalogAbortRef.current !== controller) return;
        const nextCatalog = readQuizCatalog(data, courseId);
        setCatalog(nextCatalog);
        setTopic(nextCatalog[0]?.topic ?? "");
      } catch (e) {
        if (catalogAbortRef.current !== controller) return;
        const msg = getErrorMessage(e, "加载题库目录失败");
        if (msg !== null) setCatalogError(msg);
      } finally {
        if (catalogAbortRef.current === controller && !controller.signal.aborted) {
          setCatalogLoading(false);
        }
      }
    };

    loadCatalog();
    return () => controller.abort();
  }, [catalogRetryKey, courseId]);

  const changeCourse = (nextCourseId: string) => {
    catalogAbortRef.current?.abort();
    generationAbortRef.current?.abort();
    generationAbortRef.current = null;
    setCourseId(nextCourseId);
    setCatalog([]);
    setCatalogLoading(true);
    setCatalogError("");
    setTopic("");
    setError("");
    setLoading(false);
  };

  const retryCatalog = () => {
    catalogAbortRef.current?.abort();
    setCatalog([]);
    setCatalogLoading(true);
    setCatalogError("");
    setTopic("");
    setError("");
    setCatalogRetryKey((key) => key + 1);
  };

  const generate = async () => {
    if (loading || catalogLoading || catalogError || !catalog.some((item) => item.topic === topic)) return;
    generationAbortRef.current?.abort();
    const controller = new AbortController();
    generationAbortRef.current = controller;
    const requestCourseId = courseId;
    const requestTopic = topic;
    setLoading(true);
    setError("");
    setQuiz(null);
    setResult(null);
    setAnswers({});
    try {
      const data = await requestJson<unknown>(
        "/api/quiz",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId: "demo",
            courseId: requestCourseId,
            topic: requestTopic,
            focusTag: focusTag.trim() || undefined,
            count,
            difficulty,
          }),
        },
        controller.signal,
      );
      if (generationAbortRef.current !== controller) return;
      const nextQuiz = parseQuizPackage(data);
      if (nextQuiz.courseId !== requestCourseId || nextQuiz.topic !== requestTopic) {
        throw new QuizResponseContractError();
      }
      if (generationAbortRef.current === controller) setQuiz(nextQuiz);
    } catch (e) {
      if (generationAbortRef.current !== controller) return;
      const msg = getErrorMessage(e, "生成测验失败");
      if (msg !== null) setError(msg);
    } finally {
      if (generationAbortRef.current === controller) {
        generationAbortRef.current = null;
        setLoading(false);
      }
    }
  };

  const score = () => {
    if (!quiz) return;
    setError("");
    try {
      setResult(scoreQuizLocally(quiz, answers, "demo"));
    } catch (e) {
      const msg = getErrorMessage(e, "本地评分失败");
      if (msg) setError(msg);
    }
  };

  const reset = () => {
    setQuiz(null);
    setResult(null);
    setAnswers({});
    setError("");
  };

  const answeredCount = quiz
    ? quiz.questions.filter((question) => (answers[question.id] ?? "").trim().length > 0).length
    : 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">智能测验</h1>
        <p className="mt-1 text-sm text-slate-400">自动出题 · 即时评分 · 薄弱点诊断</p>
      </div>

      {/* 配置区 */}
      {!quiz && (
        <div className="card space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="text-sm text-slate-400">课程</label>
              <select
                value={courseId}
                onChange={(e) => changeCourse(e.target.value)}
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              >
                <option value="cs101">数据结构 (cs101)</option>
                <option value="cs102">操作系统 (cs102)</option>
                <option value="cs103">计算机网络 (cs103)</option>
              </select>
            </div>
            <div>
              <label className="text-sm text-slate-400">主题</label>
              <select
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                disabled={catalogLoading || catalogError.length > 0 || catalog.length === 0}
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              >
                {catalogLoading ? (
                  <option value="">正在加载主题...</option>
                ) : catalogError ? (
                  <option value="">题库目录加载失败</option>
                ) : catalog.length === 0 ? (
                  <option value="">暂无可用主题</option>
                ) : (
                  catalog.map((item) => (
                    <option key={item.quizId} value={item.topic}>
                      {item.topic}（{item.questionCount} 题）
                    </option>
                  ))
                )}
              </select>
              {catalogLoading && (
                <p className="mt-1 flex items-center gap-1.5 text-xs text-slate-500">
                  <Loader2 size={12} className="animate-spin" /> 正在加载课程主题
                </p>
              )}
              {!catalogLoading && catalogError && (
                <div className="mt-1 flex items-center justify-between gap-2 text-xs text-red-400">
                  <span>{catalogError}</span>
                  <button
                    type="button"
                    onClick={retryCatalog}
                    className="shrink-0 rounded border border-red-500/30 px-2 py-1 transition hover:bg-red-500/10"
                  >
                    重试
                  </button>
                </div>
              )}
              {!catalogLoading && !catalogError && catalog.length === 0 && (
                <p className="mt-1 text-xs text-slate-500">当前课程没有可用于生成测验的主题</p>
              )}
            </div>
          </div>
          <div>
            <label className="text-sm text-slate-400">重点标签（可选）</label>
            <input
              value={focusTag}
              onChange={(e) => setFocusTag(e.target.value)}
              maxLength={12}
              placeholder="如：边界条件、代码推演"
              className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
            />
            <p className="mt-1 text-xs text-slate-500">用于让 AI 围绕指定能力标签生成题目，题目标签也会记录到画像。</p>
          </div>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="text-sm text-slate-400">题目数量</label>
              <input
                type="number"
                value={count}
                onChange={(e) => setCount(Number(e.target.value))}
                min={1}
                max={20}
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              />
            </div>
            <div>
              <label className="text-sm text-slate-400">难度</label>
              <select
                value={difficulty}
                onChange={(e) => setDifficulty(e.target.value as "easy" | "medium" | "hard")}
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              >
                <option value="easy">简单</option>
                <option value="medium">中等</option>
                <option value="hard">困难</option>
              </select>
            </div>
          </div>
          <button
            onClick={generate}
            disabled={loading || catalogLoading || catalogError.length > 0 || topic.length === 0}
            className="flex items-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Brain size={16} />}
            生成测验
          </button>
        </div>
      )}

      {error && <div className="card border-red-500/40 text-sm text-red-400">{error}</div>}

      {/* 答题区 */}
      {quiz && !result && (
        <div className="space-y-4">
          <div className="card flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex flex-wrap items-center gap-2">
              <Brain size={18} className="text-brand-100" />
              <span className="font-semibold">测验进行中</span>
              <span className="text-sm text-slate-400">· {quiz.questions.length} 题</span>
              {quiz.focusTag && (
                <span className="rounded-full bg-brand-500/15 px-2 py-0.5 text-xs text-brand-100">
                  重点：{quiz.focusTag}
                </span>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <span className="text-sm text-slate-400">已答 {answeredCount}/{quiz.questions.length}</span>
              <button
                onClick={score}
                disabled={answeredCount !== quiz.questions.length}
                className="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-emerald-700 disabled:opacity-40"
              >
                <CheckCircle2 size={16} />
                本地评分
              </button>
            </div>
          </div>

          {quiz.questions.map((q, i) => (
            <div key={q.id} className="card">
              <div className="mb-3 flex items-start gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-500/20 text-xs font-medium text-brand-100">
                  {i + 1}
                </span>
                <p className="text-sm font-medium">{q.stem}</p>
              </div>
              {q.options && q.options.length > 0 ? (
                <div className="ml-9 space-y-2">
                  {q.options.map((opt) => {
                    const isSelected = answers[q.id] === opt;
                    return (
                      <button
                        key={opt}
                        onClick={() => setAnswers((prev) => ({ ...prev, [q.id]: opt }))}
                        className={`flex w-full items-center gap-3 rounded-lg px-4 py-2.5 text-left text-sm transition ${
                          isSelected
                            ? "border border-brand-500/50 bg-brand-500/10 text-white"
                            : "border border-slate-700/40 bg-slate-900/30 text-slate-300 hover:border-slate-600"
                        }`}
                      >
                        <span className={`h-4 w-4 shrink-0 rounded-full border-2 ${
                          isSelected ? "border-brand-400 bg-brand-400" : "border-slate-600"
                        }`} />
                        {opt}
                      </button>
                    );
                  })}
                </div>
              ) : (
                <div className="ml-9">
                  <input
                    value={answers[q.id] ?? ""}
                    onChange={(e) => setAnswers((prev) => ({ ...prev, [q.id]: e.target.value }))}
                    placeholder="输入你的答案..."
                    className="w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* 结果区 */}
      {result && (
        <div className="space-y-4">
          {/* 分数卡片 */}
          <div className="card flex flex-col items-start gap-5 sm:flex-row sm:items-center sm:gap-6">
            <div className="flex flex-col items-center">
              <div className={`text-4xl font-bold ${
                result.accuracy >= 0.8 ? "text-emerald-400" :
                result.accuracy >= 0.6 ? "text-amber-400" : "text-red-400"
              }`}>
                {Math.round(result.accuracy * 100)}%
              </div>
              <div className="mt-1 text-xs text-slate-400">正确率</div>
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <Target size={18} className="text-brand-100" />
                <span className="font-semibold">
                  {result.correctCount} / {result.totalQuestions} 题正确
                </span>
              </div>
              <p className="mt-1 text-sm text-slate-400">
                {result.accuracy >= 0.8 ? "表现出色！继续保持。" :
                 result.accuracy >= 0.6 ? "基础尚可，部分知识点需加强。" :
                 "需要重点复习相关知识点。"}
              </p>
            </div>
            <button
              onClick={reset}
              className="flex items-center gap-2 rounded-lg border border-slate-700/60 px-4 py-2 text-sm text-slate-300 transition hover:border-brand-500/50"
            >
              <RefreshCw size={16} /> 再来一组
            </button>
          </div>

          <DeviceDataNotice
            title="评分已在当前页面完成"
            description="本次结果未提交到无状态 Web 服务；学习记录、错题与画像请在鸿学伴 HarmonyOS App 中保存和查看。"
          />

          {/* 评估报告 */}
          {result.evaluation && (
            <div className="card">
              <div className="mb-2 flex items-center gap-2">
                <Brain size={18} className="text-brand-100" />
                <h3 className="font-semibold">评估报告</h3>
              </div>
              <p className="text-sm leading-relaxed text-slate-300">{result.evaluation}</p>
            </div>
          )}

          {/* 薄弱知识点 */}
          {result.weakTopics.length > 0 && (
            <div className="card">
              <div className="mb-3 flex items-center gap-2">
                <TrendingDown size={18} className="text-amber-400" />
                <h3 className="font-semibold">建议复习</h3>
              </div>
              <div className="flex flex-wrap gap-2">
                {result.weakTopics.map((t) => (
                  <span key={t} className="rounded-lg bg-amber-500/15 px-3 py-1.5 text-sm text-amber-300">
                    {t}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* 逐题详情 */}
          <div className="card">
            <h3 className="mb-3 font-semibold">答题详情</h3>
            <div className="space-y-3">
              {result.details.map((d, i) => (
                <div
                  key={d.questionId}
                  className={`rounded-lg border p-4 ${
                    d.isCorrect
                      ? "border-emerald-500/30 bg-emerald-500/5"
                      : "border-red-500/30 bg-red-500/5"
                  }`}
                >
                  <div className="flex items-start gap-3">
                    {d.isCorrect ? (
                      <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-emerald-400" />
                    ) : (
                      <XCircle size={18} className="mt-0.5 shrink-0 text-red-400" />
                    )}
                    <div className="flex-1">
                      <p className="text-sm font-medium">
                        {i + 1}. {d.stem}
                      </p>
                      <div className="mt-2 space-y-1 text-xs">
                        <p className={d.isCorrect ? "text-emerald-300" : "text-red-300"}>
                          你的答案：{d.userAnswer || "（未作答）"}
                        </p>
                        {!d.isCorrect && (
                          <p className="text-emerald-300">正确答案：{d.correctAnswer}</p>
                        )}
                        {d.explanation && (
                          <p className="text-slate-400">解析：{d.explanation}</p>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 测验历史 */}
      {!quiz && !result && (
        <div className="card">
          <div className="mb-3 flex items-center gap-2">
            <History size={18} className="text-slate-400" />
            <h3 className="font-semibold">测验记录</h3>
          </div>
          {endpointDisabled ? (
            <p className="py-6 text-center text-sm text-slate-400">
              请在鸿学伴 HarmonyOS App 中查看
            </p>
          ) : historyError ? (
            <p className="py-6 text-center text-sm text-red-400">
              {historyError}
            </p>
          ) : historyLoading ? (
            <div className="flex items-center justify-center py-6">
              <Loader2 size={20} className="animate-spin text-slate-500" />
            </div>
          ) : history.length > 0 ? (
            <div className="space-y-2">
              {history.slice(0, 5).map((h, i) => (
                <div
                  key={i}
                  className="flex flex-wrap items-center gap-4 rounded-lg bg-slate-900/40 px-4 py-3"
                >
                  <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold ${
                    h.accuracy >= 0.8 ? "bg-emerald-500/20 text-emerald-400" :
                    h.accuracy >= 0.6 ? "bg-amber-500/20 text-amber-400" :
                    "bg-red-500/20 text-red-400"
                  }`}>
                    {Math.round(h.accuracy * 100)}%
                  </div>
                  <div className="flex-1">
                    <div className="text-sm font-medium">
                      {h.correctCount}/{h.totalQuestions} 题正确
                    </div>
                    <div className="text-xs text-slate-400">
                      {new Date(h.submittedAt).toLocaleString("zh-CN")}
                    </div>
                  </div>
                  {h.weakTopics.length > 0 && (
                    <div className="flex flex-wrap gap-1">
                      {h.weakTopics.slice(0, 3).map((t) => (
                        <span key={t} className="rounded bg-amber-500/10 px-2 py-0.5 text-xs text-amber-300">
                          {t}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="py-6 text-center text-sm text-slate-500">
              暂无测验记录，完成测验后此处显示历史成绩
            </p>
          )}
        </div>
      )}
    </div>
  );
}
