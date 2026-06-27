"use client";

import { useState } from "react";
import { CalendarDays, Loader2, CheckCircle2, Clock, Circle } from "lucide-react";
import type { PlanTask, StudyPlan } from "@/lib/types";

export default function PlanPage() {
  const [goal, setGoal] = useState("");
  const [days, setDays] = useState(14);
  const [minutes, setMinutes] = useState(90);
  const [tasks, setTasks] = useState<PlanTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const generate = async () => {
    if (!goal.trim()) return;
    setLoading(true);
    setError("");
    setTasks([]);
    try {
      const res = await fetch("/api/plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "demo",
          goal: goal.trim(),
          durationDays: days,
          dailyMinutes: minutes,
        }),
      });
      if (!res.ok) throw new Error("生成失败");
      const plan = (await res.json()) as StudyPlan;
      setTasks(plan.tasks ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  const toggleTask = async (taskId: string) => {
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;

    setTogglingId(taskId);
    // 乐观更新
    setTasks((prev) => prev.map((t) => t.id === taskId ? { ...t, done: !t.done } : t));

    try {
      const res = await fetch("/api/plan/save", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: "demo", taskId, done: !task.done }),
      });
      if (!res.ok) throw new Error("打卡失败");
    } catch {
      // 回滚
      setTasks((prev) => prev.map((t) => t.id === taskId ? { ...t, done: task.done } : t));
    } finally {
      setTogglingId(null);
    }
  };

  const completedCount = tasks.filter((t) => t.done).length;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">学习计划</h1>
        <p className="mt-1 text-sm text-slate-400">输入学习目标，自动拆解为每日可执行任务</p>
      </div>

      {/* 输入表单 */}
      <div className="card space-y-4">
        <div>
          <label className="text-sm text-slate-400">学习目标</label>
          <input
            value={goal}
            onChange={(e) => setGoal(e.target.value)}
            placeholder="例如：两周内复习数据结构期末考试"
            className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
          />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-sm text-slate-400">周期（天）</label>
            <input
              type="number"
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
              min={1}
              max={30}
              className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
            />
          </div>
          <div>
            <label className="text-sm text-slate-400">每日可用（分钟）</label>
            <input
              type="number"
              value={minutes}
              onChange={(e) => setMinutes(Number(e.target.value))}
              min={15}
              max={480}
              className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
            />
          </div>
        </div>
        <button
          onClick={generate}
          disabled={loading || !goal.trim()}
          className="flex items-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
        >
          {loading ? <Loader2 size={16} className="animate-spin" /> : <CalendarDays size={16} />}
          生成计划
        </button>
      </div>

      {error && <div className="card border-red-500/40 text-sm text-red-400">{error}</div>}

      {/* 任务列表 */}
      {tasks.length > 0 && (
        <div className="card">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="font-semibold">计划任务（{tasks.length} 项）</h3>
            <div className="flex items-center gap-3">
              <div className="h-2 w-24 overflow-hidden rounded-full bg-slate-700/50">
                <div
                  className="h-full rounded-full bg-emerald-500 transition-all duration-500"
                  style={{ width: `${(completedCount / tasks.length) * 100}%` }}
                />
              </div>
              <span className="text-xs text-slate-400">{completedCount}/{tasks.length}</span>
            </div>
          </div>
          <div className="space-y-2">
            {tasks.map((t, i) => (
              <div
                key={t.id}
                className={`flex items-center gap-3 rounded-lg px-4 py-3 transition ${
                  t.done ? "bg-emerald-500/10" : "bg-slate-900/40"
                }`}
              >
                <button
                  onClick={() => toggleTask(t.id)}
                  disabled={togglingId === t.id}
                  className="shrink-0 transition hover:scale-110 disabled:opacity-50"
                >
                  {togglingId === t.id ? (
                    <Loader2 size={18} className="animate-spin text-slate-500" />
                  ) : t.done ? (
                    <CheckCircle2 size={18} className="text-emerald-400" />
                  ) : (
                    <Circle size={18} className="text-slate-600" />
                  )}
                </button>
                <div className="flex-1">
                  <div className={`text-sm font-medium ${t.done ? "text-slate-500 line-through" : ""}`}>
                    {t.title}
                  </div>
                  <div className="flex items-center gap-3 text-xs text-slate-400">
                    <span>{t.date}</span>
                    <span className="flex items-center gap-1">
                      <Clock size={12} /> {t.estimatedMin} 分钟
                    </span>
                    <span className="rounded bg-slate-700/40 px-1.5 py-0.5">{t.type}</span>
                  </div>
                </div>
                <span className="text-xs text-slate-500">#{i + 1}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
