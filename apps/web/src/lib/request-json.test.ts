import { describe, expect, it } from "vitest";

import { readJsonObject } from "./request-json";

function request(body: string): Request {
  return new Request("http://localhost/api/test", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });
}

describe("readJsonObject", () => {
  it("accepts a JSON object", async () => {
    const result = await readJsonObject<{ message: string }>(
      request('{"message":"hello"}')
    );

    expect(result.ok).toBe(true);
    if (result.ok) expect(result.body).toEqual({ message: "hello" });
  });

  it.each(["null", "[]", '"text"', "1", "true"])(
    "rejects non-object JSON: %s",
    async (body) => {
      const result = await readJsonObject<Record<string, unknown>>(request(body));

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.response.status).toBe(400);
        await expect(result.response.json()).resolves.toEqual({
          error: "JSON 请求体必须是对象",
          code: "BAD_REQUEST",
        });
      }
    }
  );

  it("rejects malformed JSON", async () => {
    const result = await readJsonObject<Record<string, unknown>>(request("{"));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.status).toBe(400);
      await expect(result.response.json()).resolves.toEqual({
        error: "无效的 JSON 请求体",
        code: "BAD_REQUEST",
      });
    }
  });
});
