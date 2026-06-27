"use client";

import { useEffect, useState } from "react";
import { User, TrendingUp, AlertCircle, Award } from "lucide-react";
import type { UserProfile } from "@/lib/types";

export default function ProfilePage() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch("/api/profile?userId=demo");
        if (!res.ok) throw new Error(`加载失败 (HTTP ${res.status})`);
        const data = (await res.json()) as UserProfile;
        setProfile(data);
      } catch (e) {
        setError(e instanceof Error ? e.message : "画像加载失败");
        setProfile(null);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">个人画像</h1>
        <p className="mt-1 text-sm text-slate-400">你的学习数据画像，驱动个性化推荐</p>
      </div>

      {loading && (
        <div className="card flex items-center justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-600 border-t-brand-500" />
        </div>
      )}

      {error && (
        <div className="card border-red-500/30">
          <p className="text-sm text-red-400">{error}</p>
        </div>
      )}

      {!loading && !error && !profile && (
        <div className="card">
          <div className="flex flex-col items-center py-16 text-center">
            <User size={32} className="text-slate-600" />
            <p className="mt-3 text-sm text-slate-400">暂无画像数据</p>
          </div>
        </div>
      )}

      {!loading && !error && profile && (
        <>
          {/* 基本信息 */}
          <div className="card flex items-center gap-4">
            <div className="rounded-full bg-brand-500/20 p-4">
              <User className="text-brand-100" size={28} />
            </div>
            <div>
              <h2 className="text-xl font-bold">{profile.name}</h2>
              <p className="text-sm text-slate-400">
                {profile.stage} · 学习风格：{profile.learningStyle} · ID: {profile.userId}
              </p>
            </div>
          </div>

          {/* 统计 */}
          <div className="grid grid-cols-3 gap-4">
            <div className="card">
              <TrendingUp className="text-emerald-400" size={20} />
              <div className="mt-2 text-2xl font-bold">{(profile.stats.accuracy * 100).toFixed(0)}%</div>
              <div className="text-sm text-slate-400">答题正确率</div>
            </div>
            <div className="card">
              <Award className="text-amber-400" size={20} />
              <div className="mt-2 text-2xl font-bold">{profile.stats.totalQuestions}</div>
              <div className="text-sm text-slate-400">累计答题</div>
            </div>
            <div className="card">
              <User className="text-brand-100" size={20} />
              <div className="mt-2 text-2xl font-bold">{profile.stats.studyDays}</div>
              <div className="text-sm text-slate-400">学习天数</div>
            </div>
          </div>

          {/* 薄弱与优势知识点 */}
          <div className="grid grid-cols-2 gap-4">
            <div className="card">
              <div className="mb-3 flex items-center gap-2">
                <AlertCircle className="text-red-400" size={18} />
                <h3 className="font-semibold">薄弱知识点</h3>
              </div>
              {profile.weakTopics.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {profile.weakTopics.map((t) => (
                    <span key={t} className="rounded-lg bg-red-500/15 px-3 py-1.5 text-sm text-red-300">
                      {t}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-slate-500">暂无数据</p>
              )}
              <p className="mt-3 text-xs text-slate-500">学习计划会优先安排这些主题的复习任务</p>
            </div>
            <div className="card">
              <div className="mb-3 flex items-center gap-2">
                <Award className="text-emerald-400" size={18} />
                <h3 className="font-semibold">已掌握知识点</h3>
              </div>
              {profile.strongTopics.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {profile.strongTopics.map((t) => (
                    <span key={t} className="rounded-lg bg-emerald-500/15 px-3 py-1.5 text-sm text-emerald-300">
                      {t}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-slate-500">暂无数据</p>
              )}
              <p className="mt-3 text-xs text-slate-500">根据答题记录持续更新</p>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
