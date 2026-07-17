import { afterEach, describe, expect, it, vi } from "vitest";
import { retrieve } from "@/lib/rag";
import { POST } from "./route";

vi.mock("@/lib/rag", () => ({
  retrieve: vi.fn(),
}));

const retrieveMock = vi.mocked(retrieve);

afterEach(() => {
  retrieveMock.mockReset();
  vi.unstubAllEnvs();
});

function searchRequest(courseId: string): Request {
  return new Request("http://localhost/api/knowledge/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId: "demo",
      query: "二叉搜索树",
      courseId,
      topK: 3,
    }),
  });
}

describe("POST /api/knowledge/search 课程隔离与输出安全", () => {
  it("应拒绝检索层意外返回的跨课程切片", async () => {
    vi.stubEnv("DEPLOYMENT_MODE", "stateless");
    retrieveMock.mockReturnValue([{
      id: "cross-course-chunk",
      text: "进程调度算法决定就绪进程的运行顺序。",
      source: "操作系统课程资料",
      courseId: "cs102",
    }]);

    const response = await POST(searchRequest("cs101"));

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      error: "检索失败",
      code: "INTERNAL_ERROR",
    });
  });

  it("应拒绝与课程 Topic 目录不一致的切片", async () => {
    vi.stubEnv("DEPLOYMENT_MODE", "stateless");
    retrieveMock.mockReturnValue([{
      id: "invalid-topic-chunk",
      text: "二叉搜索树的左子树节点值小于根节点值。",
      source: "数据结构课程资料",
      courseId: "cs101",
      topic: "CPU调度算法",
    }]);

    const response = await POST(searchRequest("cs101"));

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      error: "检索失败",
      code: "INTERNAL_ERROR",
    });
  });

  it("应以明确错误码阻断未通过输出 Safety 的同课程切片", async () => {
    vi.stubEnv("DEPLOYMENT_MODE", "stateless");
    retrieveMock.mockReturnValue([{
      id: "unsafe-course-chunk",
      text: "暴力伤害他人的具体步骤",
      source: "数据结构课程资料",
      courseId: "cs101",
    }]);

    const response = await POST(searchRequest("cs101"));

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({
      error: "检索结果未通过安全审核",
      code: "SAFETY_BLOCKED",
    });
  });
});
