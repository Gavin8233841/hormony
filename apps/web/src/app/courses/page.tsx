"use client";

import { useEffect, useState } from "react";
import { BookOpen, FileText } from "lucide-react";
import type { Course } from "@/lib/types";
import { requestJson, getErrorMessage } from "@/lib/client-api";

export default function CoursesPage() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    let active = true;

    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await requestJson<{ courses: Course[] }>(
          "/api/courses?userId=demo",
          undefined,
          controller.signal
        );
        if (!active) return;
        setCourses(data.courses ?? []);
      } catch (e) {
        if (!active) return;
        const msg = getErrorMessage(e, "课程数据获取失败");
        if (msg === null) return; // AbortError：请求被取消，不作为业务失败
        setError(msg);
        setCourses([]);
      } finally {
        if (active) setLoading(false);
      }
    };
    load();

    return () => {
      active = false;
      controller.abort();
    };
  }, [retryKey]);

  const retry = () => setRetryKey((k) => k + 1);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">我的课程</h1>
        <p className="mt-1 text-sm text-slate-400">课程资料已纳入知识库，支持智能检索与问答</p>
      </div>

      {loading && (
        <div className="card flex items-center justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-600 border-t-brand-500" />
        </div>
      )}

      {error && (
        <div className="card flex items-center justify-between border-red-500/30">
          <p className="text-sm text-red-400">{error}</p>
          <button
            type="button"
            onClick={retry}
            className="rounded-md border border-slate-600 px-3 py-1 text-xs text-slate-300 transition hover:border-brand-500/50 hover:text-brand-100"
          >
            重试
          </button>
        </div>
      )}

      {!loading && !error && courses.length === 0 && (
        <div className="card">
          <div className="flex flex-col items-center py-16 text-center">
            <BookOpen size={32} className="text-slate-600" />
            <p className="mt-3 text-sm text-slate-400">暂无课程数据</p>
          </div>
        </div>
      )}

      {!loading && !error && courses.length > 0 && (
        <div className="grid grid-cols-2 gap-4">
          {courses.map((c) => (
            <div key={c.id} className="card">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-brand-500/20 p-2.5">
                    <BookOpen className="text-brand-100" size={20} />
                  </div>
                  <div>
                    <h3 className="font-semibold">{c.title}</h3>
                    <p className="text-xs text-slate-400">{c.id}</p>
                  </div>
                </div>
                <span className="flex items-center gap-1 text-xs text-slate-400">
                  <FileText size={14} /> {c.docCount} 份资料
                </span>
              </div>

              <div className="mt-4">
                <div className="mb-1 flex justify-between text-xs text-slate-400">
                  <span>学习进度</span>
                  <span>{(Math.min(Math.max(c.progress, 0), 1) * 100).toFixed(0)}%</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-slate-700/50">
                  <div className="h-full rounded-full bg-brand-500" style={{ width: `${Math.min(Math.max(c.progress, 0), 1) * 100}%` }} />
                </div>
              </div>

              <div className="mt-4 flex flex-wrap gap-1.5">
                {c.topics.map((t) => (
                  <span key={t} className="rounded-md bg-slate-700/40 px-2 py-0.5 text-xs text-slate-300">
                    {t}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
