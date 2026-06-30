// GET /api/health — 服务健康检查

import { getModelRuntimeInfo } from "@/lib/agents/model";

export const dynamic = "force-dynamic";

export async function GET() {
  const modelInfo = getModelRuntimeInfo();
  const status = modelInfo.configured ? "ready" : "degraded";

  return Response.json({
    status,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    model: {
      configured: modelInfo.configured,
      mode: modelInfo.mode,
      provider: modelInfo.provider,
    },
    deploymentMode: process.env.DEPLOYMENT_MODE?.trim() || "development",
    version: "1.0.0",
  }, { status: modelInfo.configured ? 200 : 503 });
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
