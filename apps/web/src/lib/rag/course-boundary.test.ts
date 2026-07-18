import { describe, expect, it } from "vitest";
import { COURSE_IDS, allKnowledgeChunks } from "@/lib/data";
import { selectRetrievedChunks } from "./course-boundary";

describe("RAG 课程与 Topic 边界", () => {
  it("应完整保留全部合法内置知识切片", () => {
    expect(
      selectRetrievedChunks(
        allKnowledgeChunks,
        undefined,
        allKnowledgeChunks.length
      )
    ).toEqual(allKnowledgeChunks);
  });

  it("指定课程时应只保留该课程的精确 Topic 切片", () => {
    for (const courseId of COURSE_IDS) {
      const expected = allKnowledgeChunks.filter(
        (chunk) => chunk.courseId === courseId
      );
      expect(
        selectRetrievedChunks(expected, courseId, expected.length)
      ).toEqual(expected);
    }
  });

  it("应仅保留 KnowledgeChunk 合约字段", () => {
    expect(selectRetrievedChunks([{
      id: "cs101-contract-test",
      text: "数组使用连续存储空间保存同一类型的数据元素。",
      source: "数据结构课程资料",
      courseId: "cs101",
      topic: "数组与线性表",
      score: 0.9,
      provenance: "original_instructional_content",
      sourceResourceIds: ["course_outline", "course_standard"],
      internalNote: "不得返回的内部字段",
    }], "cs101", 1)).toEqual([{
      id: "cs101-contract-test",
      text: "数组使用连续存储空间保存同一类型的数据元素。",
      source: "数据结构课程资料",
      courseId: "cs101",
      topic: "数组与线性表",
      score: 0.9,
      provenance: "original_instructional_content",
      sourceResourceIds: ["course_outline", "course_standard"],
    }]);
  });

  it("应拒绝畸形或重复的来源证据字段", () => {
    const baseChunk = {
      id: "cs101-contract-test",
      text: "数组使用连续存储空间保存同一类型的数据元素。",
      source: "数据结构课程资料",
      courseId: "cs101",
      topic: "数组与线性表",
    };
    expect(() => selectRetrievedChunks([{
      ...baseChunk,
      provenance: "official",
    }], "cs101", 1)).toThrow("RAG 检索结果不符合课程数据契约");
    expect(() => selectRetrievedChunks([{
      ...baseChunk,
      sourceResourceIds: ["course_outline", "course_outline"],
    }], "cs101", 1)).toThrow("RAG 检索结果不符合课程数据契约");
  });
});
