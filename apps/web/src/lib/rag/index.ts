// RAG 检索引擎：TF-IDF 加权 + 中文双字分词 + 多级回退
// 零依赖实现，后续可替换为向量库（faiss / pgvector / 云向量服务）

import type { KnowledgeChunk } from "@/lib/types";
import { store } from "@/lib/store/db";

// ========== 分词 ==========

// 中文双字（bigram）+ 英文单词分词
function tokenize(text: string): string[] {
  const tokens: string[] = [];
  const lower = text.toLowerCase();

  // 英文单词（2 字符以上）
  const enWords = lower.match(/[a-z]{2,}/g) ?? [];
  tokens.push(...enWords);

  // 中文双字滑动窗口
  const chineseSegments = lower.match(/[\u4e00-\u9fa5]+/g) ?? [];
  for (const seg of chineseSegments) {
    if (seg.length >= 2) {
      for (let i = 0; i <= seg.length - 2; i++) {
        tokens.push(seg.slice(i, i + 2));
      }
    }
    // 单字也保留（长度为 1 的中文段）
    if (seg.length === 1) {
      tokens.push(seg);
    }
  }

  // 数字（2 位以上）
  const numbers = lower.match(/\d{2,}/g) ?? [];
  tokens.push(...numbers);

  return tokens;
}

// ========== TF-IDF 计算 ==========

// 计算词频向量
function termFrequency(tokens: string[]): Map<string, number> {
  const tf = new Map<string, number>();
  for (const t of tokens) {
    tf.set(t, (tf.get(t) ?? 0) + 1);
  }
  // 归一化（除以最大词频）
  const maxFreq = Math.max(...tf.values(), 1);
  for (const [k, v] of tf) {
    tf.set(k, v / maxFreq);
  }
  return tf;
}

// 计算逆文档频率（IDF）
function computeIdf(documents: string[][]): Map<string, number> {
  const df = new Map<string, number>();
  const N = documents.length;

  for (const docTokens of documents) {
    const unique = new Set(docTokens);
    for (const term of unique) {
      df.set(term, (df.get(term) ?? 0) + 1);
    }
  }

  const idf = new Map<string, number>();
  for (const [term, freq] of df) {
    // IDF = log((N + 1) / (DF + 1)) + 1 （平滑处理）
    idf.set(term, Math.log((N + 1) / (freq + 1)) + 1);
  }
  return idf;
}

// 计算 TF-IDF 向量
function tfidfVector(tf: Map<string, number>, idf: Map<string, number>): Map<string, number> {
  const vec = new Map<string, number>();
  for (const [term, freq] of tf) {
    vec.set(term, freq * (idf.get(term) ?? 1));
  }
  return vec;
}

// 余弦相似度
function cosineSimilarity(vecA: Map<string, number>, vecB: Map<string, number>): number {
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (const [k, v] of vecA) {
    normA += v * v;
    const bVal = vecB.get(k);
    if (bVal !== undefined) {
      dotProduct += v * bVal;
    }
  }
  for (const [, v] of vecB) {
    normB += v * v;
  }

  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

// ========== 检索主逻辑 ==========

export function retrieve(query: string, courseId?: string, topK = 3): KnowledgeChunk[] {
  const knowledgePool = store.getKnowledge(courseId);
  if (knowledgePool.length === 0) return [];

  const queryTokens = tokenize(query);
  if (queryTokens.length === 0) return [];

  // 1. 构建文档集 token 列表
  const docTokensList = knowledgePool.map((c) => tokenize(c.text));
  const idf = computeIdf(docTokensList);

  // 2. 计算查询的 TF-IDF 向量
  const queryTf = termFrequency(queryTokens);
  const queryVec = tfidfVector(queryTf, idf);

  // 3. 计算每个文档的 TF-IDF 向量并评分
  const scored = knowledgePool.map((chunk, i) => {
    const docTf = termFrequency(docTokensList[i]);
    const docVec = tfidfVector(docTf, idf);
    const similarity = cosineSimilarity(queryVec, docVec);
    return { chunk, s: similarity };
  });

  // 4. 过滤零分并排序
  let results = scored
    .filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s)
    .slice(0, topK)
    .map((x) => ({ ...x.chunk, score: x.s }));

  // 5. TF-IDF 无结果时，回退到子串匹配
  if (results.length === 0) {
    const queryLower = query.toLowerCase();
    results = knowledgePool
      .filter((c) => c.text.toLowerCase().includes(queryLower))
      .slice(0, topK)
      .map((c) => ({ ...c, score: 0.5 }));
  }

  // 6. 仍无结果时，用关键词子串匹配
  if (results.length === 0) {
    const keywords = extractKeywords(query);
    results = knowledgePool
      .map((c) => {
        const textLower = c.text.toLowerCase();
        let hits = 0;
        for (const kw of keywords) {
          if (textLower.includes(kw)) hits++;
        }
        return { chunk: c, s: hits / Math.max(keywords.length, 1) };
      })
      .filter((x) => x.s > 0)
      .sort((a, b) => b.s - a.s)
      .slice(0, topK)
      .map((x) => ({ ...x.chunk, score: x.s }));
  }

  return results;
}

// 从查询中提取关键名词片段（用于回退匹配）
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
    .map((c, i) => `[${i + 1}] 来源：${c.source}（相关度：${c.score ? (c.score * 100).toFixed(0) : ""}%）\n${c.text}`)
    .join("\n\n");
}
