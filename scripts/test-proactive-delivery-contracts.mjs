import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const sourceRoot = path.resolve(scriptDirectory, '../apps/harmonyos/entry/src/main/ets');
const servicePath = path.join(sourceRoot, 'common/ProactiveLearningService.ets');
const reminderPath = path.join(sourceRoot, 'common/LearningReminder.ets');
const formUpdaterPath = path.join(sourceRoot, 'common/LearningFormUpdater.ets');
const contentRepositoryPath = path.join(sourceRoot, 'common/LearningContentRepository.ets');
const entryFormAbilityPath = path.join(sourceRoot, 'entryformability/EntryFormAbility.ets');
const entryAbilityPath = path.join(sourceRoot, 'entryability/EntryAbility.ets');
const homeContentPath = path.join(sourceRoot, 'pages/HomeContent.ets');
const indexPath = path.join(sourceRoot, 'pages/Index.ets');
const planCardPath = path.join(sourceRoot, 'widget/pages/LearningPlanCard.ets');

const catalog = [
  { id: 'cs101', title: '数据结构', progress: 0.5, docCount: 52, topics: ['二叉树'] },
  { id: 'cs102', title: '操作系统', progress: 0.25, docCount: 48, topics: ['进程调度'] }
];
const fixedNow = new Date(2026, 6, 17, 9, 0, 0);
const navigationKeys = [
  'selectedCourseId',
  'selectedCourseTitle',
  'selectedQuizTopic',
  'selectedQuizFocusTag',
  'selectedPracticeTopic',
  'selectedContentTopic',
  'proactiveTaskAction',
  'proactiveTargetPage',
  'proactiveTargetTab',
  'proactiveLaunchVersion'
];

function readSource(filePath) {
  return readFileSync(filePath, 'utf8').replaceAll('\r\n', '\n');
}

function removeImports(source, expectedImports, sourcePath) {
  let transformed = source;
  for (const expectedImport of expectedImports) {
    assert.equal(transformed.includes(expectedImport), true,
      `${path.basename(sourcePath)} import changed: ${expectedImport}`);
    transformed = transformed.replace(expectedImport, '');
  }
  return transformed;
}

function compileService() {
  const dataModelsImport = "import { Course, PlanTask } from '../model/DataModels';";
  const metadataModelsImport = `import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent
} from '../model/LearningMetadataModels';`;
  const repositoryImport = "import { LocalLearningRepository } from './LocalLearningRepository';";
  let source = removeImports(readSource(servicePath),
    [dataModelsImport, metadataModelsImport, repositoryImport], servicePath);
  assert.equal(source.includes('export class ProactiveLearningService'), true,
    'ProactiveLearningService export changed');
  source = source.replace('export class ProactiveLearningService', 'class ProactiveLearningService');
  source = 'const LocalLearningRepository = globalThis.__repository;\n' + source;
  source += '\nglobalThis.__ProactiveLearningService = ProactiveLearningService;\n';
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

function compileReminder() {
  const abilityImport = "import { common, Want, wantAgent } from '@kit.AbilityKit';";
  const notificationImport = "import { notificationManager } from '@kit.NotificationKit';";
  const serviceImport =
    "import { ProactiveLearningAction, ProactiveLearningService } from './ProactiveLearningService';";
  let source = removeImports(readSource(reminderPath),
    [abilityImport, notificationImport, serviceImport], reminderPath);
  assert.equal(source.includes('export class LearningReminder'), true, 'LearningReminder export changed');
  source = source.replace('export class LearningReminder', 'class LearningReminder');
  source = `const wantAgent = globalThis.__wantAgent;
const notificationManager = globalThis.__notificationManager;
const ProactiveLearningService = globalThis.__service;
${source}
globalThis.__LearningReminder = LearningReminder;
`;
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

function compileFormUpdater() {
  const formImport = "import { formBindingData, formProvider } from '@kit.FormKit';";
  const repositoryImport = "import { LocalLearningRepository } from './LocalLearningRepository';";
  const serviceImport =
    "import { ProactiveLearningAction, ProactiveLearningService } from './ProactiveLearningService';";
  let source = removeImports(readSource(formUpdaterPath),
    [formImport, repositoryImport, serviceImport], formUpdaterPath);
  assert.equal(source.includes('export class LearningFormUpdater'), true, 'LearningFormUpdater export changed');
  source = source.replace('export class LearningFormUpdater', 'class LearningFormUpdater');
  source = `const formBindingData = globalThis.__formBindingData;
const formProvider = globalThis.__formProvider;
const LocalLearningRepository = globalThis.__repository;
const ProactiveLearningService = globalThis.__service;
${source}
globalThis.__LearningFormUpdater = LearningFormUpdater;
`;
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

function compileEntryFormAbility() {
  const formImport = "import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';";
  const abilityImport = "import { Want } from '@kit.AbilityKit';";
  const updaterImport = "import { LearningFormUpdater } from '../common/LearningFormUpdater';";
  const contentRepositoryImport =
    "import { LearningContentRepository } from '../common/LearningContentRepository';";
  const repositoryImport = "import { LocalLearningRepository } from '../common/LocalLearningRepository';";
  let source = removeImports(readSource(entryFormAbilityPath),
    [formImport, abilityImport, updaterImport, contentRepositoryImport, repositoryImport], entryFormAbilityPath);
  assert.equal(source.includes('export default class EntryFormAbility extends FormExtensionAbility'), true,
    'EntryFormAbility export changed');
  source = source.replace('export default class EntryFormAbility extends FormExtensionAbility',
    'class EntryFormAbility extends FormExtensionAbility');
  source = `const formBindingData = globalThis.__formBindingData;
const FormExtensionAbility = globalThis.__FormExtensionAbility;
const formInfo = globalThis.__formInfo;
const LearningFormUpdater = globalThis.__formUpdater;
const LearningContentRepository = globalThis.__contentRepository;
const LocalLearningRepository = globalThis.__repository;
${source}
globalThis.__EntryFormAbility = EntryFormAbility;
`;
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

function compileLearningContentRepository() {
  const localizationImport = "import { resourceManager } from '@kit.LocalizationKit';";
  const arkTsImport = "import { util } from '@kit.ArkTS';";
  const dataModelsImport = `import {
  CuratedKnowledgeChunk,
  ExternalLearningResource,
  LessonExperience,
  TopicRelation
} from '../model/DataModels';`;
  const metadataImport =
    "import { LearningCuratedQuestion as CuratedQuestion } from '../model/LearningMetadataModels';";
  let source = removeImports(readSource(contentRepositoryPath),
    [localizationImport, arkTsImport, dataModelsImport, metadataImport], contentRepositoryPath);
  assert.equal(source.includes('export class LearningContentRepository'), true,
    'LearningContentRepository export changed');
  source = source.replace('export class LearningContentRepository', 'class LearningContentRepository');
  source = `const util = globalThis.__util;
${source}
globalThis.__LearningContentRepository = LearningContentRepository;
`;
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

function compileEntryAbility() {
  const imports = [
    "import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';",
    "import { display, window } from '@kit.ArkUI';",
    "import { hilog } from '@kit.PerformanceAnalysisKit';",
    "import { Constants } from '../common/Constants';",
    "import { LocalLearningRepository } from '../common/LocalLearningRepository';",
    "import { HttpClient } from '../common/HttpClient';",
    "import { Course, HealthResponse } from '../model/DataModels';",
    "import { LearningContentRepository } from '../common/LearningContentRepository';",
    "import { SafeAreaInsets } from '../common/SafeArea';",
    "import { ProactiveLearningAction, ProactiveLearningService } from '../common/ProactiveLearningService';"
  ];
  let source = removeImports(readSource(entryAbilityPath), imports, entryAbilityPath);
  assert.equal(source.includes('export default class EntryAbility extends UIAbility'), true,
    'EntryAbility export changed');
  source = source.replace('export default class EntryAbility extends UIAbility',
    'class EntryAbility extends UIAbility');
  source = `const UIAbility = globalThis.__UIAbility;
const display = globalThis.__display;
const window = globalThis.__window;
const hilog = globalThis.__hilog;
const Constants = globalThis.__constants;
const LocalLearningRepository = globalThis.__repository;
const HttpClient = globalThis.__httpClient;
const LearningContentRepository = globalThis.__contentRepository;
const SafeAreaInsets = globalThis.__safeAreaInsets;
const ProactiveLearningService = globalThis.__service;
${source}
globalThis.__EntryAbility = EntryAbility;
`;
  return stripTypeScriptTypes(source, { mode: 'transform', sourceMap: false });
}

const compiledService = compileService();
const compiledReminder = compileReminder();
const compiledFormUpdater = compileFormUpdater();
const compiledLearningContentRepository = compileLearningContentRepository();
const compiledEntryFormAbility = compileEntryFormAbility();
const compiledEntryAbility = compileEntryAbility();

function serviceRepository() {
  return {
    getCourses: async () => catalog,
    getStudyEvents: async () => [],
    getDueReviewItems: async () => [{
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
    getPlan: async () => null
  };
}

function createStorage() {
  const values = new Map();
  return {
    api: {
      get: (key) => values.get(key),
      setOrCreate: (key, value) => values.set(key, value)
    },
    get: (key) => values.get(key),
    navigationSnapshot: () => Object.fromEntries(navigationKeys.map((key) => [key, values.get(key)]))
  };
}

function loadService(repository = serviceRepository(), storage = createStorage()) {
  const context = vm.createContext({
    __repository: repository,
    AppStorage: storage.api
  });
  vm.runInContext(compiledService, context, { filename: servicePath });
  return context.__ProactiveLearningService;
}

function resolverFromProduct() {
  const service = loadService();
  return {
    resolve: () => service.resolve(fixedNow),
    fallback: (course) => service.fallback(course)
  };
}

function loadReminder(service, notificationManager, wantAgent) {
  const context = vm.createContext({
    __service: service,
    __notificationManager: notificationManager,
    __wantAgent: wantAgent
  });
  vm.runInContext(compiledReminder, context, { filename: reminderPath });
  return context.__LearningReminder;
}

function loadFormUpdater(service, formProvider, repository = { getFormIds: async () => [] }) {
  const context = vm.createContext({
    __service: service,
    __formProvider: formProvider,
    __repository: repository,
    __formBindingData: {
      createFormBindingData: (data) => data
    }
  });
  vm.runInContext(compiledFormUpdater, context, { filename: formUpdaterPath });
  return context.__LearningFormUpdater;
}

function loadEntryFormAbility(formUpdater, repository,
  contentRepository = { initialize: async () => {} }) {
  class FormExtensionAbility {
    constructor() {
      this.context = { name: 'form-context', resourceManager: { name: 'form-resource-manager' } };
    }
  }
  const context = vm.createContext({
    __FormExtensionAbility: FormExtensionAbility,
    __formUpdater: formUpdater,
    __contentRepository: contentRepository,
    __repository: repository,
    __formBindingData: { createFormBindingData: (data) => data },
    __formInfo: {
      FormParam: { IDENTITY_KEY: 'ohos.extra.param.key.form_identity' },
      FormState: { READY: 'READY' }
    }
  });
  vm.runInContext(compiledEntryFormAbility, context, { filename: entryFormAbilityPath });
  return context.__EntryFormAbility;
}

function loadLearningContentRepository() {
  const context = vm.createContext({
    __util: {
      TextDecoder: {
        create: () => ({
          decodeToString: (bytes) => new TextDecoder().decode(bytes)
        })
      }
    }
  });
  vm.runInContext(compiledLearningContentRepository, context, { filename: contentRepositoryPath });
  return context.__LearningContentRepository;
}

function contentFixture(pathName) {
  const values = {
    'learning/knowledge-chunks.json': [
      { id: 'knowledge-1', courseId: 'cs101', topic: '二叉树' }
    ],
    'learning/quizzes.json': [
      { id: 'question-1', courseId: 'cs101', topic: '二叉树' }
    ],
    'learning/external-resources.json': [
      { id: 'resource-1', courseId: 'cs101' }
    ],
    'learning/topic-relations.json': [
      { id: 'relation-1', courseId: 'cs101' }
    ],
    'learning/lesson-experiences.json': [
      { id: 'lesson-1', courseId: 'cs101', topic: '二叉树' }
    ]
  };
  const value = values[pathName];
  if (value === undefined) throw new Error(`未知课程内容路径: ${pathName}`);
  return new TextEncoder().encode(JSON.stringify(value));
}

function validWant() {
  return {
    parameters: {
      source: 'proactive_learning_reminder',
      targetPage: 'pages/Quiz',
      courseId: 'cs101',
      courseTitle: '不可信外部标题',
      topic: '二叉树',
      focusTag: '',
      taskAction: 'quiz'
    }
  };
}

function createEntryHarness() {
  const storage = createStorage();
  const repository = {
    initialize: async () => {},
    syncCourseCatalog: async () => {},
    getCourses: async () => catalog,
    getStudyEvents: async () => [],
    getDueReviewItems: async () => [],
    getPlan: async () => null
  };
  const service = loadService(repository, storage);
  class UIAbility {
    constructor() {
      this.context = { resourceManager: {} };
    }
  }
  const context = vm.createContext({
    __UIAbility: UIAbility,
    __display: { getDefaultDisplaySync: () => ({ densityPixels: 1 }) },
    __window: {},
    __hilog: { error: () => {}, warn: () => {} },
    __constants: { API_HEALTH: '/api/health', HILOG_DOMAIN: 0, HILOG_TAG: 'test' },
    __repository: repository,
    __httpClient: { get: async () => ({ status: 'ready' }) },
    __contentRepository: {
      initialize: async () => {},
      getKnowledge: (courseId) => new Array(catalog.find((course) => course.id === courseId)?.docCount ?? 0),
      getTopics: (courseId) => catalog.find((course) => course.id === courseId)?.topics ?? []
    },
    __safeAreaInsets: { setVp: () => {} },
    __service: service,
    AppStorage: storage.api,
    console,
    setTimeout
  });
  vm.runInContext(compiledEntryAbility, context, { filename: entryAbilityPath });
  return {
    EntryAbility: context.__EntryAbility,
    storage,
    windowStage: {
      loadContent: (_page, callback) => callback({ code: 0 })
    }
  };
}

async function settleAsyncWork() {
  await new Promise((resolve) => setImmediate(resolve));
  await Promise.resolve();
}

test('提醒和服务卡片共享真实主动行动的页面、动作、课程与 Topic', async () => {
  const productService = loadService();
  let resolveCalls = 0;
  const trackedService = {
    resolve: async () => {
      resolveCalls += 1;
      return productService.resolve(fixedNow);
    },
    fallback: (course) => productService.fallback(course)
  };
  const wantAgentInfos = [];
  const notificationRequests = [];
  const formUpdates = [];
  const reminder = loadReminder(trackedService, {
    isNotificationEnabled: async () => true,
    requestEnableNotification: async () => {},
    publish: async (request) => notificationRequests.push(request),
    SlotType: { CONTENT_INFORMATION: 'content' },
    ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 'text' }
  }, {
    OperationType: { START_ABILITY: 'start' },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 'update' },
    getWantAgent: async (info) => {
      wantAgentInfos.push(info);
      return { id: 'notification-action' };
    }
  });
  const formUpdater = loadFormUpdater(trackedService, {
    updateForm: async (formId, data) => formUpdates.push({ formId, data })
  });

  await reminder.publishNextTask({ name: 'ui-context' });
  await formUpdater.refreshForm('form-1');

  assert.equal(resolveCalls, 2);
  assert.equal(notificationRequests.length, 1);
  assert.equal(formUpdates.length, 1);
  const reminderWant = wantAgentInfos[0].wants[0];
  const cardData = formUpdates[0].data;
  assert.equal(reminderWant.parameters.source, 'proactive_learning_reminder');
  const executableFields = ['targetPage', 'taskAction', 'courseId', 'courseTitle', 'topic', 'focusTag'];
  for (const key of executableFields) {
    assert.equal(reminderWant.parameters[key], cardData[key], `${key} must match across proactive surfaces`);
  }

  const cardSource = readSource(planCardPath);
  assert.equal(cardSource.includes("source: 'proactive_learning_card'"), true);
  for (const key of executableFields) {
    assert.equal(cardSource.includes(`${key}: this.${key}`), true,
      `LearningPlanCard must route with refreshed ${key}`);
  }
});

test('通知权限请求失败后下一次调用仍会重试并发布', async () => {
  let enabledChecks = 0;
  let permissionAttempts = 0;
  let publishAttempts = 0;
  const reminder = loadReminder(resolverFromProduct(), {
    isNotificationEnabled: async () => {
      enabledChecks += 1;
      return enabledChecks >= 3;
    },
    requestEnableNotification: async () => {
      permissionAttempts += 1;
      throw new Error('permission unavailable');
    },
    publish: async () => {
      publishAttempts += 1;
    },
    SlotType: { CONTENT_INFORMATION: 'content' },
    ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 'text' }
  }, {
    OperationType: { START_ABILITY: 'start' },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 'update' },
    getWantAgent: async () => ({ id: 'notification-action' })
  });

  await assert.rejects(reminder.publishNextTask({}), /通知权限未开启/);
  await reminder.publishNextTask({});

  assert.equal(enabledChecks, 3);
  assert.equal(permissionAttempts, 1);
  assert.equal(publishAttempts, 1);
});

test('通知权限请求返回但复查仍关闭时拒绝发布', async () => {
  let enabledChecks = 0;
  let permissionAttempts = 0;
  let publishAttempts = 0;
  const reminder = loadReminder(resolverFromProduct(), {
    isNotificationEnabled: async () => {
      enabledChecks += 1;
      return false;
    },
    requestEnableNotification: async () => {
      permissionAttempts += 1;
    },
    publish: async () => {
      publishAttempts += 1;
    },
    SlotType: { CONTENT_INFORMATION: 'content' },
    ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 'text' }
  }, {
    OperationType: { START_ABILITY: 'start' },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 'update' },
    getWantAgent: async () => ({ id: 'notification-action' })
  });

  await assert.rejects(reminder.publishNextTask({}), /通知权限未开启/);

  assert.equal(enabledChecks, 2);
  assert.equal(permissionAttempts, 1);
  assert.equal(publishAttempts, 0);
});

test('通知发布失败后下一次调用仍会重新发布', async () => {
  let publishAttempts = 0;
  const reminder = loadReminder(resolverFromProduct(), {
    isNotificationEnabled: async () => true,
    requestEnableNotification: async () => {},
    publish: async () => {
      publishAttempts += 1;
      if (publishAttempts === 1) throw new Error('publish unavailable');
    },
    SlotType: { CONTENT_INFORMATION: 'content' },
    ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 'text' }
  }, {
    OperationType: { START_ABILITY: 'start' },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 'update' },
    getWantAgent: async () => ({ id: 'notification-action' })
  });

  await assert.rejects(reminder.publishNextTask({}), /系统学习提醒发布失败/);
  await reminder.publishNextTask({});

  assert.equal(publishAttempts, 2);
});

test('服务卡片更新失败后 refreshAll 下一次仍会重试', async () => {
  let updateAttempts = 0;
  const formUpdater = loadFormUpdater(resolverFromProduct(), {
    updateForm: async () => {
      updateAttempts += 1;
      if (updateAttempts === 1) throw new Error('form update unavailable');
    }
  }, {
    getFormIds: async () => ['form-1']
  });

  await formUpdater.refreshAll();
  await formUpdater.refreshAll();

  assert.equal(updateAttempts, 2);
});

test('两张服务卡片一次解析并共享同一行动快照', async () => {
  const action = await loadService().resolve(fixedNow);
  let resolveCalls = 0;
  const updates = [];
  const formUpdater = loadFormUpdater({
    resolve: async () => {
      resolveCalls += 1;
      return action;
    },
    fallback: () => action
  }, {
    updateForm: async (formId, data) => updates.push({
      formId,
      data: JSON.parse(JSON.stringify(data))
    })
  }, {
    getFormIds: async () => ['form-1', 'form-2']
  });

  await formUpdater.refreshAll();

  assert.equal(resolveCalls, 1);
  assert.deepEqual(updates.map((update) => update.formId), ['form-1', 'form-2']);
  assert.deepEqual(updates[0].data, updates[1].data);
});

test('并发服务卡片批次保持整批串行且最新行动最终覆盖全部卡片', async () => {
  const baseAction = await resolverFromProduct().resolve();
  const firstAction = { ...baseAction, title: '第一批行动' };
  const latestAction = { ...baseAction, title: '最新行动' };
  const updates = [];
  let releaseFirstUpdate;
  const firstUpdateBlocked = new Promise((resolve) => {
    releaseFirstUpdate = resolve;
  });
  let firstUpdateStarted;
  const firstUpdateSeen = new Promise((resolve) => {
    firstUpdateStarted = resolve;
  });
  let unexpectedResolveCalls = 0;
  const formUpdater = loadFormUpdater({
    resolve: async () => {
      unexpectedResolveCalls += 1;
      throw new Error('explicit action must not resolve again');
    },
    fallback: () => latestAction
  }, {
    updateForm: async (formId, data) => {
      updates.push({ formId, title: data.title });
      if (updates.length === 1) {
        firstUpdateStarted();
        await firstUpdateBlocked;
      }
    }
  }, {
    getFormIds: async () => ['form-1', 'form-2']
  });

  const firstBatch = formUpdater.refreshAllWithAction(firstAction);
  await firstUpdateSeen;
  const latestBatch = formUpdater.refreshAllWithAction(latestAction);
  releaseFirstUpdate();
  await Promise.all([firstBatch, latestBatch]);

  assert.equal(unexpectedResolveCalls, 0);
  assert.deepEqual(updates, [
    { formId: 'form-1', title: '第一批行动' },
    { formId: 'form-2', title: '第一批行动' },
    { formId: 'form-1', title: '最新行动' },
    { formId: 'form-2', title: '最新行动' }
  ]);
  assert.equal(updates.filter((item) => item.formId === 'form-1').at(-1).title, '最新行动');
  assert.equal(updates.filter((item) => item.formId === 'form-2').at(-1).title, '最新行动');
});

test('显式行动同步尝试全部卡片并向首页暴露部分失败', async () => {
  const action = await resolverFromProduct().resolve();
  const attempted = [];
  const formUpdater = loadFormUpdater(resolverFromProduct(), {
    updateForm: async (formId) => {
      attempted.push(formId);
      if (formId === 'form-1') throw new Error('form update unavailable');
    }
  }, {
    getFormIds: async () => ['form-1', 'form-2']
  });

  const result = await formUpdater.refreshAllWithAction(action);
  assert.deepEqual({ ...result }, {
    registered: 2,
    updated: 1,
    failed: 1,
    lookupFailed: false
  });
  assert.deepEqual(attempted, ['form-1', 'form-2']);

  const homeSource = readSource(homeContentPath);
  assert.equal(homeSource.includes("this.notificationState = 'warning';"), true);
  assert.equal(homeSource.includes("Button('重试同步')"), true);
  assert.equal(homeSource.includes('this.retryReminderCards();'), true);
  assert.equal(homeSource.includes('LearningFormUpdater.refreshAllWithAction(action)'), true);
});

test('服务卡片注册表读取失败与零卡片状态精确区分', async () => {
  const action = await resolverFromProduct().resolve();
  const lookupFailureUpdater = loadFormUpdater(resolverFromProduct(), {
    updateForm: async () => {}
  }, {
    getFormIds: async () => {
      throw new Error('repository unavailable');
    }
  });
  const noFormsUpdater = loadFormUpdater(resolverFromProduct(), {
    updateForm: async () => {
      throw new Error('must not update');
    }
  }, {
    getFormIds: async () => []
  });

  assert.deepEqual({ ...await lookupFailureUpdater.refreshAllWithAction(action) }, {
    registered: 0,
    updated: 0,
    failed: 0,
    lookupFailed: true
  });
  assert.deepEqual({ ...await noFormsUpdater.refreshAllWithAction(action) }, {
    registered: 0,
    updated: 0,
    failed: 0,
    lookupFailed: false
  });
});

test('本地状态变化后单张服务卡片重新解析新的行动', async () => {
  const firstAction = await loadService().resolve(fixedNow);
  const latestAction = { ...firstAction, title: '状态变化后的行动', targetPage: 'pages/Plan', taskAction: 'plan' };
  const queuedActions = [firstAction, latestAction];
  const updates = [];
  const formUpdater = loadFormUpdater({
    resolve: async () => queuedActions.shift(),
    fallback: () => latestAction
  }, {
    updateForm: async (_formId, data) => updates.push({
      title: data.title,
      targetPage: data.targetPage,
      taskAction: data.taskAction
    })
  });

  await formUpdater.refreshForm('form-1');
  await formUpdater.refreshForm('form-1');

  assert.deepEqual(updates, [
    { title: firstAction.title, targetPage: firstAction.targetPage, taskAction: firstAction.taskAction },
    { title: latestAction.title, targetPage: 'pages/Plan', taskAction: 'plan' }
  ]);
});

test('课程内容仓储并发初始化共享同一任务且只读取一轮资产', async () => {
  const repository = loadLearningContentRepository();
  const reads = [];
  let releaseFirstRead;
  const firstReadGate = new Promise((resolve) => {
    releaseFirstRead = resolve;
  });
  const manager = {
    getRawFileContent: async (pathName) => {
      reads.push(pathName);
      if (reads.length === 1) await firstReadGate;
      return contentFixture(pathName);
    }
  };

  const first = repository.initialize(manager);
  const second = repository.initialize(manager);
  let secondSettled = false;
  second.then(() => {
    secondSettled = true;
  }, () => {
    secondSettled = true;
  });
  await Promise.resolve();
  assert.equal(reads.length, 1);
  assert.equal(secondSettled, false);
  releaseFirstRead();
  await Promise.all([first, second]);

  assert.equal(reads.length, 5);
  assert.equal(secondSettled, true);
  assert.deepEqual(Array.from(repository.getTopics('cs101')), ['二叉树']);
});

test('课程内容仓储读取失败后清空半成品并允许同进程重试', async () => {
  const repository = loadLearningContentRepository();
  const expectedPaths = [
    'learning/knowledge-chunks.json',
    'learning/quizzes.json',
    'learning/external-resources.json',
    'learning/topic-relations.json',
    'learning/lesson-experiences.json'
  ];
  const reads = [];
  let failResourcesRead = true;
  const manager = {
    getRawFileContent: async (pathName) => {
      reads.push(pathName);
      if (pathName === 'learning/external-resources.json' && failResourcesRead) {
        failResourcesRead = false;
        throw new Error('fixture read failed');
      }
      return contentFixture(pathName);
    }
  };

  await assert.rejects(repository.initialize(manager), /课程内容仓储初始化失败/);
  assert.deepEqual(reads, expectedPaths.slice(0, 3));
  assert.deepEqual(Array.from(repository.getKnowledge('cs101')), []);
  assert.deepEqual(Array.from(repository.getQuestions('cs101')), []);
  assert.deepEqual(Array.from(repository.getResources('cs101')), []);
  assert.deepEqual(Array.from(repository.getTopics('cs101')), []);

  await repository.initialize(manager);
  assert.deepEqual(reads, [...expectedPaths.slice(0, 3), ...expectedPaths]);
  assert.deepEqual(Array.from(repository.getTopics('cs101')), ['二叉树']);
});

test('Form Ability 三条系统入口均等待课程内容初始化完成后再访问 ArkData', async () => {
  async function assertEntryOrder(trigger, expectedCalls) {
    const calls = [];
    let releaseContent;
    const contentGate = new Promise((resolve) => {
      releaseContent = resolve;
    });
    const EntryFormAbility = loadEntryFormAbility({
      defaultData: () => ({}),
      refreshForm: async (formId) => {
        calls.push(`refresh:${formId}`);
      }
    }, {
      initialize: async () => {
        calls.push('local');
      },
      registerFormId: async (formId) => {
        calls.push(`register:${formId}`);
      },
      removeFormId: async (formId) => {
        calls.push(`remove:${formId}`);
      }
    }, {
      initialize: async (manager) => {
        assert.equal(manager.name, 'form-resource-manager');
        calls.push('content:start');
        await contentGate;
        calls.push('content:done');
      }
    });
    const ability = new EntryFormAbility();

    trigger(ability);
    await Promise.resolve();
    assert.deepEqual(calls, ['content:start']);
    releaseContent();
    await settleAsyncWork();
    assert.deepEqual(calls, ['content:start', 'content:done', ...expectedCalls]);
  }

  await assertEntryOrder(
    (ability) => ability.onUpdateForm('form-update'),
    ['local', 'refresh:form-update']
  );
  await assertEntryOrder(
    (ability) => ability.onAddForm({
      parameters: { 'ohos.extra.param.key.form_identity': 'form-add' }
    }),
    ['local', 'register:form-add', 'refresh:form-add']
  );
  await assertEntryOrder(
    (ability) => ability.onRemoveForm('form-remove'),
    ['local', 'remove:form-remove']
  );
});

test('Form Ability 更新失败后系统再次更新仍会委托刷新', async () => {
  let initializeCalls = 0;
  let refreshCalls = 0;
  const EntryFormAbility = loadEntryFormAbility({
    defaultData: () => ({}),
    refreshForm: async () => {
      refreshCalls += 1;
      if (refreshCalls === 1) throw new Error('first update failed');
    }
  }, {
    initialize: async () => {
      initializeCalls += 1;
    },
    registerFormId: async () => {},
    removeFormId: async () => {}
  });
  const ability = new EntryFormAbility();

  ability.onUpdateForm('form-1');
  await settleAsyncWork();
  ability.onUpdateForm('form-1');
  await settleAsyncWork();

  assert.equal(initializeCalls, 2);
  assert.equal(refreshCalls, 2);
});

test('冷启动期间同一有效 Want 重复到达只写入一次跳转', async () => {
  const harness = createEntryHarness();
  const ability = new harness.EntryAbility();

  ability.onCreate(validWant(), {});
  ability.onNewWant(validWant(), {});
  await ability.startMainPage(harness.windowStage);

  assert.equal(harness.storage.get('proactiveLaunchVersion'), 1);
  assert.equal(harness.storage.get('proactiveTargetPage'), 'pages/CourseDetail');
  assert.equal(harness.storage.get('selectedCourseTitle'), '数据结构');
});

test('热启动前台周期内同一有效 Want 顺序到达只写入一次跳转', async () => {
  const harness = createEntryHarness();
  const ability = new harness.EntryAbility();
  ability.repositoriesReady = true;

  ability.onNewWant(validWant(), {});
  await settleAsyncWork();
  ability.onNewWant(validWant(), {});
  await settleAsyncWork();

  assert.equal(harness.storage.get('proactiveLaunchVersion'), 1);
  assert.equal(harness.storage.get('proactiveTargetPage'), 'pages/CourseDetail');
});

test('同一 Want 在进入后台后可于新前台周期再次触发跳转', async () => {
  const harness = createEntryHarness();
  const ability = new harness.EntryAbility();
  ability.repositoriesReady = true;

  ability.onNewWant(validWant(), {});
  ability.onNewWant(validWant(), {});
  await settleAsyncWork();
  assert.equal(harness.storage.get('proactiveLaunchVersion'), 1);

  ability.onBackground();
  ability.onNewWant(validWant(), {});
  await settleAsyncWork();

  assert.equal(harness.storage.get('proactiveLaunchVersion'), 2);
});

test('非法主动 payload 不写入任何导航 AppStorage', async () => {
  const harness = createEntryHarness();
  const ability = new harness.EntryAbility();
  ability.repositoriesReady = true;
  const before = harness.storage.navigationSnapshot();

  const invalidSource = validWant();
  invalidSource.parameters.source = 'external_widget';
  ability.onNewWant(invalidSource, {});
  await settleAsyncWork();

  const mismatchedTarget = validWant();
  mismatchedTarget.parameters.targetPage = 'pages/Lesson';
  ability.onNewWant(mismatchedTarget, {});
  await settleAsyncWork();

  const missingTopic = validWant();
  delete missingTopic.parameters.topic;
  ability.onNewWant(missingTopic, {});
  await settleAsyncWork();

  assert.deepEqual(harness.storage.navigationSnapshot(), before);
});

test('Index 按当前栈导航并只在成功后消费目标', () => {
  const source = readSource(indexPath);
  assert.equal(source.includes(
    "@StorageLink('proactiveLaunchVersion') @Watch('consumeProactiveLaunch') proactiveLaunchVersion: number = 0;"),
  true, 'Index proactive launch watcher changed');
  const consumeStart = source.indexOf('  private consumeProactiveLaunch(): void {');
  const navigateStart = source.indexOf('  private navigateProactiveLaunch(', consumeStart);
  const completeStart = source.indexOf('  private completeProactiveNavigation(', navigateStart);
  const failStart = source.indexOf('  private failProactiveNavigation(', completeStart);
  const releaseStart = source.indexOf('  private releaseProactiveNavigation(', failStart);
  assert.notEqual(consumeStart, -1, 'Index.consumeProactiveLaunch missing');
  assert.notEqual(navigateStart, -1, 'Index.navigateProactiveLaunch missing');
  assert.notEqual(completeStart, -1, 'Index.completeProactiveNavigation missing');
  assert.notEqual(failStart, -1, 'Index.failProactiveNavigation missing');
  assert.notEqual(releaseStart, -1, 'Index.releaseProactiveNavigation missing');

  const consume = source.slice(consumeStart, navigateStart);
  const navigate = source.slice(navigateStart, completeStart);
  const complete = source.slice(completeStart, failStart);
  const fail = source.slice(failStart, releaseStart);
  const clearTarget = "AppStorage.setOrCreate<string>('proactiveTargetPage', '');";
  assert.equal(consume.includes(clearTarget), false, 'Index must retain the target before navigation starts');
  assert.equal(navigate.includes("appRouter.back({ url: 'pages/Index' });"), true,
    'nested course launch must return to the existing root page');
  assert.equal(navigate.includes('appRouter.pushUrl({ url: targetPage })'), true,
    'root-to-subpage launch must push a route');
  assert.equal(navigate.includes('appRouter.replaceUrl({ url: targetPage })'), true,
    'nested-to-subpage launch must replace the current child route');
  assert.equal(complete.includes(clearTarget), true, 'successful navigation must consume the target');
  assert.equal(fail.includes(clearTarget), false, 'failed navigation must retain the target for retry');
});

test('首页提醒以 loading 防并发并在错误态提供可执行重试', () => {
  const source = readSource(homeContentPath);
  const methodStart = source.indexOf('  private async publishReminder(): Promise<void> {');
  const methodEnd = source.indexOf('\n  private submitQuickAsk(', methodStart);
  assert.notEqual(methodStart, -1, 'HomeContent.publishReminder missing');
  assert.notEqual(methodEnd, -1, 'HomeContent.publishReminder boundary changed');
  const method = source.slice(methodStart, methodEnd);
  const guardIndex = method.indexOf("if (this.notificationState === 'loading') return;");
  const openIndex = method.indexOf('this.notificationOpen = true;');
  const loadingIndex = method.indexOf("this.notificationState = 'loading';");
  const publishIndex = method.indexOf('LearningReminder.publishNextTask(hostContext)');
  const errorIndex = method.indexOf("this.notificationState = 'error';");
  assert.notEqual(guardIndex, -1, 'HomeContent loading guard missing');
  assert.notEqual(openIndex, -1, 'HomeContent notification visibility write missing');
  assert.notEqual(loadingIndex, -1, 'HomeContent loading state write missing');
  assert.notEqual(publishIndex, -1, 'HomeContent reminder publish call missing');
  assert.notEqual(errorIndex, -1, 'HomeContent error state write missing');
  assert.equal(guardIndex < loadingIndex && loadingIndex < publishIndex, true,
    'HomeContent must guard concurrent requests before entering loading and publishing');
  assert.equal(openIndex < publishIndex && publishIndex < errorIndex, true,
    'HomeContent must keep failures visible after a publish attempt');

  const headerStart = source.indexOf('  @Builder\n  Header() {');
  const headerEnd = source.indexOf('\n  @Builder\n  ContinueCard()', headerStart);
  assert.notEqual(headerStart, -1, 'HomeContent.Header missing');
  assert.notEqual(headerEnd, -1, 'HomeContent.Header boundary changed');
  const header = source.slice(headerStart, headerEnd);
  const visibleErrorIndex = header.indexOf("if (this.notificationState === 'error') {");
  const retryButtonIndex = header.indexOf("Button('重试')", visibleErrorIndex);
  const retryCallIndex = header.indexOf('this.publishReminder();', retryButtonIndex);
  assert.notEqual(visibleErrorIndex, -1, 'HomeContent visible error branch missing');
  assert.notEqual(retryButtonIndex, -1, 'HomeContent retry button missing');
  assert.notEqual(retryCallIndex, -1, 'HomeContent retry action missing');
  assert.equal(visibleErrorIndex < retryButtonIndex && retryButtonIndex < retryCallIndex, true,
    'HomeContent error branch must show a retry button that republishes');
});

test('首页提醒和卡片同步入口具备动态播报与 48vp 触控区', () => {
  const source = readSource(homeContentPath);
  const headerStart = source.indexOf('  @Builder\n  Header() {');
  const headerEnd = source.indexOf('\n  @Builder\n  ContinueCard()', headerStart);
  assert.notEqual(headerStart, -1);
  assert.notEqual(headerEnd, -1);
  const header = source.slice(headerStart, headerEnd);

  const bellIconIndex = header.indexOf("SymbolGlyph($r('sys.symbol.bell_fill'))");
  const bellStart = header.lastIndexOf('        Button() {', bellIconIndex);
  const bellEnd = header.indexOf('\n      if (this.notificationOpen)', bellIconIndex);
  const bell = header.slice(bellStart, bellEnd);
  assert.notEqual(bellIconIndex, -1);
  assert.notEqual(bellStart, -1);
  assert.notEqual(bellEnd, -1);
  assert.equal(bell.includes('.width(48)'), true);
  assert.equal(bell.includes('.height(48)'), true);
  assert.equal(bell.includes('.accessibilityText('), true);
  assert.equal(bell.includes("this.notificationState === 'loading'"), true);

  const warningRetryStart = header.indexOf("Button('重试同步')");
  const warningRetryEnd = header.indexOf('\n              .onClick(', warningRetryStart);
  const warningRetry = header.slice(warningRetryStart, warningRetryEnd);
  assert.notEqual(warningRetryStart, -1);
  assert.notEqual(warningRetryEnd, -1);
  assert.equal(warningRetry.includes('.height(48)'), true);
  assert.equal(warningRetry.includes(".accessibilityText('重试同步当前学习任务到服务卡片')"), true);
  assert.equal(header.includes("this.notificationState !== 'warning'"), true);
});

test('服务卡片整卡入口播报行动、进度与推荐依据', () => {
  const source = readSource(planCardPath);
  const formLinkStart = source.indexOf('    FormLink({');
  assert.notEqual(formLinkStart, -1);
  const formLink = source.slice(formLinkStart);
  assert.equal(formLink.includes('.accessibilityGroup(true)'), true);
  const textStart = formLink.indexOf('.accessibilityText(');
  const descriptionStart = formLink.indexOf('.accessibilityDescription(');
  assert.notEqual(textStart, -1);
  assert.notEqual(descriptionStart, -1);
  const textExpression = formLink.slice(textStart, descriptionStart);
  assert.equal(textExpression.includes('this.cta'), true);
  assert.equal(textExpression.includes('this.title'), true);
  assert.equal(textExpression.includes('this.progressText'), true);
  assert.equal(formLink.slice(descriptionStart).includes('this.evidence'), true);
});
