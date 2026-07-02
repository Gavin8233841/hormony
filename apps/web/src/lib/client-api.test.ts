import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  ApiError,
  requestJson,
  getErrorMessage,
  isNotFound,
  isEndpointDisabled,
} from "./client-api";

// Mock global fetch
const fetchMock = vi.fn();
vi.stubGlobal("fetch", fetchMock);

// Mock DOMException for Node environment
class MockDOMException extends Error {
  readonly name: string;
  constructor(message: string, name: string) {
    super(message);
    this.name = name;
  }
}
vi.stubGlobal("DOMException", MockDOMException);

function mockResponse(body: string, init: { status: number; ok: boolean; headers?: Record<string, string> }) {
  return {
    ok: init.ok,
    status: init.status,
    text: async () => body,
    headers: new Map(Object.entries(init.headers ?? {})),
  } as unknown as Response;
}

beforeEach(() => {
  fetchMock.mockReset();
});

afterEach(() => {
  vi.clearAllMocks();
});

describe("requestJson", () => {
  it("200 JSON 成功响应 — 返回解析后的数据", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(JSON.stringify({ name: "test", value: 42 }), { status: 200, ok: true })
    );

    const result = await requestJson<{ name: string; value: number }>("/api/test");
    expect(result.name).toBe("test");
    expect(result.value).toBe(42);
  });

  it("201 JSON 成功响应 — 返回解析后的数据", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(JSON.stringify({ id: "abc", created: true }), { status: 201, ok: true })
    );

    const result = await requestJson<{ id: string; created: boolean }>("/api/test", {
      method: "POST",
    });
    expect(result.id).toBe("abc");
    expect(result.created).toBe(true);
  });

  it("400 `{ error, code }` — 抛出 ApiError 保留 status、code、message", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "缺少课程名称", code: "MISSING_FIELD" }),
        { status: 400, ok: false }
      )
    );

    try {
      await requestJson("/api/test", { method: "POST" });
      expect.fail("Should have thrown");
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      const apiError = e as ApiError;
      expect(apiError.status).toBe(400);
      expect(apiError.code).toBe("MISSING_FIELD");
      expect(apiError.message).toBe("缺少课程名称");
    }
  });

  it("404 `NOT_FOUND` — 抛出 ApiError 且 code 为 NOT_FOUND", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "未找到学习计划", code: "NOT_FOUND" }),
        { status: 404, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(404);
      expect(apiError.code).toBe("NOT_FOUND");
      expect(apiError.message).toBe("未找到学习计划");
    }
  });

  it("404 `ENDPOINT_DISABLED` — 抛出 ApiError 且 code 为 ENDPOINT_DISABLED", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "学习计划仅保存在 HarmonyOS 设备", code: "ENDPOINT_DISABLED" }),
        { status: 404, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(404);
      expect(apiError.code).toBe("ENDPOINT_DISABLED");
      expect(apiError.message).toBe("学习计划仅保存在 HarmonyOS 设备");
    }
  });

  it("429 `RATE_LIMITED` — 抛出 ApiError 保留服务端错误信息", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "请求过于频繁，请稍后再试", code: "RATE_LIMITED" }),
        { status: 429, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(429);
      expect(apiError.code).toBe("RATE_LIMITED");
      expect(apiError.message).toBe("请求过于频繁，请稍后再试");
    }
  });

  it("500 非 JSON 响应 — 抛出 ApiError 使用包含 HTTP 状态的通用消息", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse("Internal Server Error", { status: 500, ok: false })
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(500);
      expect(apiError.code).toBeNull();
      expect(apiError.message).toContain("500");
    }
  });

  it("500 非对象 JSON 响应 — 不把未知结构当作服务端错误契约", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(JSON.stringify(["bad shape"]), { status: 500, ok: false })
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(500);
      expect(apiError.code).toBeNull();
      expect(apiError.message).toContain("500");
    }
  });

  it("400 非字符串 error/code — 使用通用消息且不保留非法 code", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: { message: "bad" }, code: 123 }),
        { status: 400, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(400);
      expect(apiError.code).toBeNull();
      expect(apiError.message).toContain("400");
    }
  });

  it("200 非法 JSON 响应 — 抛出 ApiError", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse("not valid json {{{", { status: 200, ok: true })
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.code).toBe("INVALID_JSON");
      expect(apiError.message).toContain("非法 JSON");
    }
  });

  it("网络异常 — 直接抛出原始 Error，不包装为 ApiError", async () => {
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    const promise = requestJson("/api/test");
    await expect(promise).rejects.toThrow(TypeError);
    await expect(promise).rejects.not.toThrow(ApiError);
  });

  it("AbortError — 不被吞掉，直接向上抛出", async () => {
    const abortError = new MockDOMException("The user aborted a request.", "AbortError");
    fetchMock.mockRejectedValueOnce(abortError);

    await expect(requestJson("/api/test")).rejects.toThrow(MockDOMException);
  });

  it("status、code、message 完整保留 — 503 MODEL_UNAVAILABLE", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "云端学伴暂不可用，请稍后重试", code: "MODEL_UNAVAILABLE" }),
        { status: 503, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(503);
      expect(apiError.code).toBe("MODEL_UNAVAILABLE");
      expect(apiError.message).toBe("云端学伴暂不可用，请稍后重试");
    }
  });

  it("502 MODEL_INVALID_RESPONSE — 保留模型错误码", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(
        JSON.stringify({ error: "模型返回内容无效，请重新生成", code: "MODEL_INVALID_RESPONSE" }),
        { status: 502, ok: false }
      )
    );

    try {
      await requestJson("/api/test");
      expect.fail("Should have thrown");
    } catch (e) {
      const apiError = e as ApiError;
      expect(apiError.status).toBe(502);
      expect(apiError.code).toBe("MODEL_INVALID_RESPONSE");
    }
  });
});

describe("getErrorMessage", () => {
  it("ApiError 返回服务端消息", () => {
    const error = new ApiError(400, "MISSING_FIELD", "缺少课程名称");
    expect(getErrorMessage(error, "回退消息")).toBe("缺少课程名称");
  });

  it("AbortError 返回 null（不应显示为业务失败）", () => {
    const abortError = new MockDOMException("aborted", "AbortError");
    expect(getErrorMessage(abortError, "回退消息")).toBeNull();
  });

  it("普通 Error 返回 message", () => {
    const error = new Error("网络连接失败");
    expect(getErrorMessage(error, "回退消息")).toBe("网络连接失败");
  });

  it("未知错误使用调用方提供的中文回退文本", () => {
    expect(getErrorMessage("string error", "加载失败")).toBe("加载失败");
    expect(getErrorMessage(null, "加载失败")).toBe("加载失败");
    expect(getErrorMessage(undefined, "加载失败")).toBe("加载失败");
    expect(getErrorMessage({ random: "object" }, "加载失败")).toBe("加载失败");
  });
});

describe("isNotFound", () => {
  it("NOT_FOUND 错误返回 true", () => {
    const error = new ApiError(404, "NOT_FOUND", "未找到");
    expect(isNotFound(error)).toBe(true);
  });

  it("其他错误返回 false", () => {
    const error = new ApiError(404, "ENDPOINT_DISABLED", "禁用");
    expect(isNotFound(error)).toBe(false);
  });

  it("非 ApiError 返回 false", () => {
    expect(isNotFound(new Error("普通错误"))).toBe(false);
    expect(isNotFound(null)).toBe(false);
  });
});

describe("isEndpointDisabled", () => {
  it("ENDPOINT_DISABLED 错误返回 true", () => {
    const error = new ApiError(404, "ENDPOINT_DISABLED", "禁用");
    expect(isEndpointDisabled(error)).toBe(true);
  });

  it("其他错误返回 false", () => {
    const error = new ApiError(404, "NOT_FOUND", "未找到");
    expect(isEndpointDisabled(error)).toBe(false);
  });

  it("非 ApiError 返回 false", () => {
    expect(isEndpointDisabled(new Error("普通错误"))).toBe(false);
  });
});
