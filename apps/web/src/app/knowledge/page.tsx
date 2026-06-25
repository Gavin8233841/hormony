"use client";

import { useState } from "react";
import { Database, Search, FileText } from "lucide-react";
import type { KnowledgeChunk } from "@/lib/types";

export default function KnowledgePage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<KnowledgeChunk[]>([]);
  const [loading, setLoading] = useState(false);

  const search = async () => {
    if (!query.trim()) return;
    setLoading(true);
    try {
      // 简化版：直接调后端 chat 接口的检索能力，或本地展示
      const res = await fetch(
        `/api/courses?userId=demo`
      );
      // 这里用内置演示知识库展示
      const demoChunks: KnowledgeChunk[] = [
        { id: "k1", text: "二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。", source: "数据结构.pdf", courseId: "cs101" },
        { id: "k2", text: "动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算，适用于具有最优子结构和重叠子问题性质的问题。", source: "数据结构.pdf", courseId: "cs101" },
        { id: "k3", text: "进程调度算法包括先来先服务（FCFS）、短作业优先（SJF）、时间片轮转、多级反馈队列等。", source: "操作系统.pdf", courseId: "cs102" },
        { id: "k4", text: "TCP 三次握手：SYN → SYN+ACK → ACK，建立可靠连接；四次挥手用于安全关闭连接。", source: "计算机网络.pdf", courseId: "cs103" },
        { id: "k5", text: "图的遍历分为深度优先搜索（DFS）和广度优先搜索（BFS），DFS 使用栈/递归，BFS 使用队列。", source: "数据结构.pdf", courseId: "cs101" },
      ];
      const q = query.toLowerCase();
      const matched = demoChunks.filter(
        (c) => c.text.toLowerCase().includes(q) || c.source.toLowerCase().includes(q)
      );
      setResults(matched.length > 0 ? matched : demoChunks);
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
