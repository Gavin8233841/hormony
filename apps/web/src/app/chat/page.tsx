"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { Send, Loader2, Square } from "lucide-react";
import type { AgentName, Citation, StreamEvent } from "@/lib/types";

interface ChatItem {
  role: "user" | "assistant";
  content: string;
  citations?: Citation[];
  trace?: { agent: AgentName; content: string }[];
  thinking?: AgentName[];
}

const agentColors: Record<AgentName, string> = {
  Profile: "bg-blue-500/20 text-blue-300",
  Retrieval: "bg-emerald-500/20 text-emerald-300",
  Planner: "bg-amber-500/20 text-amber-300",
  Tutor: "bg-purple-500/20 text-purple-300",
  Quiz: "bg-pink-500/20 text-pink-300",
  Evaluator: "bg-cyan-500/20 text-cyan-300",
  Safety: "bg-red-500/20 text-red-300",
};

export default function ChatPage() {
  const [messages, setMessages] = useState<ChatItem[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const sessionIdRef = useRef<string | null>(null);

  const send = useCallback(async () => {
    if (!input.trim() || loading) return;
    const userMsg: ChatItem = { role: "user", content: input.trim() };
    const currentInput = input.trim();
    setMessages((m) => [...m, userMsg]);
    setInput("");
    setLoading(true);

    // 构建对话历史（最近 6 轮）
    const history = messages.slice(-12).map((m) => ({
      role: m.role,
      content: m.content,
    }));

    const assistantMsg: ChatItem = {
      role: "assistant",
      content: "",
      citations: [],
      trace: [],
      thinking: [],
    };
    setMessages((m) => [...m, assistantMsg]);

    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "demo",
          message: currentInput,
          history: history.length > 0 ? history : undefined,
          context: sessionIdRef.current
            ? { sessionId: sessionIdRef.current }
            : undefined,
        }),
        signal: controller.signal,
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({ error: "未知错误" }));
        throw new Error(errData.error || `请求失败 (HTTP ${res.status})`);
      }

      const reader = res.body?.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            const data = line.replace(/^data: /, "").trim();
            if (!data) continue;
            try {
              const evt = JSON.parse(data) as StreamEvent;
              if (evt.type === "done") {
                sessionIdRef.current = evt.sessionId;
                continue;
              }
              setMessages((m) => {
                const last = m[m.length - 1];
                if (!last || last.role !== "assistant") return m;
                const updated: ChatItem = { ...last };
                if (evt.type === "thinking") {
                  updated.thinking = [...(last.thinking ?? []), evt.agent];
                } else if (evt.type === "trace") {
                  updated.trace = [...(last.trace ?? []), { agent: evt.agent, content: evt.content }];
                } else if (evt.type === "delta") {
                  updated.content = last.content + evt.content;
                } else if (evt.type === "citation") {
                  updated.citations = [...(last.citations ?? []), evt.source];
                }
                return [...m.slice(0, -1), updated];
              });
            } catch {
              /* ignore parse errors */
            }
          }
        }
      }
    } catch (err) {
      if (err instanceof DOMException && err.name === "AbortError") {
        setMessages((m) => {
          const last = m[m.length - 1];
          if (!last || last.role !== "assistant") return m;
          return [...m.slice(0, -1), { ...last, content: last.content || "（已取消）" }];
        });
      } else {
        setMessages((m) => {
          const last = m[m.length - 1];
          if (!last || last.role !== "assistant") return m;
          return [...m.slice(0, -1), { ...last, content: `请求失败：${err instanceof Error ? err.message : String(err)}` }];
        });
      }
    } finally {
      setLoading(false);
      abortRef.current = null;
    }
  }, [input, loading]);

  // 卸载时中止未完成的 SSE 请求
  useEffect(() => {
    return () => {
      abortRef.current?.abort();
    };
  }, []);

  const stop = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setLoading(false);
  }, []);

  const suggestions = [
    "什么是二叉搜索树？",
    "帮我制定两周数据结构复习计划",
    "出 3 道动态规划选择题",
    "解释 TCP 三次握手",
  ];

  return (
    <div className="flex h-[calc(100vh-4rem)] flex-col">
      <div className="mb-4">
        <h1 className="text-2xl font-bold">AI 对话辅导</h1>
        <p className="mt-1 text-sm text-slate-400">
          智能问答 · 流式输出 · 带资料引用
        </p>
      </div>

      {/* 消息区 */}
      <div className="flex-1 space-y-4 overflow-y-auto pr-2">
        {messages.length === 0 && (
          <div className="card">
            <p className="text-sm text-slate-400">试试这些问题：</p>
            <div className="mt-3 flex flex-wrap gap-2">
              {suggestions.map((s) => (
                <button
                  key={s}
                  onClick={() => setInput(s)}
                  className="rounded-lg border border-slate-700/60 px-3 py-1.5 text-sm text-slate-300 transition hover:border-brand-500/50 hover:text-white"
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={msg.role === "user" ? "flex justify-end" : ""}>
            <div className={msg.role === "user" ? "max-w-[70%] rounded-xl bg-brand-600/30 px-4 py-3" : "w-full"}>
              {msg.role === "assistant" && msg.thinking && msg.thinking.length > 0 && (
                <div className="mb-2 flex flex-wrap gap-1.5">
                  {msg.thinking.map((a, j) => (
                    <span key={j} className={`agent-tag ${agentColors[a]}`}>
                      {loading && j === msg.thinking!.length - 1 ? (
                        <Loader2 size={11} className="animate-spin" />
                      ) : null}
                      {a}
                    </span>
                  ))}
                </div>
              )}

              <div className="whitespace-pre-wrap text-sm leading-relaxed">
                {msg.content || (loading && msg.role === "assistant" ? "思考中..." : "")}
              </div>

              {/* 执行轨迹 */}
              {msg.trace && msg.trace.length > 0 && (
                <details className="mt-3 rounded-lg bg-slate-900/50 p-3 text-xs">
                  <summary className="cursor-pointer text-slate-400">参考资料溯源</summary>
                  <div className="mt-2 space-y-2">
                    {msg.trace.map((t, j) => (
                      <div key={j}>
                        <span className={`agent-tag ${agentColors[t.agent]}`}>{t.agent}</span>
                        <span className="ml-2 text-slate-400">{t.content}</span>
                      </div>
                    ))}
                  </div>
                </details>
              )}

              {/* 引用 */}
              {msg.citations && msg.citations.length > 0 && (
                <div className="mt-3 border-t border-slate-700/40 pt-2">
                  <p className="text-xs text-slate-500">资料引用：</p>
                  {msg.citations.map((c, j) => (
                    <div key={j} className="mt-1 text-xs text-slate-400">
                      [{j + 1}] {c.doc}
                      {c.snippet ? ` — ${c.snippet}...` : ""}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* 输入区 */}
      <div className="mt-4 flex gap-3">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && send()}
          placeholder="输入你的问题..."
          className="flex-1 rounded-xl border border-slate-700/60 bg-slate-800/40 px-4 py-3 text-sm outline-none transition focus:border-brand-500/50"
          disabled={loading}
        />
        <button
          onClick={send}
          disabled={loading || !input.trim()}
          className="flex items-center gap-2 rounded-xl bg-brand-600 px-5 py-3 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
        >
          {loading ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
          发送
        </button>
        {loading && (
          <button
            onClick={stop}
            className="flex items-center gap-2 rounded-xl border border-red-500/40 px-4 py-3 text-sm font-medium text-red-400 transition hover:bg-red-500/10"
          >
            <Square size={14} /> 停止
          </button>
        )}
      </div>
    </div>
  );
}
