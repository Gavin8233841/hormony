import { beforeEach, describe, expect, it, vi } from "vitest";

const modelMock = vi.hoisted(() => ({
  callModel: vi.fn(async (_systemPrompt: string, _userPrompt: string) => "讲解内容"),
  callModelWithHistory: vi.fn(async () => "讲解内容"),
}));

vi.mock("./model", () => modelMock);

import { runTutorAgent } from "./tutor-agent";

beforeEach(() => {
  modelMock.callModel.mockClear();
  modelMock.callModelWithHistory.mockClear();
});

describe("Tutor 入口的画像边界", () => {
  it("小艺概念讲解不把演示默认画像传给模型", async () => {
    await runTutorAgent("xiaoyi_guest", "什么是二叉搜索树？", "课程片段", [],
      undefined, {
        stage: "不应使用的阶段",
        weakTopics: [],
        strongTopics: [],
        learningStyle: "不应使用的风格",
        stats: { totalQuestions: 3, accuracy: 0.67, studyDays: 2 },
      }, undefined, "concept");

    expect(modelMock.callModel).toHaveBeenCalledOnce();
    const userPrompt = modelMock.callModel.mock.calls[0][1];
    expect(userPrompt).toContain("课程片段");
    expect(userPrompt).toContain("什么是二叉搜索树？");
    expect(userPrompt).not.toContain("学生画像");
    expect(userPrompt).not.toContain("本科二年级");
    expect(userPrompt).not.toContain("不应使用的阶段");
  });

  it("原生普通讲解仍可使用已提供的学习画像", async () => {
    await runTutorAgent("demo", "解释数组", "课程片段", [], undefined, {
      stage: "大一",
      weakTopics: [],
      strongTopics: [],
      learningStyle: "图示学习",
      stats: { totalQuestions: 3, accuracy: 0.67, studyDays: 2 },
    });

    expect(modelMock.callModel).toHaveBeenCalledOnce();
    const userPrompt = modelMock.callModel.mock.calls[0][1];
    expect(userPrompt).toContain('"stage":"大一"');
    expect(userPrompt).toContain('"learningStyle":"图示学习"');
  });
});
