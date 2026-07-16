import { LessonProgress } from '../model/DataModels';

export interface CourseResumeState {
  startedTopics: string[];
  completedTopics: string[];
  recentTopic: string;
}

export function resolveCourseResumeState(courseId: string, topics: string[],
  progressItems: LessonProgress[]): CourseResumeState {
  const startedTopics: string[] = [];
  const completedTopics: string[] = [];
  let recentTopic = '';
  let recentUpdatedAt = '';

  for (const item of progressItems) {
    if (item.courseId !== courseId || !topics.includes(item.topic) || item.completedChunkIds.length === 0) continue;
    if (!startedTopics.includes(item.topic)) startedTopics.push(item.topic);
    if (item.completedAt !== undefined) {
      if (!completedTopics.includes(item.topic)) completedTopics.push(item.topic);
      continue;
    }
    if (recentTopic.length === 0 || item.updatedAt > recentUpdatedAt) {
      recentTopic = item.topic;
      recentUpdatedAt = item.updatedAt;
    }
  }

  return {
    startedTopics: startedTopics,
    completedTopics: completedTopics,
    recentTopic: recentTopic
  };
}

export function hasCourseStarted(state: CourseResumeState): boolean {
  return state.startedTopics.length > 0;
}

export function resolveNextTopic(topics: string[], completedTopics: string[], state: CourseResumeState): string {
  if (state.recentTopic.length > 0 && !completedTopics.includes(state.recentTopic)) return state.recentTopic;
  return topics.find((topic: string): boolean => !completedTopics.includes(topic)) ?? '';
}

export function resolveTopicAction(topic: string, completedTopics: string[], nextTopic: string,
  state: CourseResumeState): string {
  if (completedTopics.includes(topic)) return '复习';
  if (state.startedTopics.includes(topic)) return '继续';
  if (topic === nextTopic) return '开始';
  return '预览';
}
