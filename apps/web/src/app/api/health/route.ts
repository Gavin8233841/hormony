// GET /api/health — 服务健康检查

import { getModelRuntimeInfo } from "@/lib/agents/model";
import { store } from "@/lib/store/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const modelInfo = getModelRuntimeInfo();
  const stats = store.getStats("demo");

  return Response.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    model: {
      configured: modelInfo.configured,
      mode: modelInfo.mode,
      provider: modelInfo.provider,
    },
    data: {
      profiles: stats.totalQuestions >= 0 ? "loaded" : "empty",
      courses: stats.activeCourses,
      quizSubmissions: stats.totalQuizSubmissions,
    },
    version: "1.0.0",
  });
}

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}
