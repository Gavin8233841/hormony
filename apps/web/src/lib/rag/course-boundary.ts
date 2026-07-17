import { isCourseId, isCourseTopic } from "@/lib/data";
import type { KnowledgeChunk } from "@/lib/types";

export class RetrievedChunkContractError extends Error {
  constructor() {
    super("RAG 检索结果不符合课程数据契约");
    this.name = "RetrievedChunkContractError";
  }
}

function readRetrievedChunk(
  value: unknown,
  requestedCourseId: string | undefined
): KnowledgeChunk | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }

  const chunk = value as Record<string, unknown>;
  if (
    typeof chunk.id !== "string" || chunk.id.trim().length === 0 ||
    typeof chunk.text !== "string" || chunk.text.trim().length === 0 ||
    typeof chunk.source !== "string" || chunk.source.trim().length === 0 ||
    typeof chunk.courseId !== "string" || !isCourseId(chunk.courseId)
  ) {
    return undefined;
  }
  if (requestedCourseId !== undefined && chunk.courseId !== requestedCourseId) {
    return undefined;
  }
  if (
    chunk.topic !== undefined &&
    (typeof chunk.topic !== "string" || !isCourseTopic(chunk.courseId, chunk.topic))
  ) {
    return undefined;
  }
  if (
    chunk.score !== undefined &&
    (typeof chunk.score !== "number" || !Number.isFinite(chunk.score))
  ) {
    return undefined;
  }

  return {
    id: chunk.id,
    text: chunk.text,
    source: chunk.source,
    courseId: chunk.courseId,
    ...(typeof chunk.topic === "string" ? { topic: chunk.topic } : {}),
    ...(typeof chunk.score === "number" ? { score: chunk.score } : {}),
  };
}

export function selectRetrievedChunks(
  value: unknown,
  requestedCourseId: string | undefined,
  maxResults: number
): KnowledgeChunk[] {
  if (!Array.isArray(value) || !Number.isInteger(maxResults) || maxResults < 1) {
    throw new RetrievedChunkContractError();
  }
  if (value.length > maxResults) {
    throw new RetrievedChunkContractError();
  }

  const selected: KnowledgeChunk[] = [];
  for (const valueItem of value) {
    const chunk = readRetrievedChunk(valueItem, requestedCourseId);
    if (!chunk) throw new RetrievedChunkContractError();
    selected.push(chunk);
  }
  return selected;
}
