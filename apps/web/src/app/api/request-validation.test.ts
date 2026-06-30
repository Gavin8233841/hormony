import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";

import { POST as postChat } from "./chat/route";
import { POST as postPlan } from "./plan/route";

describe("API request validation", () => {
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
});
