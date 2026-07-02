import {
  KnowledgeUnavailableError,
  ModelCancelledError,
  ModelInvalidResponseError,
  ModelTimeoutError,
  ModelUnavailableError,
} from "@/lib/agents/model";

export class SafetyBlockedError extends Error {
  readonly code = "SAFETY_BLOCKED";

  constructor(message = "模型输出未通过安全审核") {
    super(message);
    this.name = "SafetyBlockedError";
  }
}

export function modelErrorResponse(error: unknown): Response {
  if (error instanceof SafetyBlockedError) {
    return Response.json(
      { error: "模型输出未通过安全审核，请重新生成", code: error.code },
      { status: 502 }
    );
  }
  if (error instanceof ModelCancelledError) {
    return Response.json(
      { error: "模型请求已取消", code: error.code },
      { status: 499 }
    );
  }
  if (error instanceof ModelUnavailableError) {
    return Response.json(
      { error: "云端学伴暂不可用，请稍后重试", code: error.code },
      { status: 503 }
    );
  }
  if (error instanceof ModelTimeoutError) {
    return Response.json(
      { error: "模型请求超时，请稍后重试", code: error.code },
      { status: 504 }
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
  if (
    error instanceof KnowledgeUnavailableError ||
    (error instanceof Error && error.message.startsWith("KNOWLEDGE_UNAVAILABLE:"))
  ) {
    return Response.json(
      { error: "当前主题缺少课程资料，请换一个主题重试", code: "KNOWLEDGE_UNAVAILABLE" },
      { status: 404 }
    );
  }
  return Response.json(
    { error: "服务处理异常，请稍后重试", code: "INTERNAL_ERROR" },
    { status: 500 }
  );
}
