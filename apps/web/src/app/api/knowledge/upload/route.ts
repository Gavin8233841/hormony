// POST /api/knowledge/upload — 上传知识文本到 RAG 知识库
// 支持单条文本上传，自动分块存储

import { store } from "@/lib/store/db";
import { generateId } from "@/lib/utils";
import { invalidateRagCache } from "@/lib/rag";
import type { KnowledgeUploadRequest, KnowledgeChunk } from "@/lib/types";

export const dynamic = "force-dynamic";

const MAX_TEXT_LENGTH = 50000;
const MAX_CHUNK_SIZE = 500;

// 将长文本按段落/句子边界分块
function chunkText(text: string): string[] {
  if (text.length <= MAX_CHUNK_SIZE) {
    return [text.trim()];
  }

  const chunks: string[] = [];
  // 先按段落分割
  const paragraphs = text.split(/\n\s*\n/);

  let currentChunk = "";
  for (const para of paragraphs) {
    if (currentChunk.length + para.length + 2 <= MAX_CHUNK_SIZE) {
      currentChunk = currentChunk ? `${currentChunk}\n\n${para}` : para;
    } else {
      if (currentChunk) chunks.push(currentChunk.trim());
      // 段落本身超长时按句子分割
      if (para.length > MAX_CHUNK_SIZE) {
        const sentences = para.split(/(?<=[。！？.!?])\s*/);
        let sentenceChunk = "";
        for (const sent of sentences) {
          if (sentenceChunk.length + sent.length <= MAX_CHUNK_SIZE) {
            sentenceChunk += sent;
          } else {
            if (sentenceChunk) chunks.push(sentenceChunk.trim());
            sentenceChunk = sent;
          }
        }
        if (sentenceChunk) currentChunk = sentenceChunk;
        else currentChunk = "";
      } else {
        currentChunk = para;
      }
    }
  }
  if (currentChunk) chunks.push(currentChunk.trim());

  return chunks.filter((c) => c.length > 0);
}

export async function POST(req: Request) {
  try {
    let body: KnowledgeUploadRequest;
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
    }

    const courseId = String(body.courseId ?? "").trim();
    const source = String(body.source ?? "").trim();
    const text = String(body.text ?? "").trim();

    if (!courseId) {
      return Response.json({ error: "缺少 courseId", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (!source) {
      return Response.json({ error: "缺少 source（资料来源名称）", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (!text) {
      return Response.json({ error: "缺少 text（知识内容）", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (text.length > MAX_TEXT_LENGTH) {
      return Response.json(
        { error: `文本过长（上限 ${MAX_TEXT_LENGTH} 字符，当前 ${text.length}）`, code: "TEXT_TOO_LONG" },
        { status: 400 }
      );
    }

    // 分块
    const textChunks = chunkText(text);
    const chunks: KnowledgeChunk[] = textChunks.map((chunkText) => ({
      id: generateId("k"),
      text: chunkText,
      source,
      courseId,
    }));

    store.addKnowledgeBatch(chunks);
    // 文档变更：清除 RAG 索引缓存，下次检索按新文档集重建
    invalidateRagCache();
    store.logActivity({
      type: "study",
      description: `上传知识资料：${source}（${chunks.length} 个切片）`,
      timestamp: new Date().toISOString(),
    });

    return Response.json({
      success: true,
      courseId,
      source,
      chunkCount: chunks.length,
      chunkIds: chunks.map((c) => c.id),
    });
  } catch (err) {
    console.error("[knowledge/upload] unhandled error:", err instanceof Error ? err.message : String(err));
    return Response.json({ error: "服务器内部错误", code: "INTERNAL_ERROR" }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
