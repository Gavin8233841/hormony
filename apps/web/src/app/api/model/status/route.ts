// GET /api/model/status - 只返回非敏感的模型联调状态

import { getModelRuntimeInfo } from "@/lib/agents/model";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const {
    configured,
    mode,
    provider,
    modelName,
    timeoutMs,
  } = getModelRuntimeInfo();

  return Response.json({
    configured,
    mode,
    provider,
    modelName,
    timeoutMs,
  });
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
