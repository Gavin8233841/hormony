// Planner Agent：学习计划生成与任务拆解

import { callModel, extractJsonPayload } from "./model";
import { getProfileContext } from "./profile-agent";
import { allQuizzes } from "@/lib/data";
import { generateId } from "@/lib/utils";
import type { LearningProfileSnapshot, PlanTask, StudyPlan } from "@/lib/types";

type PlanAction = "lesson" | "practice" | "quiz" | "review";

interface TopicOption {
  courseId: string;
  courseTitle: string;
  topic: string;
}

interface ParsedPlanItem {
  courseId: string;
  courseTitle: string;
  topic: string;
  action: PlanAction;
  title: string;
  estimatedMin: number;
}

const COURSE_TITLES: Record<string, string> = {
  cs101: "数据结构",
  cs102: "操作系统",
  cs103: "计算机网络",
};

const ACTIONS: PlanAction[] = ["lesson", "practice", "quiz", "review"];

const ACTION_TYPES: Record<PlanAction, PlanTask["type"]> = {
  lesson: "reading",
  practice: "practice",
  quiz: "quiz",
  review: "review",
};

const ACTION_LABELS: Record<PlanAction, string> = {
  lesson: "学习",
  practice: "练习",
  quiz: "测验",
  review: "复盘",
};

export async function runPlannerAgent(
  userId: string,
  goal: string,
  durationDays: number,
  dailyMinutes: number,
  profileSnapshot?: LearningProfileSnapshot
): Promise<StudyPlan> {
  const profile = getProfileContext(profileSnapshot);
  const startDate = new Date().toISOString().slice(0, 10);
  const topicOptions = getTopicOptions();
  const topicCatalog = formatTopicCatalog(topicOptions);

  const systemPrompt = `你是一位学习规划专家。根据学生画像和学习目标，制定结构化学习计划。
输出 JSON 数组，每个元素格式：{"courseId":"cs101","topic":"数组与线性表","action":"lesson|practice|quiz|review","title":"","estimatedMin":45}
courseId 和 topic 必须从下方清单逐字选择，不能改写、缩写或新增主题。
action 含义：lesson=学习讲解，practice=本地练习，quiz=AI出题测验，review=错题复盘。
计划从 ${startDate} 开始，所有日期必须位于接下来 ${durationDays} 天内。
只输出 JSON，不要额外文字。

可选主题清单：
${topicCatalog}`;

  const userPrompt = `学生画像：${JSON.stringify(profile)}
目标：${goal}
周期：${durationDays} 天
每日可用时间：${dailyMinutes} 分钟
请生成 ${Math.min(durationDays, 10)} 个关键任务。`;

  const raw = await callModel(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 1200 });

  const tasks = parseTasks(raw, startDate, durationDays, topicOptions);
  if (tasks.length === 0) {
    throw new Error("MODEL_INVALID_RESPONSE: 学习计划不是有效 JSON");
  }

  const plan: StudyPlan = {
    planId: generateId("plan"),
    userId,
    goal,
    tasks,
  };
  return plan;
}

function parseTasks(raw: string, startDate: string, durationDays: number, topicOptions: TopicOption[]): PlanTask[] {
  try {
    const arr = JSON.parse(extractJsonPayload(raw));
    if (Array.isArray(arr)) {
      const selected = arr.slice(0, 10);
      const startTime = Date.parse(startDate + "T00:00:00.000Z");
      const parsedItems: ParsedPlanItem[] = [];
      for (const item of selected) {
        if (!item || typeof item !== "object") continue;
        const t = item as Record<string, unknown>;
        const courseId = typeof t.courseId === "string" ? t.courseId.trim() : "";
        const topic = typeof t.topic === "string" ? t.topic.trim() : "";
        const option = findTopicOption(courseId, topic, topicOptions);
        const rawAction = typeof t.action === "string" ? t.action.trim() : "";
        if (option === undefined || !isPlanAction(rawAction)) continue;
        const title = typeof t.title === "string" ? t.title.trim() : "";
        parsedItems.push({
          courseId: option.courseId,
          courseTitle: option.courseTitle,
          topic: option.topic,
          action: rawAction,
          title: title.length > 0 ? title : `${ACTION_LABELS[rawAction]}：${option.topic}`,
          estimatedMin: Math.min(Math.max(Number(t.estimatedMin) || 45, 15), 180),
        });
      }
      return parsedItems.map((item: ParsedPlanItem, i: number) => {
        const dayOffset = Math.min(durationDays - 1, Math.floor(i * durationDays / parsedItems.length));
        const taskDate = new Date(startTime + dayOffset * 86400000).toISOString().slice(0, 10);
        return {
          id: generateId("task"),
          title: item.title.slice(0, 120),
          date: taskDate,
          estimatedMin: item.estimatedMin,
          type: ACTION_TYPES[item.action],
          courseId: item.courseId,
          topic: item.topic,
          action: item.action,
        };
      });
    }
  } catch {
    return [];
  }
  return [];
}

function getTopicOptions(): TopicOption[] {
  const seen = new Set<string>();
  const options: TopicOption[] = [];
  for (const quiz of allQuizzes) {
    const courseTitle = COURSE_TITLES[quiz.courseId];
    if (!courseTitle) continue;
    const key = `${quiz.courseId}:${quiz.topic}`;
    if (seen.has(key)) continue;
    seen.add(key);
    options.push({
      courseId: quiz.courseId,
      courseTitle,
      topic: quiz.topic,
    });
  }
  return options;
}

function formatTopicCatalog(options: TopicOption[]): string {
  return Object.entries(COURSE_TITLES).map(([courseId, title]) => {
    const topics = options
      .filter((option) => option.courseId === courseId)
      .map((option) => option.topic)
      .join("、");
    return `${courseId} ${title}：${topics}`;
  }).join("\n");
}

function findTopicOption(courseId: string, topic: string, options: TopicOption[]): TopicOption | undefined {
  return options.find((option) => option.courseId === courseId && option.topic === topic);
}

function isPlanAction(value: string): value is PlanAction {
  return ACTIONS.some((action) => action === value);
}
