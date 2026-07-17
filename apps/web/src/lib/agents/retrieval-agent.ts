// Retrieval Agent：RAG 知识库检索

import { retrieve, formatContext } from "@/lib/rag";
import { selectRetrievedChunks } from "@/lib/rag/course-boundary";
import type { AgentResult, Citation } from "@/lib/types";

export async function runRetrievalAgent(
  query: string,
  courseId?: string
): Promise<AgentResult> {
  const chunks = selectRetrievedChunks(retrieve(query, courseId, 3), courseId, 3);
  const context = formatContext(chunks);
  const citations: Citation[] = chunks.map((c) => ({
    doc: c.source,
    snippet: c.text.slice(0, 60),
  }));

  return {
    agent: "Retrieval",
    content: context
      ? `已检索到 ${chunks.length} 条相关资料：\n${context}`
      : "未检索到直接相关资料，将基于通用知识作答。",
    citations,
    metadata: { chunkCount: chunks.length },
  };
}
