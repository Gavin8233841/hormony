import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const servicePath = path.resolve(scriptDirectory,
  '../apps/harmonyos/entry/src/main/ets/common/ProactiveLearningService.ets');
const dataModelsImport = "import { Course, PlanTask } from '../model/DataModels';";
const metadataModelsImport = `import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight
} from '../model/LearningMetadataModels';`;
const repositoryImport = "import { LocalLearningRepository } from './LocalLearningRepository';";

function compileService() {
  let source = readFileSync(servicePath, 'utf8').replaceAll('\r\n', '\n');
  for (const expectedImport of [dataModelsImport, metadataModelsImport, repositoryImport]) {
    assert.equal(source.includes(expectedImport), true,
      `ProactiveLearningService import changed: ${expectedImport}`);
  }
  assert.equal(source.includes('export class ProactiveLearningService'), true,
    'ProactiveLearningService export changed');

  source = source
    .replace(dataModelsImport, '')
    .replace(metadataModelsImport, '')
    .replace(repositoryImport, 'const LocalLearningRepository = globalThis.__repository;')
    .replace('export class ProactiveLearningService', 'class ProactiveLearningService');
  source += '\nglobalThis.__ProactiveLearningService = ProactiveLearningService;\n';
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

const compiledService = compileService();

function repositoryFor(overrides = {}) {
  const state = {
    courses: [],
    events: [],
    dueReviews: [],
    insights: [],
    plan: null,
    ...overrides
  };
  return {
    getCourses: async () => state.courses,
    getStudyEvents: async () => state.events,
    getDueReviewItems: async () => state.dueReviews,
    getTagInsights: async () => state.insights,
    getPlan: async () => state.plan
  };
}

function loadService(repository) {
  const context = vm.createContext({ __repository: repository });
  vm.runInContext(compiledService, context, { filename: servicePath });
  return context.__ProactiveLearningService;
}

const now = new Date(2026, 6, 17, 9, 0, 0);
const courses = [
  { id: 'cs101', title: '数据结构', progress: 0.5, docCount: 52, topics: ['二叉树'] },
  { id: 'cs102', title: '操作系统', progress: 0.25, docCount: 48, topics: ['进程调度'] }
];

test('到期错题优先于薄弱标签', async () => {
  const service = loadService(repositoryFor({
    courses,
    dueReviews: [{
      id: 'review_q1',
      questionId: 'q1',
      courseId: 'cs101',
      topic: '二叉树',
      source: 'local',
      stem: '二叉树前序遍历的访问顺序是什么？',
      userAnswer: 'B',
      correctAnswer: 'A',
      explanation: '根左右',
      attempts: 2,
      resolved: false,
      intervalDays: 1,
      nextReviewAt: '2026-07-17T00:00:00.000Z',
      updatedAt: '2026-07-16T00:00:00.000Z',
      tags: ['遍历顺序']
    }],
    insights: [{
      tag: '遍历顺序',
      courseId: 'cs101',
      topic: '二叉树',
      totalQuestions: 5,
      correctQuestions: 2,
      accuracy: 0.4,
      wrongQuestions: 3,
      lastPracticedAt: '2026-07-16T00:00:00.000Z',
      easyQuestions: 1,
      mediumQuestions: 4,
      hardQuestions: 0,
      lastDifficulty: 'medium',
      masteryLevel: '熟悉',
      masteryPoints: 48,
      weakReason: '正确率低于 60%，说明概念或判断步骤不稳',
      nextStep: '练 5 道同标签题，再查看错题解析'
    }]
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'review');
  assert.equal(action.targetPage, 'pages/MistakeBook');
  assert.equal(action.taskAction, 'review');
  assert.equal(action.focusTag, '遍历顺序');
});

test('掌握值达到 72 的标签不进入薄弱标签动作', async () => {
  const service = loadService(repositoryFor({
    courses,
    insights: [{
      tag: '边界条件',
      courseId: 'cs101',
      topic: '二叉树',
      totalQuestions: 8,
      correctQuestions: 7,
      accuracy: 0.875,
      wrongQuestions: 1,
      lastPracticedAt: '2026-07-16T00:00:00.000Z',
      easyQuestions: 2,
      mediumQuestions: 4,
      hardQuestions: 2,
      lastDifficulty: 'hard',
      masteryLevel: '熟练',
      masteryPoints: 72,
      weakReason: '偶发失误，适合用短练习巩固',
      nextStep: '继续挑战同主题进阶题'
    }],
    plan: {
      planId: 'plan_1',
      userId: 'demo',
      goal: '巩固二叉树',
      tasks: [{
        id: 'task_1',
        title: '完成二叉树测验',
        date: '2026-07-17',
        estimatedMin: 15,
        type: 'quiz',
        action: 'quiz',
        courseId: 'cs101',
        topic: '二叉树',
        done: false
      }]
    }
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'task');
  assert.equal(action.title, '完成二叉树测验');
  assert.equal(action.targetPage, 'pages/Quiz');
});

test('今日未完成计划优先于最近学习事件', async () => {
  const service = loadService(repositoryFor({
    courses,
    events: [{
      id: 'event_1',
      type: 'lesson_completed',
      timestamp: '2026-07-17T08:00:00.000Z',
      courseId: 'cs102',
      topic: '进程调度'
    }],
    plan: {
      planId: 'plan_2',
      userId: 'demo',
      goal: '完成今日任务',
      tasks: [{
        id: 'task_2',
        title: '复习二叉树遍历',
        date: '2026-07-17',
        estimatedMin: 10,
        type: 'lesson',
        action: 'lesson',
        courseId: 'cs101',
        topic: '二叉树',
        done: false
      }]
    }
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'task');
  assert.equal(action.courseId, 'cs101');
  assert.equal(action.courseTitle, '数据结构');
  assert.equal(action.targetPage, 'pages/Lesson');
});

test('无学习状态时返回明确计划空态', async () => {
  const service = loadService(repositoryFor({ courses: null }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'plan');
  assert.equal(action.badge, '今日起步');
  assert.equal(action.cta, '制定计划');
  assert.equal(action.targetPage, 'pages/Plan');
  assert.equal(action.evidence, '本机还没有可继续的课程状态或今日任务');
  assert.equal(action.progressText, '等待制定计划');
});
