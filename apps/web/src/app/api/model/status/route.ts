// GET /api/model/status - 模型服务端配置状态，不返回任何密钥

import { getModelRuntimeInfo } from "@/lib/agents/model";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json(getModelRuntimeInfo());
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
