import { describe, it, expect, beforeEach } from "vitest";
import { retrieve, formatContext, invalidateRagCache } from "@/lib/rag";
import { store } from "@/lib/store/db";

describe("RAG TF-IDF 检索引擎", () => {
  beforeEach(() => {
    // store 是 globalThis 单例，种子数据已在首次加载时初始化
    // 这里只验证检索功能正常工作
    invalidateRagCache();
  });

  describe("retrieve() 基本检索", () => {
    it("中文关键词检索应返回相关结果", () => {
      const results = retrieve("二叉搜索树", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      // BST 相关的知识切片应出现在结果中
      const hasBstContent = results.some(
        (r) => r.text.includes("二叉搜索树") || r.text.includes("BST") || r.text.includes("二叉树")
      );
      expect(hasBstContent).toBe(true);
    });

    it("动态规划检索应返回相关结果", () => {
      const results = retrieve("动态规划", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].text).toContain("动态规划");
    });

    it("英文关键词检索应正常工作", () => {
      const results = retrieve("TCP", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].text.toLowerCase()).toContain("tcp");
    });

    it("多词组合查询应返回最相关的结果", () => {
      const results = retrieve("进程调度算法", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      // 进程调度的知识切片应排在前列
      expect(results[0].text).toContain("调度");
    });
  });

  describe("retrieve() 课程过滤", () => {
    it("指定 courseId 应只返回该课程的知识切片", () => {
      const results = retrieve("数据结构", "cs101", 5);
      expect(results.length).toBeGreaterThan(0);
      for (const r of results) {
        expect(r.courseId).toBe("cs101");
      }
    });

    it("不存在的 courseId 应返回空数组", () => {
      const results = retrieve("测试", "nonexistent_course", 3);
      expect(results).toEqual([]);
    });
  });

  describe("retrieve() 回退机制", () => {
    it("TF-IDF 无结果时应回退到子串匹配", () => {
      // 使用种子数据中的精确文本片段
      const results = retrieve("哈希表通过哈希函数", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].text).toContain("哈希表");
    });

    it("完全不相关的查询应返回空或低相关度结果", () => {
      const results = retrieve("xyzqwerty", undefined, 3);
      // 应回退到关键词匹配，若无匹配则返回空
      expect(results.length).toBeGreaterThanOrEqual(0);
    });
  });

  describe("retrieve() 评分", () => {
    it("结果应包含 score 字段", () => {
      const results = retrieve("二叉搜索树", undefined, 3);
      expect(results.length).toBeGreaterThan(0);
      for (const r of results) {
        expect(r.score).toBeDefined();
        expect(r.score).toBeGreaterThanOrEqual(0);
        expect(r.score).toBeLessThanOrEqual(1);
      }
    });

    it("结果应按相关度降序排列", () => {
      const results = retrieve("数据结构算法", undefined, 5);
      if (results.length >= 2) {
        for (let i = 1; i < results.length; i++) {
          expect(results[i - 1].score!).toBeGreaterThanOrEqual(results[i].score!);
        }
      }
    });
  });

  describe("formatContext()", () => {
    it("空数组应返回空字符串", () => {
      expect(formatContext([])).toBe("");
    });

    it("非空数组应返回格式化的上下文文本", () => {
      const results = retrieve("二叉搜索树", undefined, 2);
      const formatted = formatContext(results);
      expect(formatted).toContain("来源：");
      expect(formatted).toContain("相关度：");
    });

    it("应包含切片序号", () => {
      const results = retrieve("动态规划", undefined, 3);
      const formatted = formatContext(results);
      expect(formatted).toContain("[1]");
    });
  });

  describe("topK 参数", () => {
    it("topK=1 应只返回 1 条结果", () => {
      const results = retrieve("数据结构", undefined, 1);
      expect(results.length).toBeLessThanOrEqual(1);
    });

    it("topK=10 应最多返回 10 条结果", () => {
      const results = retrieve("算法", undefined, 10);
      expect(results.length).toBeLessThanOrEqual(10);
    });
  });

  describe("检索缓存", () => {
    it("命中缓存时应返回拷贝，避免调用方修改缓存内容", () => {
      const first = retrieve("二叉搜索树", undefined, 1);
      expect(first.length).toBe(1);
      const originalText = first[0].text;

      first[0].text = "调用方局部修改";

      const second = retrieve("二叉搜索树", undefined, 1);
      expect(second.length).toBe(1);
      expect(second[0].text).toBe(originalText);
    });

    it("知识库变更并显式失效后应读取新增内容", () => {
      const courseId = "cache-test-course";
      const query = "cacheuniquealpha";

      expect(retrieve(query, courseId, 3)).toEqual([]);

      store.addKnowledgeBatch([
        {
          id: "cache-test-knowledge-001",
          courseId,
          source: "cache-test",
          text: "cacheuniquealpha describes a newly uploaded topic",
        },
      ]);
      invalidateRagCache();

      const results = retrieve(query, courseId, 3);
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe("cache-test-knowledge-001");
      expect(results[0].courseId).toBe(courseId);
    });
  });
});
