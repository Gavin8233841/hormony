import { describe, it, expect } from "vitest";
import { generateId } from "@/lib/utils";
import { extractJsonPayload } from "@/lib/agents/model";

describe("工具函数", () => {
  describe("generateId()", () => {
    it("应生成带前缀的 ID", () => {
      const id = generateId("test");
      expect(id).toMatch(/^test_/);
    });

    it("默认前缀应为 id", () => {
      const id = generateId();
      expect(id).toMatch(/^id_/);
    });

    it("每次调用应生成不同的 ID", () => {
      const id1 = generateId("test");
      const id2 = generateId("test");
      expect(id1).not.toBe(id2);
    });
  });

  describe("extractJsonPayload()", () => {
    it("应提取纯 JSON 数组", () => {
      const input = '[{"a":1},{"b":2}]';
      expect(extractJsonPayload(input)).toBe(input);
    });

    it("应提取纯 JSON 对象", () => {
      const input = '{"a":1,"b":2}';
      expect(extractJsonPayload(input)).toBe(input);
    });

    it("应从 Markdown 代码块中提取 JSON", () => {
      const input = '```json\n[{"a":1}]\n```';
      expect(extractJsonPayload(input)).toBe('[{"a":1}]');
    });

    it("应从无语言标记的代码块中提取", () => {
      const input = '```\n{"a":1}\n```';
      expect(extractJsonPayload(input)).toBe('{"a":1}');
    });

    it("应从带说明文字的输出中提取 JSON 数组", () => {
      const input = '以下是生成的题目：\n[{"stem":"题目1"}]\n以上是题目。';
      const result = extractJsonPayload(input);
      expect(result).toBe('[{"stem":"题目1"}]');
    });

    it("应从带说明文字的输出中提取 JSON 对象", () => {
      const input = '结果是：\n{"answer":"A"}\n完毕';
      const result = extractJsonPayload(input);
      expect(result).toBe('{"answer":"A"}');
    });

    it("无 JSON 内容时应返回原文", () => {
      const input = "这是一段纯文本";
      expect(extractJsonPayload(input)).toBe("这是一段纯文本");
    });
  });
});

describe("Profile Agent", () => {
  it("runProfileAgent 应返回演示用户画像", async () => {
    const { runProfileAgent } = await import("@/lib/agents/profile-agent");
    const result = await runProfileAgent("demo");
    expect(result.agent).toBe("Profile");
    expect(result.content).toContain("演示同学");
    expect(result.metadata).toBeDefined();
  });

  it("getProfileContext 应返回部分画像字段", async () => {
    const { getProfileContext } = await import("@/lib/agents/profile-agent");
    const ctx = getProfileContext("demo");
    expect(ctx.stage).toBeDefined();
    expect(ctx.weakTopics).toBeDefined();
    expect(ctx.learningStyle).toBeDefined();
  });
});
