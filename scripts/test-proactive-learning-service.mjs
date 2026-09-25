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
const indexPagePath = path.resolve(scriptDirectory,
  '../apps/harmonyos/entry/src/main/ets/pages/Index.ets');
const dataModelsImport = "import { Course, PlanTask } from '../model/DataModels';";
const metadataModelsImport = `import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent
} from '../model/LearningMetadataModels';`;
const repositoryImport = "import { LocalLearningRepository } from './LocalLearningRepository';";

function sourceFile(filePath) {
  return readFileSync(filePath, 'utf8').replaceAll('\r\n', '\n');
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function balancedBlock(source, openBraceIndex, description) {
  assert.equal(source[openBraceIndex], '{', `${description} opening brace missing`);
  let depth = 0;
  let quote = '';
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = openBraceIndex; index < source.length; index++) {
    const character = source[index];
    const nextCharacter = source[index + 1] ?? '';
    if (lineComment) {
      if (character === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (character === '*' && nextCharacter === '/') {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote.length > 0) {
      if (escaped) {
        escaped = false;
      } else if (character === '\\') {
        escaped = true;
      } else if (character === quote) {
        quote = '';
      }
      continue;
    }
    if (character === '/' && nextCharacter === '/') {
      lineComment = true;
      index += 1;
      continue;
    }
    if (character === '/' && nextCharacter === '*') {
      blockComment = true;
      index += 1;
      continue;
    }
    if (character === "'" || character === '"' || character === '`') {
      quote = character;
      continue;
    }
    if (character === '{') depth += 1;
    if (character === '}') {
      depth -= 1;
      if (depth === 0) {
        return { source: source.slice(openBraceIndex, index + 1), start: openBraceIndex, end: index + 1 };
      }
    }
  }
  assert.fail(`${description} closing brace missing`);
}

function methodBlock(source, methodName) {
  const declaration = new RegExp(
    `(?:^|\\n)\\s*(?:private\\s+)?(?:static\\s+)?(?:async\\s+)?${escapeRegExp(methodName)}\\s*\\(`, 'm');
  const match = declaration.exec(source);
  assert.notEqual(match, null, `${methodName} declaration missing`);
  const openBraceIndex = source.indexOf('{', match.index + match[0].length);
  assert.notEqual(openBraceIndex, -1, `${methodName} body missing`);
  return balancedBlock(source, openBraceIndex, methodName).source;
}

function conditionalBlock(source, condition, description) {
  const match = condition.exec(source);
  assert.notEqual(match, null, `${description} condition missing`);
  const openBraceIndex = source.indexOf('{', match.index + match[0].length);
  assert.notEqual(openBraceIndex, -1, `${description} body missing`);
  return balancedBlock(source, openBraceIndex, description);
}

function assertOrdered(source, expressions, description) {
  let cursor = 0;
  for (const expression of expressions) {
    const match = expression.exec(source.slice(cursor));
    assert.notEqual(match, null, `${description}: ${expression} missing or out of order`);
    cursor += match.index + match[0].length;
  }
}

function matchCount(source, expression) {
  const flags = expression.flags.includes('g') ? expression.flags : expression.flags + 'g';
  return Array.from(source.matchAll(new RegExp(expression.source, flags))).length;
}

const clearProactiveTargetPattern =
  /AppStorage\.setOrCreate\s*<\s*string\s*>\s*\(\s*'proactiveTargetPage'\s*,\s*''\s*\)\s*;/g;

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
  assert.equal(action.targetPage, 'pages/CourseDetail');
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
  assert.equal(action.evidence, '还没有学习计划');
  assert.equal(action.progressText, '等待制定计划');
});

test('今日任务全完成后保留完成事实，不回退到首次制定计划', async () => {
  const service = loadService(repositoryFor({
    courses: [{ id: 'cs101', title: '数据结构', progress: 0, topics: ['图的表示与遍历'] }],
    plan: {
      tasks: [{ id: 'today_graph', date: '2026-07-17', title: '学习图遍历',
        estimatedMin: 20, type: 'lesson', action: 'lesson', courseId: 'cs101',
        topic: '图的表示与遍历', done: true }]
    }
  }));

  const action = await service.resolve(now);
  assert.equal(action.badge, '今日已完成');
  assert.equal(action.targetPage, 'pages/CourseDetail');
  assert.equal(action.courseId, 'cs101');
  assert.equal(action.progressText, '1/1 项已完成');
  assert.equal(action.evidence, '今天的任务已勾选');
});

test('无课程可续时，今日已完成仍可打开课程入口', async () => {
  const service = loadService(repositoryFor({
    courses: [],
    plan: { tasks: [{ id: 'legacy_done', date: '2026-07-17', done: true }] }
  }));

  const action = await service.resolve(now);
  assert.equal(action.badge, '今日已完成');
  assert.equal(action.targetPage, 'pages/Index');
  assert.equal(action.cta, '浏览课程');
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

test('validateLaunch 接受课程详情直达并保留旧课程 Tab 回流', () => {
  const service = loadService(repositoryFor({ courses }));
  const detailLaunch = service.validateLaunch(
    courses, 'proactive_learning_card', 'pages/CourseDetail', 'cs101', '', '', 'course');
  const legacyLaunch = service.validateLaunch(
    courses, 'proactive_learning_reminder', 'pages/Index', 'cs101', '', '', 'course');

  assert.notEqual(detailLaunch, undefined);
  assert.equal(detailLaunch.targetPage, 'pages/CourseDetail');
  assert.equal(detailLaunch.courseId, 'cs101');
  assert.equal(detailLaunch.courseTitle, '数据结构');
  assert.notEqual(legacyLaunch, undefined);
  assert.equal(legacyLaunch.targetPage, 'pages/Index');
});

test('EntryAbility 忽略无关 Want 且保留已排队的合法回流', () => {
  const source = sourceFile(entryAbilityPath);
  const queueMethod = methodBlock(source, 'queueProactiveWant');
  const irrelevantWant = conditionalBlock(queueMethod,
    /if\s*\(\s*source\s*===\s*undefined\s*\|\|\s*!ProactiveLearningService\.isLaunchSource\s*\(\s*source\s*\)\s*\)/,
    'irrelevant Want guard');

  assert.match(irrelevantWant.source, /\{\s*return\s*;\s*\}/,
    'irrelevant Want must return without mutating queued launch state');
  assert.doesNotMatch(irrelevantWant.source, /this\.pendingProactiveWant\s*=/,
    'irrelevant Want must not clear or replace a valid pending Want');
  assert.doesNotMatch(irrelevantWant.source, /this\.(?:pendingProactiveWantSequence|proactiveWantSequence)\s*(?:=|\+=)/,
    'irrelevant Want must not advance or overwrite the valid pending sequence');
});

test('EntryAbility 连续合法 Want 以单调序号保证 latest-wins', () => {
  const source = sourceFile(entryAbilityPath);
  const queueMethod = methodBlock(source, 'queueProactiveWant');
  const consumeMethod = methodBlock(source, 'consumeProactiveWant');
  const clearMethod = methodBlock(source, 'clearPendingProactiveWant');

  assert.match(source, /private\s+pendingProactiveWantSequence\s*:\s*number\s*=\s*0\s*;/,
    'pending Want sequence field missing');
  assert.match(source, /private\s+proactiveWantSequence\s*:\s*number\s*=\s*0\s*;/,
    'monotonic Want sequence field missing');
  assertOrdered(queueMethod, [
    /this\.proactiveWantSequence\s*\+=\s*1\s*;/,
    /this\.pendingProactiveWant\s*=\s*want\s*;/,
    /this\.pendingProactiveWantSequence\s*=\s*this\.proactiveWantSequence\s*;/
  ], 'valid Want queue must advance and snapshot its sequence');
  assertOrdered(consumeMethod, [
    /const\s+sequence\s*=\s*this\.pendingProactiveWantSequence\s*;/,
    /await\s+LocalLearningRepository\.getCourses\s*\(\s*\)/,
    /if\s*\(\s*sequence\s*!==\s*this\.pendingProactiveWantSequence\s*\)\s*return\s*;/,
    /ProactiveLearningService\.validateLaunch\s*\(/,
    /await\s+ProactiveLearningService\.resolve\s*\(\s*\)/,
    /if\s*\(\s*sequence\s*!==\s*this\.pendingProactiveWantSequence\s*\)\s*return\s*;/,
    /this\.clearPendingProactiveWant\s*\(\s*sequence\s*\)\s*;/,
    /ProactiveLearningService\.requestAction\s*\(\s*currentAction\s*\)\s*;/
  ], 'only the latest Want may survive repository reads and publish an action');
  assert.doesNotMatch(consumeMethod, /this\.pendingProactiveWant\s*=\s*null\s*;/,
    'async consumers must not clear a newer Want directly');
  assertOrdered(clearMethod, [
    /if\s*\(\s*sequence\s*!==\s*this\.pendingProactiveWantSequence\s*\)\s*return\s*;/,
    /this\.pendingProactiveWant\s*=\s*null\s*;/
  ], 'pending Want clear must be sequence guarded');
});

test('EntryAbility 校验通知外壳后重新解析当前行动', () => {
  const source = sourceFile(entryAbilityPath);
  const consumeMethod = methodBlock(source, 'consumeProactiveWant');

  assert.doesNotMatch(consumeMethod, /this\.wantString\s*\(\s*want\s*,\s*'courseTitle'\s*\)/,
    'EntryAbility must not trust an external courseTitle parameter');
  assertOrdered(consumeMethod, [
    /const\s+launch\s*=\s*ProactiveLearningService\.validateLaunch\s*\(/,
    /if\s*\(\s*launch\s*===\s*undefined\s*\)/,
    /const\s+currentAction\s*=\s*await\s+ProactiveLearningService\.resolve\s*\(\s*\)\s*;/,
    /ProactiveLearningService\.requestAction\s*\(\s*currentAction\s*\)\s*;/
  ], 'notification click must validate its envelope and then resolve live learning state');
  assert.doesNotMatch(consumeMethod, /ProactiveLearningService\.requestLaunch\s*\(\s*launch\s*\)/,
    'validated notification parameters must not execute a stale fixed action');
});

test('Index 热启动按当前路径返回根页或切换子页', () => {
  const source = sourceFile(indexPagePath);
  const navigateMethod = methodBlock(source, 'navigateProactiveLaunch');
  const rootPageBranch = conditionalBlock(navigateMethod,
    /if\s*\(\s*targetPage\s*===\s*'pages\/Index'\s*\)/, 'root-page launch');

  assert.match(navigateMethod, /const\s+currentPage\s*=\s*appRouter\.getState\s*\(\s*\)\.path\s*;/,
    'hot launch must inspect the current router path');
  assertOrdered(rootPageBranch.source, [
    /this\.selectTab\s*\(/,
    /if\s*\(\s*currentPage\s*===\s*'pages\/Index'\s*\)/,
    /this\.completeProactiveNavigation\s*\(\s*launchVersion\s*,\s*targetPage\s*\)\s*;/,
    /appRouter\.back\s*\(\s*\{\s*url\s*:\s*'pages\/Index'\s*\}\s*\)\s*;/,
    /appRouter\.getState\s*\(\s*\)\.path\s*===\s*'pages\/Index'/,
    /this\.completeProactiveNavigation\s*\(\s*launchVersion\s*,\s*targetPage\s*\)\s*;/,
    /this\.failProactiveNavigation\s*\(\s*launchVersion\s*,/
  ], 'course launch must return a nested route to the API 12 root page before completing');
  assert.match(navigateMethod,
    /currentPage\s*===\s*'pages\/Index'\s*\?\s*appRouter\.pushUrl\s*\(\s*\{\s*url\s*:\s*targetPage\s*\}\s*\)\s*:\s*appRouter\.replaceUrl\s*\(\s*\{\s*url\s*:\s*targetPage\s*\}\s*\)/s,
    'subpage launch must push from root and replace an already nested page');
});

test('Index 合法目标仅在导航确认成功后消费且失败只重试一次', () => {
  const source = sourceFile(indexPagePath);
  const consumeMethod = methodBlock(source, 'consumeProactiveLaunch');
  const navigateMethod = methodBlock(source, 'navigateProactiveLaunch');
  const completeMethod = methodBlock(source, 'completeProactiveNavigation');
  const failMethod = methodBlock(source, 'failProactiveNavigation');
  const invalidTarget = conditionalBlock(navigateMethod,
    /if\s*\(\s*!ProactiveLearningService\.isTargetPage\s*\(\s*targetPage\s*\)\s*\)/,
    'invalid proactive target');
  const validNavigation = navigateMethod.slice(0, invalidTarget.start) +
    navigateMethod.slice(invalidTarget.end);

  assert.equal(matchCount(consumeMethod, clearProactiveTargetPattern), 0,
    'queued target must not be cleared before navigation starts');
  assert.equal(matchCount(validNavigation, clearProactiveTargetPattern), 0,
    'valid target must not be cleared before asynchronous navigation confirms success');
  assert.equal(matchCount(failMethod, clearProactiveTargetPattern), 0,
    'navigation failure must preserve the target for retry');
  assert.equal(matchCount(completeMethod, clearProactiveTargetPattern), 1,
    'successful navigation must clear the exact pending target once');
  assertOrdered(completeMethod, [
    /launchVersion\s*===\s*this\.proactiveLaunchVersion/,
    /targetPage\s*===\s*\(\s*AppStorage\.get\s*<\s*string\s*>\s*\(\s*'proactiveTargetPage'\s*\)/,
    /AppStorage\.setOrCreate\s*<\s*string\s*>\s*\(\s*'proactiveTargetPage'\s*,\s*''\s*\)\s*;/,
    /this\.consumedLaunchVersion\s*=\s*launchVersion\s*;/
  ], 'completion must still own the current version and target before consuming it');
  assertOrdered(navigateMethod, [
    /const\s+navigation\s*=/,
    /navigation\.then\s*\(/,
    /this\.completeProactiveNavigation\s*\(/,
    /\.catch\s*\(/,
    /this\.failProactiveNavigation\s*\(/
  ], 'promise navigation must separate success completion from failure retention');
  assertOrdered(failMethod, [
    /this\.releaseProactiveNavigation\s*\(\s*launchVersion\s*\)\s*;/,
    /this\.retryLaunchVersion\s*!==\s*launchVersion/,
    /this\.retryLaunchVersion\s*=\s*launchVersion\s*;/,
    /setTimeout\s*\(/,
    /this\.consumeProactiveLaunch\s*\(\s*\)\s*;/
  ], 'failure must retain the target and schedule one version-scoped retry');
});
