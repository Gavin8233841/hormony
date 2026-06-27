"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MessageSquare, BookOpen, CalendarDays, Target, TrendingUp, ShieldCheck, Database } from "lucide-react";
import type { DashboardStats } from "@/lib/types";

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch("/api/stats?userId=demo");
        if (res.ok) {
          const data = (await res.json()) as DashboardStats;
          setStats(data);
        }
      } catch {
        // 降级到默认值
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const totalQuestions = stats?.totalQuestions ?? 0;
  const accuracy = stats ? Math.round(stats.accuracy * 100) : 0;
  const studyDays = stats?.studyDays ?? 0;
  const activeCourses = stats?.activeCourses ?? 0;
  const completedTasks = stats?.completedTasks ?? 0;
  const totalTasks = stats?.totalTasks ?? 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">学习仪表盘</h1>
        <p className="mt-1 text-sm text-slate-400">智能校园学习助理 · 个性化辅导</p>
      </div>

      {/* 统计卡片 */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard icon={MessageSquare} label="累计提问" value={loading ? "…" : String(totalQuestions)} color="text-brand-100" />
        <StatCard icon={Target} label="答题正确率" value={loading ? "…" : `${accuracy}%`} color="text-emerald-400" />
        <StatCard icon={CalendarDays} label="连续学习" value={loading ? "…" : `${studyDays} 天`} color="text-amber-400" />
        <StatCard icon={BookOpen} label="进行中课程" value={loading ? "…" : `${activeCourses} 门`} color="text-purple-400" />
      </div>

      {/* 快捷入口 */}
      <div className="grid grid-cols-3 gap-4">
        <Link href="/chat" className="card transition hover:border-brand-500/50">
          <MessageSquare className="mb-2 text-brand-100" size={24} />
          <h3 className="font-semibold">AI 对话辅导</h3>
          <p className="mt-1 text-sm text-slate-400">智能问答，获取带资料引用的讲解</p>
        </Link>
        <Link href="/plan" className="card transition hover:border-brand-500/50">
          <CalendarDays className="mb-2 text-amber-400" size={24} />
          <h3 className="font-semibold">生成学习计划</h3>
          <p className="mt-1 text-sm text-slate-400">输入目标，自动拆解为每日可执行任务</p>
        </Link>
        <Link href="/knowledge" className="card transition hover:border-brand-500/50">
          <Database className="mb-2 text-emerald-400" size={24} />
          <h3 className="font-semibold">知识库检索</h3>
          <p className="mt-1 text-sm text-slate-400">搜索课程资料，语义匹配相关知识点</p>
        </Link>
      </div>

      {/* 学习进度概览 */}
      {!loading && totalTasks > 0 && (
        <div className="card">
          <div className="mb-3 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <TrendingUp size={18} className="text-brand-100" />
              <h2 className="font-semibold">学习计划进度</h2>
            </div>
            <span className="text-sm text-slate-400">{completedTasks} / {totalTasks} 已完成</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-slate-700/50">
            <div
              className="h-full rounded-full bg-brand-500 transition-all duration-500"
              style={{ width: `${totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0}%` }}
            />
          </div>
        </div>
      )}

      {/* 最近活动 */}
      {!loading && stats && stats.recentActivity.length > 0 && (
        <div className="card">
          <div className="mb-3 flex items-center gap-2">
            <TrendingUp size={18} className="text-brand-100" />
            <h2 className="font-semibold">最近活动</h2>
          </div>
          <div className="space-y-2">
            {stats.recentActivity.slice(0, 5).map((act, i) => (
              <div key={i} className="flex items-center gap-3 rounded-lg bg-slate-900/40 px-4 py-2.5">
                <div className={`h-2 w-2 rounded-full ${
                  act.type === "quiz" ? "bg-pink-400" :
                  act.type === "chat" ? "bg-brand-400" :
                  act.type === "plan" ? "bg-amber-400" : "bg-emerald-400"
                }`} />
                <span className="flex-1 text-sm text-slate-300">{act.description}</span>
                <span className="text-xs text-slate-500">
                  {new Date(act.timestamp).toLocaleDateString("zh-CN", { month: "short", day: "numeric" })}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 系统能力概览 */}
      <div className="card">
        <div className="mb-4 flex items-center gap-2">
          <TrendingUp size={18} className="text-brand-100" />
          <h2 className="font-semibold">系统能力概览</h2>
        </div>
        <div className="grid grid-cols-7 gap-2 text-center text-xs">
          {[
            { name: "画像", desc: "用户画像", color: "bg-blue-500/20 text-blue-300" },
            { name: "检索", desc: "知识库", color: "bg-emerald-500/20 text-emerald-300" },
            { name: "计划", desc: "任务拆解", color: "bg-amber-500/20 text-amber-300" },
            { name: "辅导", desc: "课程问答", color: "bg-purple-500/20 text-purple-300" },
            { name: "测验", desc: "自动出题", color: "bg-pink-500/20 text-pink-300" },
            { name: "评估", desc: "薄弱分析", color: "bg-cyan-500/20 text-cyan-300" },
            { name: "安全", desc: "内容审核", color: "bg-red-500/20 text-red-300" },
          ].map((a) => (
            <div key={a.name} className="rounded-lg border border-slate-700/50 p-3">
              <div className={`agent-tag mx-auto mb-1.5 w-fit ${a.color}`}>{a.name}</div>
              <div className="text-slate-400">{a.desc}</div>
            </div>
          ))}
        </div>
      </div>

      {/* 安全机制 */}
      <div className="card flex items-start gap-3">
        <ShieldCheck className="mt-0.5 text-emerald-400" size={20} />
        <div>
          <h3 className="font-semibold">内容安全与反幻觉机制</h3>
          <p className="mt-1 text-sm text-slate-400">
            所有 AI 输出经安全审核：敏感内容过滤、幻觉风险评级、学术诚信检查。
            回答附带资料引用，确保可解释性。
          </p>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
  color,
}: {
  icon: React.ElementType;
  label: string;
  value: string;
  color: string;
}) {
  return (
    <div className="card">
      <Icon size={20} className={color} />
      <div className="mt-3 text-2xl font-bold">{value}</div>
      <div className="text-sm text-slate-400">{label}</div>
    </div>
  );
}
