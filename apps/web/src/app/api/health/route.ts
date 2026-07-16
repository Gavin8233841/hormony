// GET /api/health — 服务健康检查

import { getModelRuntimeInfo } from "@/lib/agents/model";
import { getDeploymentMode, isStatelessDeployment } from "@/lib/deployment";
import { isAppStatePersistenceEnabled } from "@/lib/store/persistence";

export const dynamic = "force-dynamic";

export async function GET() {
  const modelInfo = getModelRuntimeInfo();
  const status = modelInfo.configured ? "ready" : "degraded";
  const persistenceMode = isStatelessDeployment()
    ? "stateless"
    : isAppStatePersistenceEnabled()
      ? "file"
      : "disabled";

  return Response.json({
    status,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    model: {
      configured: modelInfo.configured,
      mode: modelInfo.mode,
      provider: modelInfo.provider,
      name: modelInfo.modelName,
    },
    deploymentMode: getDeploymentMode(),
    persistence: {
      mode: persistenceMode,
    },
    version: "1.0.1",
  }, { status: modelInfo.configured ? 200 : 503 });
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
