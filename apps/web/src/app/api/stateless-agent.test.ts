import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { middleware } from "../../middleware";
import { POST as chat } from "./chat/route";
import { POST as xiaoyiTutor } from "./xiaoyi/tutor/route";
import { GET as health } from "./health/route";
import { POST as searchKnowledge } from "./knowledge/search/route";
import { GET as getProfile } from "./profile/route";
import { POST as generateQuiz } from "./quiz/route";
import { store } from "@/lib/store/db";

const originalModelKey = process.env.MODEL_API_KEY;
const originalDeploymentMode = process.env.DEPLOYMENT_MODE;

afterEach(() => {
  vi.unstubAllEnvs();
  delete process.env.TEST_MODEL_RESPONSE;
  if (originalModelKey === undefined) delete process.env.MODEL_API_KEY;
  else process.env.MODEL_API_KEY = originalModelKey;

  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;
  vi.restoreAllMocks();
});

async function getProfileThroughGateway(request: NextRequest): Promise<Response> {
  const gatewayResponse = middleware(request);
  if (gatewayResponse.headers.get("x-middleware-next") !== "1") {
    return gatewayResponse;
  }
  return getProfile(request);
}

describe("无状态真实 Agent 边界", () => {
  it("小艺独立入口用真实流式编排固定回答课程概念", async () => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = "二叉搜索树让左子树键值小于根，右子树键值大于根。";
    const response = await xiaoyiTutor(new NextRequest("http://localhost/api/xiaoyi/tutor", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mode: "xiaoyi_tutor", message: "解释二叉搜索树并给我出题和计划" }),
    }));
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('"agent":"Tutor"');
    expect(body).not.toContain('"agent":"Planner"');
    expect(body).not.toContain('"agent":"Quiz"');
    expect(body).toContain('"type":"delta"');
    expect(body).toContain('"type":"done"');
  });

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

  it("无状态健康检查应公开精确部署模式", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";

    const response = await health();
    const body = await response.json();

    expect(body.deploymentMode).toBe("stateless");
    expect(body.persistence).toEqual({ mode: "stateless" });
  });

  it("生产环境未设置部署模式时应默认禁用状态路由", async () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("DEPLOYMENT_MODE", undefined);

    const profileResponse = await getProfileThroughGateway(
      new NextRequest("http://localhost/api/profile?userId=demo")
    );
    const healthResponse = await health();

    expect(profileResponse.status).toBe(404);
    await expect(profileResponse.json()).resolves.toEqual({
      error: "该接口在无状态部署中不可用",
      code: "ENDPOINT_DISABLED",
    });
    await expect(healthResponse.json()).resolves.toMatchObject({
      deploymentMode: "stateless",
      persistence: { mode: "stateless" },
    });
  });

  it("无状态测验生成应返回评分包但不写入进程内测验状态", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      type: "choice",
      stem: "二叉搜索树中序遍历的结果是什么？",
      options: ["A. 升序序列", "B. 降序序列", "C. 随机序列", "D. 层序序列"],
      answer: "A",
      explanation: "二叉搜索树的中序遍历会按键值从小到大访问节点。",
      tags: ["遍历顺序"],
    }]);
    const saveQuiz = vi.spyOn(store, "saveQuiz");

    const response = await generateQuiz(new Request("http://localhost/api/quiz", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: "demo",
        courseId: "cs101",
        topic: "二叉树与BST",
        count: 1,
        difficulty: "medium",
      }),
    }));
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.questions).toHaveLength(1);
    expect(body.grading).toHaveLength(1);
    expect(saveQuiz).not.toHaveBeenCalled();
  });

  it("无状态知识检索不记录用户活动", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    const logActivity = vi.spyOn(store, "logActivity");

    const response = await searchKnowledge(new Request("http://localhost/api/knowledge/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: "demo",
        courseId: "cs101",
        query: "二叉搜索树",
        topK: 3,
      }),
    }));
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(Array.isArray(body.chunks)).toBe(true);
    expect(logActivity).not.toHaveBeenCalled();
  });
});
