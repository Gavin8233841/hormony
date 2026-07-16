// POST /api/knowledge/upload — 上传知识文本到 RAG 知识库
// 支持单条文本上传，自动分块存储

import { store } from "@/lib/store/db";
import { generateId } from "@/lib/utils";
import { invalidateRagCache } from "@/lib/rag";
import type { KnowledgeUploadRequest, KnowledgeChunk } from "@/lib/types";
import { readJsonObject } from "@/lib/request-json";
import { readUserId } from "@/lib/api-validation";
import { validateUserInput } from "@/lib/agents/safety-agent";

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
    const parsed = await readJsonObject<KnowledgeUploadRequest>(req);
    if (!parsed.ok) return parsed.response;
    const body = parsed.body;

    const userId = readUserId(body.userId);
    if (!userId.ok) return userId.response;
    if (body.courseId !== undefined && typeof body.courseId !== "string") {
      return Response.json({ error: "courseId 必须是字符串", code: "INVALID_COURSE" }, { status: 400 });
    }
    if (body.source !== undefined && typeof body.source !== "string") {
      return Response.json({ error: "source 必须是字符串", code: "INVALID_SOURCE" }, { status: 400 });
    }
    if (body.text !== undefined && typeof body.text !== "string") {
      return Response.json({ error: "text 必须是字符串", code: "INVALID_TEXT" }, { status: 400 });
    }
    const courseId = body.courseId?.trim() ?? "";
    const source = body.source?.trim() ?? "";
    const text = body.text?.trim() ?? "";

    if (!courseId) {
      return Response.json({ error: "缺少 courseId", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (!source) {
      return Response.json({ error: "缺少 source（资料来源名称）", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (!text) {
      return Response.json({ error: "缺少 text（知识内容）", code: "MISSING_FIELD" }, { status: 400 });
    }
    if (courseId.length > 100) {
      return Response.json({ error: "courseId 长度不能超过 100 字符", code: "INVALID_COURSE" }, { status: 400 });
    }
    if (source.length > 200) {
      return Response.json({ error: "source 长度不能超过 200 字符", code: "INVALID_SOURCE" }, { status: 400 });
    }
    if (text.length > MAX_TEXT_LENGTH) {
      return Response.json(
        { error: `文本过长（上限 ${MAX_TEXT_LENGTH} 字符，当前 ${text.length}）`, code: "TEXT_TOO_LONG" },
        { status: 400 }
      );
    }
    if (validateUserInput([courseId, source, text].join("\n")).length > 0) {
      return Response.json(
        { error: "知识内容不符合安全要求", code: "INPUT_REJECTED" },
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
      userId: userId.value,
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
