// POST /api/quiz — 生成测验题

import { runQuizAgent } from "@/lib/agents/quiz-agent";

export async function POST(req: Request) {
  let body: {
    userId?: string;
    courseId?: string;
    topic?: string;
    count?: number;
    difficulty?: "easy" | "medium" | "hard";
  };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "无效的 JSON", code: "BAD_REQUEST" }, { status: 400 });
  }

  const userId = body.userId ?? "demo";
  const courseId = body.courseId ?? "cs101";
  const topic = body.topic ?? "综合";
  const count = body.count ?? 5;
  const difficulty = body.difficulty ?? "medium";

  const quiz = await runQuizAgent(userId, courseId, topic, count, difficulty);
  return Response.json(quiz);
}
