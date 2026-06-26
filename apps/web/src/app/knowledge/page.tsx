"use client";

import { useState } from "react";
import { Database, Search, FileText } from "lucide-react";
import type { KnowledgeChunk } from "@/lib/types";

export default function KnowledgePage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<KnowledgeChunk[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = async () => {
    if (!query.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/knowledge/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query: query.trim(), topK: 5 }),
      });
      if (!res.ok) throw new Error(`检索失败 (HTTP ${res.status})`);
      const data = (await res.json()) as { chunks?: KnowledgeChunk[] };
      setResults(data.chunks ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "检索失败");
      setResults([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">知识库</h1>
        <p className="mt-1 text-sm text-slate-400">
          RAG 检索演示 · Retrieval Agent 基于课程资料切片做语义匹配
        </p>
      </div>

      <div className="card">
        <div className="flex gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && search()}
              placeholder="搜索知识库，如：二叉搜索树、动态规划、TCP..."
              className="w-full rounded-lg border border-slate-700/60 bg-slate-800/40 py-2.5 pl-10 pr-3 text-sm outline-none focus:border-brand-500/50"
            />
          </div>
          <button
            onClick={search}
            disabled={loading}
            className="flex items-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
          >
            <Database size={16} /> 检索
          </button>
        </div>
      </div>

      {error && (
        <div className="card border-red-500/30">
          <p className="text-sm text-red-400">{error}</p>
        </div>
      )}

      {results.length > 0 && (
        <div className="space-y-3">
          <p className="text-sm text-slate-400">检索到 {results.length} 条相关资料</p>
          {results.map((c) => (
            <div key={c.id} className="card">
              <div className="mb-2 flex items-center gap-2">
                <FileText size={16} className="text-brand-100" />
                <span className="text-sm font-medium text-brand-100">{c.source}</span>
                <span className="rounded bg-slate-700/40 px-1.5 py-0.5 text-xs text-slate-400">
                  {c.courseId}
                </span>
              </div>
              <p className="text-sm leading-relaxed text-slate-300">{c.text}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
