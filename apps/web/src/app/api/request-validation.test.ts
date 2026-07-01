import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";

import { POST as postChat } from "./chat/route";
import { POST as postCourse } from "./courses/route";
import { POST as searchKnowledge } from "./knowledge/search/route";
import { POST as uploadKnowledge } from "./knowledge/upload/route";
import { POST as postPlan } from "./plan/route";
import { PATCH as updatePlanTask, POST as savePlan } from "./plan/save/route";
import { PUT as updateProfile } from "./profile/update/route";
import { POST as postQuiz } from "./quiz/route";
import { POST as submitQuiz } from "./quiz/submit/route";
import { POST as reviewSafety } from "./safety-review/route";

type RequestHandler = (request: Request) => Promise<Response>;

const objectBodyRoutes: Array<{
  name: string;
  method: string;
  handler: RequestHandler;
}> = [
  { name: "chat POST", method: "POST", handler: (request) => postChat(request as NextRequest) },
  { name: "courses POST", method: "POST", handler: postCourse },
  { name: "knowledge search POST", method: "POST", handler: searchKnowledge },
  { name: "knowledge upload POST", method: "POST", handler: uploadKnowledge },
  { name: "plan POST", method: "POST", handler: postPlan },
  { name: "plan save POST", method: "POST", handler: savePlan },
  { name: "plan save PATCH", method: "PATCH", handler: updatePlanTask },
  { name: "profile update PUT", method: "PUT", handler: updateProfile },
  { name: "quiz POST", method: "POST", handler: postQuiz },
  { name: "quiz submit POST", method: "POST", handler: submitQuiz },
  { name: "safety review POST", method: "POST", handler: reviewSafety },
];

describe("API request validation", () => {
  it.each(objectBodyRoutes)(
    "$name rejects non-object JSON",
    async ({ method, handler }) => {
      const response = await handler(new Request("http://localhost/api/test", {
        method,
        headers: { "Content-Type": "application/json" },
        body: "null",
      }));

      expect(response.status).toBe(400);
      await expect(response.json()).resolves.toEqual({
        error: "JSON 请求体必须是对象",
        code: "BAD_REQUEST",
      });
    }
  );

  it("rejects a whitespace-only chat message", async () => {
    const request = new NextRequest("http://localhost/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: "demo", message: "   " }),
    });

    const response = await postChat(request);
    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ code: "MISSING_FIELD" });
  });

  it("rejects a missing plan goal", async () => {
    const request = new Request("http://localhost/api/plan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: "demo", durationDays: 14 }),
    });

    const response = await postPlan(request);
    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ code: "MISSING_FIELD" });
  });

  it.each([
    {
      name: "chat context",
      handler: (request: Request) => postChat(request as NextRequest),
      body: { message: "解释二叉树", context: [] },
      code: "INVALID_CONTEXT",
    },
    {
      name: "chat history",
      handler: (request: Request) => postChat(request as NextRequest),
      body: { message: "解释二叉树", history: [null] },
      code: "INVALID_HISTORY",
    },
    {
      name: "plan tasks",
      handler: savePlan,
      body: { goal: "复习数据结构", tasks: [null] },
      code: "INVALID_TASKS",
    },
    {
      name: "quiz answers",
      handler: submitQuiz,
      body: { quizId: "quiz_test", answers: [null] },
      code: "INVALID_ANSWERS",
    },
    {
      name: "safety citations",
      handler: reviewSafety,
      body: { content: "普通内容", citations: [null] },
      code: "INVALID_CITATIONS",
    },
  ])("rejects malformed nested $name", async ({ handler, body, code }) => {
    const response = await handler(new Request("http://localhost/api/test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ code });
  });
});
