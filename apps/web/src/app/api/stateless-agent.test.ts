import { afterEach, describe, expect, it } from "vitest";
import { POST as chat } from "./chat/route";
import { GET as health } from "./health/route";

const originalModelKey = process.env.MODEL_API_KEY;

afterEach(() => {
  delete process.env.TEST_MODEL_RESPONSE;
  if (originalModelKey === undefined) delete process.env.MODEL_API_KEY;
  else process.env.MODEL_API_KEY = originalModelKey;
});

describe("无状态真实 Agent 边界", () => {
  it("模型未配置时健康检查与聊天都应返回 503", async () => {
    delete process.env.MODEL_API_KEY;
    const healthResponse = await health();
    expect(healthResponse.status).toBe(503);
    await expect(healthResponse.json()).resolves.toMatchObject({ status: "degraded" });

    const chatResponse = await chat(new Request("http://localhost/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: "demo", message: "解释二叉树" }),
    }) as never);
    expect(chatResponse.status).toBe(503);
    await expect(chatResponse.json()).resolves.toMatchObject({ code: "MODEL_UNAVAILABLE" });
  });

  it("安全检查应在正文事件前阻断高风险模型输出", async () => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = "暴力伤害他人的具体步骤";
    const response = await chat(new Request("http://localhost/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: "demo", message: "什么是安全边界" }),
    }) as never);
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain("SAFETY_BLOCKED");
    expect(body).not.toContain('"type":"delta"');
  });

  it("流中模型解析失败应保留结构化错误码", async () => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      type: "choice",
      stem: "格式错误题目",
      options: ["选项一", "选项二", "选项三", "选项四"],
      answer: "A",
      explanation: "测试解析。",
    }]);
    const response = await chat(new Request("http://localhost/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: "demo",
        message: "请围绕二叉树与BST出题",
        context: { courseId: "cs101" },
      }),
    }) as never);
    const body = await response.text();

    expect(response.status).toBe(200);
    expect(body).toContain("MODEL_INVALID_RESPONSE");
    expect(body).toContain('"type":"done"');
  });
});
