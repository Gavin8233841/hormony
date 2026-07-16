export type JsonObjectResult<T extends object> =
  | { ok: true; body: T }
  | { ok: false; response: Response };

type JsonErrorResult = { ok: false; response: Response };

const MAX_JSON_BODY_BYTES = 256 * 1024;

export function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export async function readJsonObject<T extends object>(
  request: Request
): Promise<JsonObjectResult<T>> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    const declaredBytes = Number(contentLength);
    if (Number.isFinite(declaredBytes) && declaredBytes > MAX_JSON_BODY_BYTES) {
      return payloadTooLarge();
    }
  }

  const body = await readBodyWithinLimit(request);
  if (!body.ok) return body;

  let value: unknown;
  try {
    value = JSON.parse(body.raw) as unknown;
  } catch {
    return invalidJsonBody();
  }

  if (!isJsonObject(value)) {
    return {
      ok: false,
      response: Response.json(
        { error: "JSON 请求体必须是对象", code: "BAD_REQUEST" },
        { status: 400 }
      ),
    };
  }

  return { ok: true, body: value as T };
}

async function readBodyWithinLimit(
  request: Request
): Promise<{ ok: true; raw: string } | { ok: false; response: Response }> {
  if (!request.body) return { ok: true, raw: "" };

  let reader: ReadableStreamDefaultReader<Uint8Array>;
  try {
    reader = request.body.getReader();
  } catch {
    return invalidJsonBody();
  }

  const decoder = new TextDecoder();
  let raw = "";
  let bytesRead = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytesRead += value.byteLength;
      if (bytesRead > MAX_JSON_BODY_BYTES) {
        try {
          await reader.cancel("JSON request body exceeds byte limit");
        } catch {
          // The producer may already have closed while the limit was detected.
        }
        return payloadTooLarge();
      }
      raw += decoder.decode(value, { stream: true });
    }
    raw += decoder.decode();
    return { ok: true, raw };
  } catch {
    return invalidJsonBody();
  } finally {
    reader.releaseLock();
  }
}

function invalidJsonBody(): JsonErrorResult {
  return {
    ok: false,
    response: Response.json(
      { error: "无效的 JSON 请求体", code: "BAD_REQUEST" },
      { status: 400 }
    ),
  };
}

function payloadTooLarge(): JsonErrorResult {
  return {
    ok: false,
    response: Response.json(
      { error: "JSON 请求体过大", code: "PAYLOAD_TOO_LARGE" },
      { status: 413 }
    ),
  };
}
