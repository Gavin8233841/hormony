import { describe, expect, it } from "vitest";

import { readJsonObject } from "./request-json";

const MAX_JSON_BODY_BYTES = 256 * 1024;
const textEncoder = new TextEncoder();

function request(body: string, contentLength?: string): Request {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (contentLength !== undefined) headers.set("Content-Length", contentLength);

  return new Request("http://localhost/api/test", {
    method: "POST",
    headers,
    body,
  });
}

function jsonObjectWithByteLength(byteLength: number): string {
  const prefix = '{"content":"学';
  const suffix = '"}';
  const fixedBytes = textEncoder.encode(`${prefix}${suffix}`).byteLength;
  return `${prefix}${"a".repeat(byteLength - fixedBytes)}${suffix}`;
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

  it.each([
    ["without Content-Length", undefined],
    ["with Content-Length at the limit", String(MAX_JSON_BODY_BYTES)],
  ])("accepts a valid UTF-8 object exactly at 256 KiB %s", async (_name, contentLength) => {
    const body = jsonObjectWithByteLength(MAX_JSON_BODY_BYTES);
    expect(textEncoder.encode(body).byteLength).toBe(MAX_JSON_BODY_BYTES);

    const result = await readJsonObject<Record<string, unknown>>(request(body, contentLength));

    expect(result.ok).toBe(true);
    if (result.ok) expect(result.body.content).toEqual(expect.stringMatching(/^学/));
  });

  it("rejects an oversized Content-Length before parsing the body", async () => {
    const result = await readJsonObject<Record<string, unknown>>(
      request("{", String(MAX_JSON_BODY_BYTES + 1))
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.status).toBe(413);
      await expect(result.response.json()).resolves.toEqual({
        error: "JSON 请求体过大",
        code: "PAYLOAD_TOO_LARGE",
      });
    }
  });

  it.each([
    ["missing", undefined],
    ["malformed", "not-a-number"],
    ["falsely small", "2"],
  ])("rejects a UTF-8 body one byte over the limit with %s Content-Length", async (_name, contentLength) => {
    const body = jsonObjectWithByteLength(MAX_JSON_BODY_BYTES + 1);
    expect(textEncoder.encode(body).byteLength).toBe(MAX_JSON_BODY_BYTES + 1);

    const input = request(body, contentLength);
    expect(input.headers.get("Content-Length")).toBe(contentLength ?? null);

    const result = await readJsonObject<Record<string, unknown>>(input);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.status).toBe(413);
      await expect(result.response.json()).resolves.toEqual({
        error: "JSON 请求体过大",
        code: "PAYLOAD_TOO_LARGE",
      });
    }
  });
});
