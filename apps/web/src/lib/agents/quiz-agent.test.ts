import { afterEach, describe, expect, it } from "vitest";

import { runQuizAgent } from "./quiz-agent";

const originalModelResponse = process.env.TEST_MODEL_RESPONSE;
const originalModelResponseSequence = process.env.TEST_MODEL_RESPONSE_SEQUENCE;
const originalModelResponseSequenceScope = process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE;

function modelQuestion(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    type: "choice",
    stem: "二叉搜索树中序遍历的结果是什么？",
    options: ["A. 升序序列", "B. 降序序列", "C. 随机序列", "D. 层序序列"],
    answer: "A",
    explanation: "二叉搜索树的中序遍历会按键值从小到大访问节点。",
    tags: ["遍历顺序"],
    ...overrides,
  };
}

async function expectInvalidModelResponse(payload: unknown) {
  process.env.TEST_MODEL_RESPONSE = JSON.stringify(payload);
  await expect(
    runQuizAgent("quiz_test", "cs101", "二叉树与BST", 1, "medium")
  ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
}

afterEach(() => {
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
  if (originalModelResponseSequence === undefined) delete process.env.TEST_MODEL_RESPONSE_SEQUENCE;
  else process.env.TEST_MODEL_RESPONSE_SEQUENCE = originalModelResponseSequence;
  if (originalModelResponseSequenceScope === undefined) {
    delete process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE;
  } else {
    process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = originalModelResponseSequenceScope;
  }
});

describe("Quiz Agent 模型输出边界", () => {
  it("修复后仍不足完整批次时立即拒绝而不继续放大模型调用", async () => {
    process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = "重点标签：批次预算";
    process.env.TEST_MODEL_RESPONSE_SEQUENCE = JSON.stringify([
      [modelQuestion()],
      [modelQuestion({ stem: "平衡二叉树的高度约束是什么？" })],
    ]);

    await expect(
      runQuizAgent("quiz_test", "cs101", "二叉树与BST", 5, "medium", "批次预算")
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
    expect(JSON.parse(process.env.TEST_MODEL_RESPONSE_SEQUENCE ?? "null")).toEqual([]);
  });

  it("同批重复题修复后仍重复时立即拒绝", async () => {
    process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = "重点标签：重复预算";
    const duplicateBatch = Array.from({ length: 5 }, () => modelQuestion());
    process.env.TEST_MODEL_RESPONSE_SEQUENCE = JSON.stringify([
      duplicateBatch,
      duplicateBatch,
    ]);

    await expect(
      runQuizAgent("quiz_test", "cs101", "二叉树与BST", 5, "medium", "重复预算")
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
    expect(JSON.parse(process.env.TEST_MODEL_RESPONSE_SEQUENCE ?? "null")).toEqual([]);
  });

  it("拒绝超过用户请求总量的题目而不是静默截断", async () => {
    await expectInvalidModelResponse([
      modelQuestion(),
      modelQuestion({ stem: "平衡二叉树的高度约束是什么？" }),
    ]);
  });

  it.each([
    ["非 choice 题型", modelQuestion({ type: "short" })],
    ["缺失标签数组", modelQuestion({ tags: undefined })],
    ["非字符串标签", modelQuestion({ tags: [123] })],
    ["超过三项的标签", modelQuestion({ tags: ["概念", "遍历", "性质", "边界"] })],
    ["超过十二字符的标签", modelQuestion({ tags: ["标".repeat(13)] })],
    ["超过五百字符的题干", modelQuestion({ stem: "题".repeat(501) })],
    [
      "超过二百字符的选项",
      modelQuestion({
        options: [
          `A. ${"选".repeat(198)}`,
          "B. 降序序列",
          "C. 随机序列",
          "D. 层序序列",
        ],
      }),
    ],
    ["超过一千字符的解析", modelQuestion({ explanation: "解".repeat(1001) })],
  ])("拒绝%s", async (_name, question) => {
    await expectInvalidModelResponse([question]);
  });
});
