"use client";

import { useEffect, useState, useCallback } from "react";
import { User, TrendingUp, AlertCircle, Award, Pencil, Check, X, Loader2, Plus } from "lucide-react";
import type { UserProfile } from "@/lib/types";

export default function ProfilePage() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 编辑状态
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState("");
  const [editStage, setEditStage] = useState("");
  const [editStyle, setEditStyle] = useState("");
  const [editWeak, setEditWeak] = useState<string[]>([]);
  const [editStrong, setEditStrong] = useState<string[]>([]);
  const [newWeak, setNewWeak] = useState("");
  const [newStrong, setNewStrong] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const loadProfile = useCallback(async () => {
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
  }, []);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  const startEdit = () => {
    if (!profile) return;
    setEditName(profile.name);
    setEditStage(profile.stage);
    setEditStyle(profile.learningStyle);
    setEditWeak([...profile.weakTopics]);
    setEditStrong([...profile.strongTopics]);
    setEditing(true);
    setSaveMsg(null);
  };

  const cancelEdit = () => {
    setEditing(false);
    setSaveMsg(null);
  };

  const save = async () => {
    setSaving(true);
    setSaveMsg(null);
    try {
      const res = await fetch("/api/profile/update", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "demo",
          name: editName,
          stage: editStage,
          learningStyle: editStyle,
          weakTopics: editWeak,
          strongTopics: editStrong,
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: "保存失败" }));
        throw new Error(err.error ?? `保存失败 (HTTP ${res.status})`);
      }
      const updated = (await res.json()) as UserProfile;
      setProfile(updated);
      setEditing(false);
      setSaveMsg({ type: "success", text: "画像已更新" });
    } catch (e) {
      setSaveMsg({ type: "error", text: e instanceof Error ? e.message : "保存失败" });
    } finally {
      setSaving(false);
    }
  };

  const addWeak = () => {
    const v = newWeak.trim();
    if (v && !editWeak.includes(v)) {
      setEditWeak([...editWeak, v]);
      setNewWeak("");
    }
  };
  const removeWeak = (t: string) => setEditWeak(editWeak.filter((x) => x !== t));

  const addStrong = () => {
    const v = newStrong.trim();
    if (v && !editStrong.includes(v)) {
      setEditStrong([...editStrong, v]);
      setNewStrong("");
    }
  };
  const removeStrong = (t: string) => setEditStrong(editStrong.filter((x) => x !== t));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">个人画像</h1>
          <p className="mt-1 text-sm text-slate-400">你的学习数据画像，驱动个性化推荐</p>
        </div>
        {profile && !editing && (
          <button
            onClick={startEdit}
            className="flex items-center gap-2 rounded-lg border border-slate-700/60 px-4 py-2 text-sm text-slate-300 transition hover:border-brand-500/50"
          >
            <Pencil size={16} /> 编辑
          </button>
        )}
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

      {saveMsg && (
        <div className={`rounded-lg px-4 py-2.5 text-sm ${
          saveMsg.type === "success" ? "bg-emerald-500/10 text-emerald-300" : "bg-red-500/10 text-red-300"
        }`}>
          {saveMsg.text}
        </div>
      )}

      {!loading && !error && profile && (
        <>
          {/* 基本信息 */}
          <div className="card flex items-center gap-4">
            <div className="rounded-full bg-brand-500/20 p-4">
              <User className="text-brand-100" size={28} />
            </div>
            <div className="flex-1">
              {editing ? (
                <div className="grid grid-cols-3 gap-3">
                  <input
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    placeholder="姓名"
                    className="rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2 text-sm outline-none focus:border-brand-500/50"
                  />
                  <input
                    value={editStage}
                    onChange={(e) => setEditStage(e.target.value)}
                    placeholder="阶段（如：大三）"
                    className="rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2 text-sm outline-none focus:border-brand-500/50"
                  />
                  <input
                    value={editStyle}
                    onChange={(e) => setEditStyle(e.target.value)}
                    placeholder="学习风格"
                    className="rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2 text-sm outline-none focus:border-brand-500/50"
                  />
                </div>
              ) : (
                <>
                  <h2 className="text-xl font-bold">{profile.name}</h2>
                  <p className="text-sm text-slate-400">
                    {profile.stage} · 学习风格：{profile.learningStyle} · ID: {profile.userId}
                  </p>
                </>
              )}
            </div>
            {editing && (
              <div className="flex gap-2">
                <button
                  onClick={save}
                  disabled={saving}
                  className="flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-emerald-700 disabled:opacity-40"
                >
                  {saving ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                  保存
                </button>
                <button
                  onClick={cancelEdit}
                  className="flex items-center gap-1.5 rounded-lg border border-slate-700/60 px-3 py-2 text-sm text-slate-300 transition hover:border-slate-500"
                >
                  <X size={16} /> 取消
                </button>
              </div>
            )}
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
              {editing ? (
                <>
                  <div className="flex flex-wrap gap-2">
                    {editWeak.map((t) => (
                      <span key={t} className="flex items-center gap-1 rounded-lg bg-red-500/15 px-3 py-1.5 text-sm text-red-300">
                        {t}
                        <button onClick={() => removeWeak(t)} className="hover:text-red-200">
                          <X size={14} />
                        </button>
                      </span>
                    ))}
                  </div>
                  <div className="mt-2 flex gap-2">
                    <input
                      value={newWeak}
                      onChange={(e) => setNewWeak(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && addWeak()}
                      placeholder="添加薄弱知识点..."
                      className="flex-1 rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-1.5 text-sm outline-none focus:border-brand-500/50"
                    />
                    <button onClick={addWeak} className="rounded-lg bg-slate-700/50 px-3 py-1.5 text-slate-300 hover:bg-slate-600/50">
                      <Plus size={16} />
                    </button>
                  </div>
                </>
              ) : (
                <>
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
                </>
              )}
            </div>
            <div className="card">
              <div className="mb-3 flex items-center gap-2">
                <Award className="text-emerald-400" size={18} />
                <h3 className="font-semibold">已掌握知识点</h3>
              </div>
              {editing ? (
                <>
                  <div className="flex flex-wrap gap-2">
                    {editStrong.map((t) => (
                      <span key={t} className="flex items-center gap-1 rounded-lg bg-emerald-500/15 px-3 py-1.5 text-sm text-emerald-300">
                        {t}
                        <button onClick={() => removeStrong(t)} className="hover:text-emerald-200">
                          <X size={14} />
                        </button>
                      </span>
                    ))}
                  </div>
                  <div className="mt-2 flex gap-2">
                    <input
                      value={newStrong}
                      onChange={(e) => setNewStrong(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && addStrong()}
                      placeholder="添加已掌握知识点..."
                      className="flex-1 rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-1.5 text-sm outline-none focus:border-brand-500/50"
                    />
                    <button onClick={addStrong} className="rounded-lg bg-slate-700/50 px-3 py-1.5 text-slate-300 hover:bg-slate-600/50">
                      <Plus size={16} />
                    </button>
                  </div>
                </>
              ) : (
                <>
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
                </>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
