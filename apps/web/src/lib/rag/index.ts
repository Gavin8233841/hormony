// 简化版 RAG：基于关键词重叠的检索（初期零依赖验证流程）
// 后续替换为向量库（如 faiss / pgvector / 云向量服务）

import type { KnowledgeChunk } from "@/lib/types";
import { store } from "@/lib/store/db";

// 简易分词：按非字母数字汉字拆分
function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .split(" ")
    .filter((t) => t.length > 1);
}

// 计算 query 与 chunk 的关键词重叠分数
function score(queryTokens: string[], chunk: KnowledgeChunk): number {
  const chunkTokens = tokenize(chunk.text);
  const chunkSet = new Set(chunkTokens);
  let hits = 0;
  for (const t of queryTokens) {
    if (chunkSet.has(t)) hits++;
  }
  // 归一化分数
  return hits / Math.max(queryTokens.length, 1);
}

export function retrieve(query: string, courseId?: string, topK = 3): KnowledgeChunk[] {
  const candidates = store.getKnowledge(courseId);
  const queryTokens = tokenize(query);
  const queryLower = query.toLowerCase();

  // 1. 尝试 token 重叠匹配
  let results: KnowledgeChunk[] = candidates
    .map((c) => ({ chunk: c, s: score(queryTokens, c) }))
    .filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s)
    .slice(0, topK)
    .map((x) => ({ ...x.chunk, score: x.s }));

  // 2. token 匹配为空时，回退到子串匹配（兼容中文无分词场景）
  if (results.length === 0) {
    results = candidates
      .filter((c) => c.text.toLowerCase().includes(queryLower))
      .slice(0, topK);
  }

  // 3. 仍为空时，用查询中的关键名词做子串匹配（提取 2 字以上片段）
  if (results.length === 0) {
    const keywords = extractKeywords(query);
    results = candidates
      .map((c) => {
        const textLower = c.text.toLowerCase();
        let hits = 0;
        for (const kw of keywords) {
          if (textLower.includes(kw)) hits++;
        }
        return { chunk: c, s: hits };
      })
      .filter((x) => x.s > 0)
      .sort((a, b) => b.s - a.s)
      .slice(0, topK)
      .map((x) => ({ ...x.chunk, score: x.s }));
  }

  return results;
}

// 从查询中提取关键名词片段（中文取 2-4 字连续片段，英文取单词）
function extractKeywords(query: string): string[] {
  const keywords = new Set<string>();
  // 英文单词
  const enWords = query.toLowerCase().match(/[a-z]{2,}/g) ?? [];
  enWords.forEach((w) => keywords.add(w));
  // 中文连续片段（2-4 字滑动窗口）
  const chinese = query.match(/[\u4e00-\u9fa5]+/g) ?? [];
  for (const seg of chinese) {
    if (seg.length >= 2 && seg.length <= 4) {
      keywords.add(seg);
    } else if (seg.length > 4) {
      // 长片段取 2-3 字子串
      for (let len = 2; len <= 3; len++) {
        for (let i = 0; i <= seg.length - len; i++) {
          keywords.add(seg.slice(i, i + len));
        }
      }
    }
  }
  return Array.from(keywords);
}

export function formatContext(chunks: KnowledgeChunk[]): string {
  if (chunks.length === 0) return "";
  return chunks
    .map((c, i) => `[${i + 1}] 来源：${c.source}\n${c.text}`)
    .join("\n\n");
}
