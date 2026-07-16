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
const entryAbilityPath = path.resolve(scriptDirectory,
  '../apps/harmonyos/entry/src/main/ets/entryability/EntryAbility.ets');
const dataModelsImport = "import { Course, PlanTask } from '../model/DataModels';";
const metadataModelsImport = `import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent
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
    tagInsightReads: 0,
    plan: null,
    ...overrides
  };
  return {
    getCourses: async () => state.courses,
    getStudyEvents: async () => state.events,
    getDueReviewItems: async () => state.dueReviews,
    getTagInsights: async (limit = 6) => {
      state.tagInsightReads += 1;
      return state.insights.slice(0, limit);
    },
    getPlan: async () => state.plan,
    getTagInsightReadCount: () => state.tagInsightReads
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

test('到期错题优先于今日计划', async () => {
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
    plan: {
      planId: 'plan_after_review',
      userId: 'demo',
      goal: '完成今日任务',
      tasks: [{
        id: 'task_after_review',
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
  assert.equal(action.kind, 'review');
  assert.equal(action.targetPage, 'pages/MistakeBook');
  assert.equal(action.taskAction, 'review');
  assert.equal(action.focusTag, '');
});

test('有效今日计划返回可直达测验任务', async () => {
  const service = loadService(repositoryFor({
    courses,
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

test('混合标签洞察不被主动行动读取或推荐', async () => {
  const repository = repositoryFor({
    courses,
    insights: [
      { tag: '递归出口', masteryPoints: 28, wrongQuestions: 2 },
      { tag: '边界条件', masteryPoints: 88, wrongQuestions: 0 }
    ]
  });
  const service = loadService(repository);

  const action = await service.resolve(now);
  assert.equal(action.kind, 'course');
  assert.equal(action.courseId, 'cs101');
  assert.equal(action.focusTag, '');
  assert.equal(repository.getTagInsightReadCount(), 0);
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

test('生产初始化的三门零进度目录课程仍返回制定计划动作', async () => {
  const service = loadService(repositoryFor({
    courses: [
      {
        id: 'cs101',
        title: '数据结构',
        progress: 0,
        docCount: 52,
        topics: ['二叉树', '图的遍历', '动态规划']
      },
      {
        id: 'cs102',
        title: '操作系统',
        progress: 0,
        docCount: 48,
        topics: ['进程调度', '内存管理', '文件系统']
      },
      {
        id: 'cs103',
        title: '计算机网络',
        progress: 0,
        docCount: 47,
        topics: ['TCP/IP', 'HTTP', '路由协议']
      }
    ]
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'plan');
  assert.equal(action.cta, '制定计划');
  assert.equal(action.courseId, '');
  assert.equal(action.targetPage, 'pages/Plan');
  assert.equal(action.progressText, '等待制定计划');
});

test('今日计划跳过跨课程错配 Topic 并选择后续可执行任务', async () => {
  const service = loadService(repositoryFor({
    courses,
    plan: {
      planId: 'plan_topic_guard',
      userId: 'demo',
      goal: '完成今日任务',
      tasks: [
        {
          id: 'task_invalid_topic',
          title: '错误关联的进程调度测验',
          date: '2026-07-17',
          estimatedMin: 15,
          type: 'quiz',
          action: 'quiz',
          courseId: 'cs101',
          topic: '进程调度',
          done: false
        },
        {
          id: 'task_valid_topic',
          title: '完成进程调度测验',
          date: '2026-07-17',
          estimatedMin: 20,
          type: 'quiz',
          action: 'quiz',
          courseId: 'cs102',
          topic: '进程调度',
          done: false
        }
      ]
    }
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'task');
  assert.equal(action.title, '完成进程调度测验');
  assert.equal(action.courseId, 'cs102');
  assert.equal(action.courseTitle, '操作系统');
  assert.equal(action.topic, '进程调度');
  assert.equal(action.targetPage, 'pages/Quiz');
});

test('旧计划四类不可执行任务返回计划修复动作', async () => {
  const service = loadService(repositoryFor({
    courses,
    plan: {
      planId: 'plan_needs_repair',
      userId: 'demo',
      goal: '修复旧计划',
      tasks: [
        {
          id: 'task_without_course',
          title: '缺少课程',
          date: '2026-07-17',
          estimatedMin: 15,
          type: 'quiz',
          action: 'quiz',
          topic: '二叉树',
          done: false
        },
        {
          id: 'task_without_topic',
          title: '缺少 Topic',
          date: '2026-07-17',
          estimatedMin: 15,
          type: 'quiz',
          action: 'quiz',
          courseId: 'cs101',
          done: false
        },
        {
          id: 'task_without_action',
          title: '缺少动作',
          date: '2026-07-17',
          estimatedMin: 15,
          type: 'lesson',
          courseId: 'cs101',
          topic: '二叉树',
          done: false
        },
        {
          id: 'task_with_invalid_action',
          title: '动作枚举无效',
          date: '2026-07-17',
          estimatedMin: 15,
          type: 'reading',
          action: 'reading',
          courseId: 'cs101',
          topic: '二叉树',
          done: false
        }
      ]
    }
  }));

  const action = await service.resolve(now);
  assert.equal(action.kind, 'plan');
  assert.equal(action.badge, '计划待修复');
  assert.equal(action.targetPage, 'pages/Plan');
  assert.equal(action.taskAction, 'plan');
  assert.equal(action.progressText, '4 项需要更新');
});

test('validateLaunch 拒绝非法来源', () => {
  const service = loadService(repositoryFor({ courses }));
  const launch = service.validateLaunch(
    courses, 'external_widget', 'pages/Quiz', 'cs101', '二叉树', '', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 拒绝非空 focusTag', () => {
  const service = loadService(repositoryFor({ courses }));
  const launch = service.validateLaunch(
    courses, 'proactive_learning_card', 'pages/Quiz', 'cs101', '二叉树', '遍历顺序', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 拒绝 129 字符参数', () => {
  const tooLongTopic = '题'.repeat(129);
  const longTopicCourses = [{
    id: 'cs101',
    title: '数据结构',
    progress: 0,
    docCount: 52,
    topics: [tooLongTopic]
  }];
  const service = loadService(repositoryFor({ courses: longTopicCourses }));
  const launch = service.validateLaunch(
    longTopicCourses, 'proactive_learning_card', 'pages/Quiz', 'cs101', tooLongTopic, '', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 拒绝动作与页面错配', () => {
  const service = loadService(repositoryFor({ courses }));
  const launch = service.validateLaunch(
    courses, 'proactive_learning_card', 'pages/Lesson', 'cs101', '二叉树', '', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 拒绝未知课程', () => {
  const service = loadService(repositoryFor({ courses }));
  const launch = service.validateLaunch(
    courses, 'proactive_learning_reminder', 'pages/Quiz', 'cs999', '二叉树', '', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 拒绝跨课程 Topic', () => {
  const service = loadService(repositoryFor({ courses }));
  const launch = service.validateLaunch(
    courses, 'proactive_learning_reminder', 'pages/Quiz', 'cs101', '进程调度', '', 'quiz');

  assert.equal(launch, undefined);
});

test('validateLaunch 接受合法测验并从课程目录派生标题', () => {
  const catalogCourses = [{
    id: 'cs101',
    title: '本机目录中的数据结构',
    progress: 0,
    docCount: 52,
    topics: ['二叉树']
  }];
  const service = loadService(repositoryFor({ courses: catalogCourses }));
  const launch = service.validateLaunch(
    catalogCourses, 'proactive_learning_card', 'pages/Quiz', 'cs101', '二叉树', '', 'quiz');

  assert.notEqual(launch, undefined);
  assert.equal(launch.targetPage, 'pages/Quiz');
  assert.equal(launch.courseId, 'cs101');
  assert.equal(launch.courseTitle, '本机目录中的数据结构');
  assert.equal(launch.topic, '二叉树');
  assert.equal(launch.focusTag, '');
  assert.equal(launch.taskAction, 'quiz');
});

test('validateLaunch 接受无课程参数的合法计划回流', () => {
  const service = loadService(repositoryFor({ courses: [] }));
  const launch = service.validateLaunch(
    [], 'proactive_learning_reminder', 'pages/Plan', '', '', '', 'plan');

  assert.notEqual(launch, undefined);
  assert.equal(launch.targetPage, 'pages/Plan');
  assert.equal(launch.courseId, '');
  assert.equal(launch.courseTitle, '');
  assert.equal(launch.topic, '');
  assert.equal(launch.focusTag, '');
  assert.equal(launch.taskAction, 'plan');
});

test('EntryAbility 只在目录校验后请求主动跳转且不读取外部课程标题', () => {
  const source = readFileSync(entryAbilityPath, 'utf8').replaceAll('\r\n', '\n');
  const methodStart = source.indexOf('  private async consumeProactiveWant(): Promise<void> {');
  const methodEnd = source.indexOf('\n  private wantString(', methodStart);
  assert.notEqual(methodStart, -1, 'EntryAbility.consumeProactiveWant missing');
  assert.notEqual(methodEnd, -1, 'EntryAbility.consumeProactiveWant boundary changed');

  const method = source.slice(methodStart, methodEnd);
  assert.equal(method.includes("this.wantString(want, 'courseTitle')"), false,
    'EntryAbility must not trust an external courseTitle parameter');
  const validateIndex = method.indexOf('ProactiveLearningService.validateLaunch(');
  const requestIndex = method.indexOf('ProactiveLearningService.requestLaunch(launch);');
  assert.notEqual(validateIndex, -1, 'EntryAbility validateLaunch call missing');
  assert.notEqual(requestIndex, -1, 'EntryAbility requestLaunch call missing');
  assert.equal(validateIndex < requestIndex, true, 'EntryAbility must validate before requestLaunch');
  const validatedLaunchBlock = method.slice(validateIndex, requestIndex);
  assert.equal(validatedLaunchBlock.includes('if (launch === undefined) return;'), true,
    'EntryAbility must stop before requestLaunch when validation fails');
});
