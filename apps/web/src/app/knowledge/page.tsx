"use client";

import { useRef, useState } from "react";
import { Database, Search, FileText, Upload, Loader2, ChevronDown, ChevronUp } from "lucide-react";
import type { KnowledgeChunk } from "@/lib/types";
import { requestJson, getErrorMessage } from "@/lib/client-api";

export default function KnowledgePage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<KnowledgeChunk[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasSearched, setHasSearched] = useState(false);

  // 取消旧搜索请求，避免快速多次搜索时旧响应覆盖新结果
  const searchAbortRef = useRef<AbortController | null>(null);

  // 上传状态
  const [showUpload, setShowUpload] = useState(false);
  const [uploadCourseId, setUploadCourseId] = useState("cs101");
  const [uploadSource, setUploadSource] = useState("");
  const [uploadText, setUploadText] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadMsg, setUploadMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const search = async () => {
    if (!query.trim()) return;
    // 取消上一次未完成的搜索，避免旧响应覆盖新结果
    searchAbortRef.current?.abort();
    const controller = new AbortController();
    searchAbortRef.current = controller;
    setLoading(true);
    setError(null);
    setHasSearched(true);
    try {
      const data = await requestJson<{ chunks?: KnowledgeChunk[] }>(
        "/api/knowledge/search",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ userId: "demo", query: query.trim(), topK: 5 }),
        },
        controller.signal,
      );
      // 请求已被新搜索取代，丢弃本次结果
      if (searchAbortRef.current !== controller) return;
      setResults(data.chunks ?? []);
    } catch (e) {
      // 请求已被新搜索取代，忽略旧请求的错误
      if (searchAbortRef.current !== controller) return;
      const msg = getErrorMessage(e, "检索失败");
      // AbortError → msg 为 null：不显示红色错误，也不清空已有结果
      if (msg !== null) {
        setError(msg);
        setResults([]);
      }
    } finally {
      // 仅当本次请求仍是当前请求时才关闭 loading
      if (searchAbortRef.current === controller) {
        setLoading(false);
      }
    }
  };

  const upload = async () => {
    if (!uploadSource.trim() || !uploadText.trim()) return;
    setUploading(true);
    setUploadMsg(null);
    try {
      const data = await requestJson<{
        success: boolean;
        courseId: string;
        source: string;
        chunkCount: number;
        chunkIds: string[];
      }>("/api/knowledge/upload", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "demo",
          courseId: uploadCourseId,
          source: uploadSource.trim(),
          text: uploadText.trim(),
        }),
      });
      setUploadMsg({ type: "success", text: `上传成功：${data.chunkCount} 个知识切片已加入知识库` });
      setUploadSource("");
      setUploadText("");
    } catch (e) {
      const msg = getErrorMessage(e, "上传失败");
      // AbortError → msg 为 null；错误时保留用户输入的 source/text（仅在成功时清空）
      if (msg !== null) {
        setUploadMsg({ type: "error", text: msg });
      }
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">知识库</h1>
        <p className="mt-1 text-sm text-slate-400">
          搜索课程资料 · 语义匹配相关知识点
        </p>
      </div>

      {/* 搜索区 */}
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
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Database size={16} />}
            检索
          </button>
          <button
            onClick={() => setShowUpload(!showUpload)}
            className="flex items-center gap-2 rounded-lg border border-slate-700/60 px-4 py-2.5 text-sm font-medium text-slate-300 transition hover:border-brand-500/50"
          >
            {showUpload ? <ChevronUp size={16} /> : <Upload size={16} />}
            上传
          </button>
        </div>
      </div>

      {/* 上传区 */}
      {showUpload && (
        <div className="card space-y-4">
          <div className="flex items-center gap-2">
            <Upload size={18} className="text-brand-100" />
            <h3 className="font-semibold">上传知识资料</h3>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-sm text-slate-400">课程 ID</label>
              <select
                value={uploadCourseId}
                onChange={(e) => setUploadCourseId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              >
                <option value="cs101">数据结构 (cs101)</option>
                <option value="cs102">操作系统 (cs102)</option>
                <option value="cs103">计算机网络 (cs103)</option>
              </select>
            </div>
            <div>
              <label className="text-sm text-slate-400">资料来源名称</label>
              <input
                value={uploadSource}
                onChange={(e) => setUploadSource(e.target.value)}
                placeholder="如：算法导论.pdf"
                className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
              />
            </div>
          </div>
          <div>
            <label className="text-sm text-slate-400">知识内容</label>
            <textarea
              value={uploadText}
              onChange={(e) => setUploadText(e.target.value)}
              placeholder="粘贴课程文本内容，系统会自动分块存入知识库..."
              rows={5}
              className="mt-1 w-full rounded-lg border border-slate-700/60 bg-slate-800/40 px-3 py-2.5 text-sm outline-none focus:border-brand-500/50"
            />
          </div>
          {uploadMsg && (
            <div className={`rounded-lg px-4 py-2.5 text-sm ${
              uploadMsg.type === "success"
                ? "bg-emerald-500/10 text-emerald-300"
                : "bg-red-500/10 text-red-300"
            }`}>
              {uploadMsg.text}
            </div>
          )}
          <button
            onClick={upload}
            disabled={uploading || !uploadSource.trim() || !uploadText.trim()}
            className="flex items-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
          >
            {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
            上传到知识库
          </button>
        </div>
      )}

      {/* 错误提示 */}
      {error && (
        <div className="card border-red-500/30">
          <p className="text-sm text-red-400">{error}</p>
        </div>
      )}

      {/* 空结果 */}
      {hasSearched && !loading && !error && results.length === 0 && (
        <div className="card flex flex-col items-center gap-2 py-12 text-center">
          <Search size={32} className="text-slate-600" />
          <p className="text-slate-400">未检索到相关资料</p>
          <p className="text-xs text-slate-500">尝试换个关键词，或上传新的课程资料</p>
        </div>
      )}

      {/* 搜索结果 */}
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
                {c.score !== undefined && c.score > 0 && (
                  <span className="rounded bg-brand-500/15 px-1.5 py-0.5 text-xs text-brand-300">
                    相关度 {Math.round(c.score * 100)}%
                  </span>
                )}
              </div>
              <p className="text-sm leading-relaxed text-slate-300">{c.text}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
