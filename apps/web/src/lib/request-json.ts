export type JsonObjectResult<T extends object> =
  | { ok: true; body: T }
  | { ok: false; response: Response };

export function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export async function readJsonObject<T extends object>(
  request: Request
): Promise<JsonObjectResult<T>> {
  let value: unknown;
  try {
    value = await request.json();
  } catch {
    return {
      ok: false,
      response: Response.json(
        { error: "无效的 JSON 请求体", code: "BAD_REQUEST" },
        { status: 400 }
      ),
    };
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
