import {
  ModelInvalidResponseError,
  ModelUnavailableError,
} from "@/lib/agents/model";

export function modelErrorResponse(error: unknown): Response {
  if (error instanceof ModelUnavailableError) {
    return Response.json(
      { error: "云端学伴暂不可用，请稍后重试", code: error.code },
      { status: 503 }
    );
  }
  if (
    error instanceof ModelInvalidResponseError ||
    (error instanceof Error && error.message.startsWith("MODEL_INVALID_RESPONSE:"))
  ) {
    return Response.json(
      { error: "模型返回内容无效，请重新生成", code: "MODEL_INVALID_RESPONSE" },
      { status: 502 }
    );
  }
  return Response.json(
    { error: "服务处理异常，请稍后重试", code: "INTERNAL_ERROR" },
    { status: 500 }
  );
}
