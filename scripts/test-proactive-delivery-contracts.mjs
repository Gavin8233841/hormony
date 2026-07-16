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
  const repositoryImport = "import { LocalLearningRepository } from '../common/LocalLearningRepository';";
  let source = removeImports(readSource(entryFormAbilityPath),
    [formImport, abilityImport, updaterImport, repositoryImport], entryFormAbilityPath);
  assert.equal(source.includes('export default class EntryFormAbility extends FormExtensionAbility'), true,
    'EntryFormAbility export changed');
  source = source.replace('export default class EntryFormAbility extends FormExtensionAbility',
    'class EntryFormAbility extends FormExtensionAbility');
  source = `const formBindingData = globalThis.__formBindingData;
const FormExtensionAbility = globalThis.__FormExtensionAbility;
const formInfo = globalThis.__formInfo;
const LearningFormUpdater = globalThis.__formUpdater;
const LocalLearningRepository = globalThis.__repository;
${source}
globalThis.__EntryFormAbility = EntryFormAbility;
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
    "import { ProactiveLearningLaunch, ProactiveLearningService } from '../common/ProactiveLearningService';"
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

function compileHomeReminderHarness() {
  const source = readSource(homeContentPath);
  const methodStart = source.indexOf('  private async publishReminder(): Promise<void> {');
  const methodEnd = source.indexOf('\n  private submitQuickAsk(', methodStart);
  assert.notEqual(methodStart, -1, 'HomeContent.publishReminder missing');
  assert.notEqual(methodEnd, -1, 'HomeContent.publishReminder boundary changed');
  const method = source.slice(methodStart, methodEnd);
  const transformed = `const LearningReminder = globalThis.__reminder;
const LearningFormUpdater = globalThis.__formUpdater;
class HomeReminderHarness {
  notificationOpen = false;
  notificationState = 'idle';
  notificationMessage = '';

  getUIContext() {
    return { getHostContext: () => globalThis.__hostContext };
  }

  applyNextAction(action) {
    globalThis.__appliedActions.push(action);
  }

${method}
}
globalThis.__HomeReminderHarness = HomeReminderHarness;
`;
  return stripTypeScriptTypes(transformed, { mode: 'transform', sourceMap: false });
}

const compiledService = compileService();
const compiledReminder = compileReminder();
const compiledFormUpdater = compileFormUpdater();
const compiledEntryFormAbility = compileEntryFormAbility();
const compiledEntryAbility = compileEntryAbility();
const compiledHomeReminderHarness = compileHomeReminderHarness();

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

function loadEntryFormAbility(formUpdater, repository) {
  class FormExtensionAbility {
    constructor() {
      this.context = { name: 'form-context' };
    }
  }
  const context = vm.createContext({
    __FormExtensionAbility: FormExtensionAbility,
    __formUpdater: formUpdater,
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

function loadHomeReminderHarness(reminder, formUpdater) {
  const appliedActions = [];
  const hostContext = { name: 'home-context' };
  const context = vm.createContext({
    __reminder: reminder,
    __formUpdater: formUpdater,
    __appliedActions: appliedActions,
    __hostContext: hostContext
  });
  vm.runInContext(compiledHomeReminderHarness, context, { filename: homeContentPath });
  return {
    instance: new context.__HomeReminderHarness(),
    appliedActions,
    hostContext
  };
}

function formDataSnapshot(data) {
  return JSON.parse(JSON.stringify(data));
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
    getCourses: async () => catalog
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

  const reminderAction = await reminder.publishNextTask({ name: 'ui-context' });
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
    assert.equal(reminderAction[key], cardData[key], `${key} must be returned for HomeContent reuse`);
  }
  const presentationFields = ['kind', 'badge', 'title', 'subtitle', 'cta', 'evidence', 'progressText'];
  for (const key of presentationFields) {
    assert.equal(reminderAction[key], cardData[key], `${key} must be returned for HomeContent reuse`);
  }

  const cardSource = readSource(planCardPath);
  assert.equal(cardSource.includes("source: 'proactive_learning_card'"), true);
  for (const key of executableFields) {
    assert.equal(cardSource.includes(`${key}: this.${key}`), true,
      `LearningPlanCard must route with refreshed ${key}`);
  }
});

test('首页提醒成功后以通知返回行动同步首页和所有服务卡片', async () => {
  const action = await loadService().resolve(fixedNow);
  const refreshedActions = [];
  const reminder = {
    publishNextTask: async (context) => {
      assert.equal(context.name, 'home-context');
      return action;
    }
  };
  const formUpdater = {
    refreshAllWithAction: async (resolvedAction) => {
      refreshedActions.push(resolvedAction);
    }
  };
  const harness = loadHomeReminderHarness(reminder, formUpdater);

  await harness.instance.publishReminder();

  assert.equal(harness.instance.notificationOpen, true);
  assert.equal(harness.instance.notificationState, 'success');
  assert.equal(harness.instance.notificationMessage, '系统提醒已创建：' + action.title);
  assert.equal(harness.appliedActions.length, 1);
  assert.equal(refreshedActions.length, 1);
  assert.equal(harness.appliedActions[0], action, 'HomeContent must apply the exact notification action object');
  assert.equal(refreshedActions[0], action, 'cards must receive the exact notification action object');
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
    updateForm: async (formId, data) => updates.push({ formId, data: formDataSnapshot(data) })
  }, {
    getFormIds: async () => ['form-1', 'form-2']
  });

  await formUpdater.refreshAll();

  assert.equal(resolveCalls, 1, 'refreshAll must resolve next-best-action once per refresh batch');
  assert.deepEqual(updates.map((update) => update.formId), ['form-1', 'form-2']);
  assert.deepEqual(updates[0].data, updates[1].data, 'all forms must render one immutable action snapshot');
});

test('显式行动刷新所有服务卡片时不会再次解析状态', async () => {
  const action = await loadService().resolve(fixedNow);
  let resolveCalls = 0;
  const updates = [];
  const formUpdater = loadFormUpdater({
    resolve: async () => {
      resolveCalls += 1;
      throw new Error('explicit action must not resolve again');
    },
    fallback: () => action
  }, {
    updateForm: async (formId, data) => updates.push({ formId, data: formDataSnapshot(data) })
  }, {
    getFormIds: async () => ['form-1', 'form-2']
  });

  await formUpdater.refreshAllWithAction(action);

  assert.equal(resolveCalls, 0);
  assert.equal(updates.length, 2);
  assert.deepEqual(updates[0].data, formDataSnapshot(action));
  assert.deepEqual(updates[1].data, formDataSnapshot(action));
});

test('本地状态变化后单张服务卡片重新解析新的 next-best-action', async () => {
  const firstAction = await loadService().resolve(fixedNow);
  const secondAction = {
    kind: 'plan',
    badge: '今日起步',
    title: '制定今天的学习计划',
    subtitle: '让学伴把目标拆成可执行任务',
    cta: '制定计划',
    courseId: '',
    courseTitle: '',
    topic: '',
    focusTag: '',
    taskAction: 'plan',
    targetPage: 'pages/Plan',
    evidence: '本机还没有可继续的课程状态或今日任务',
    progressText: '等待制定计划'
  };
  const queuedActions = [firstAction, secondAction];
  const updates = [];
  const formUpdater = loadFormUpdater({
    resolve: async () => queuedActions.shift(),
    fallback: () => secondAction
  }, {
    updateForm: async (_formId, data) => updates.push(formDataSnapshot(data))
  });

  await formUpdater.refreshForm('form-1');
  await formUpdater.refreshForm('form-1');

  assert.equal(updates.length, 2);
  assert.equal(updates[0].kind, firstAction.kind);
  assert.equal(updates[0].targetPage, firstAction.targetPage);
  assert.equal(updates[1].kind, 'plan');
  assert.equal(updates[1].targetPage, 'pages/Plan');
  assert.notDeepEqual(updates[0], updates[1]);
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
  assert.equal(harness.storage.get('proactiveTargetPage'), 'pages/Quiz');
  assert.equal(harness.storage.get('selectedCourseTitle'), '数据结构');
});

test('热启动期间同一有效 Want 重复到达只写入一次跳转', async () => {
  const harness = createEntryHarness();
  const ability = new harness.EntryAbility();
  ability.repositoriesReady = true;

  ability.onNewWant(validWant(), {});
  ability.onNewWant(validWant(), {});
  await settleAsyncWork();

  assert.equal(harness.storage.get('proactiveLaunchVersion'), 1);
  assert.equal(harness.storage.get('proactiveTargetPage'), 'pages/Quiz');
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

test('Index 用版本守卫幂等消费并在导航前清空目标', () => {
  const source = readSource(indexPath);
  assert.equal(source.includes(
    "@StorageLink('proactiveLaunchVersion') @Watch('consumeProactiveLaunch') proactiveLaunchVersion: number = 0;"),
  true, 'Index proactive launch watcher changed');
  const methodStart = source.indexOf('  private consumeProactiveLaunch(): void {');
  const methodEnd = source.indexOf('\n  private selectTab(', methodStart);
  assert.notEqual(methodStart, -1, 'Index.consumeProactiveLaunch missing');
  assert.notEqual(methodEnd, -1, 'Index.consumeProactiveLaunch boundary changed');
  const method = source.slice(methodStart, methodEnd);
  const guardIndex = method.indexOf(
    'if (this.consumedLaunchVersion === this.proactiveLaunchVersion) return;');
  const consumeIndex = method.indexOf('this.consumedLaunchVersion = this.proactiveLaunchVersion;');
  const clearIndex = method.indexOf("AppStorage.setOrCreate<string>('proactiveTargetPage', '');");
  const routeIndex = method.indexOf('this.getUIContext().getRouter().pushUrl({ url: targetPage })');
  assert.notEqual(guardIndex, -1, 'Index version guard missing');
  assert.notEqual(consumeIndex, -1, 'Index consumed version write missing');
  assert.notEqual(clearIndex, -1, 'Index target clear missing');
  assert.notEqual(routeIndex, -1, 'Index proactive route missing');
  assert.equal(guardIndex < consumeIndex, true, 'Index must guard before consuming a version');
  assert.equal(clearIndex < routeIndex, true, 'Index must clear the target before routing');
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

test('首页提醒入口具备动态无障碍语义与 48vp 最小触控区', () => {
  const source = readSource(homeContentPath);
  const headerStart = source.indexOf('  @Builder\n  Header() {');
  const headerEnd = source.indexOf('\n  @Builder\n  ContinueCard()', headerStart);
  assert.notEqual(headerStart, -1, 'HomeContent.Header missing');
  assert.notEqual(headerEnd, -1, 'HomeContent.Header boundary changed');
  const header = source.slice(headerStart, headerEnd);

  const bellIconIndex = header.indexOf("SymbolGlyph($r('sys.symbol.bell_fill'))");
  const bellStart = header.lastIndexOf('          Button() {', bellIconIndex);
  const bellEnd = header.indexOf('\n\n          Column()', bellIconIndex);
  assert.notEqual(bellIconIndex, -1, 'HomeContent reminder bell missing');
  assert.notEqual(bellStart, -1, 'HomeContent reminder button boundary changed');
  assert.notEqual(bellEnd, -1, 'HomeContent reminder button end changed');
  const bell = header.slice(bellStart, bellEnd);
  assert.equal(bell.includes('.width(48)'), true, 'reminder button must be at least 48vp wide');
  assert.equal(bell.includes('.height(48)'), true, 'reminder button must be at least 48vp high');
  const bellAccessibility = bell.indexOf('.accessibilityText(');
  assert.notEqual(bellAccessibility, -1, 'reminder button accessibility text missing');
  assert.equal(bell.slice(bellAccessibility).includes("this.notificationState === 'loading'"), true,
    'reminder accessibility text must expose loading state');

  const retryStart = header.indexOf("            Button('重试')");
  const retryEnd = header.indexOf('\n              .onClick(', retryStart);
  assert.notEqual(retryStart, -1, 'HomeContent reminder retry button missing');
  assert.notEqual(retryEnd, -1, 'HomeContent reminder retry boundary changed');
  const retry = header.slice(retryStart, retryEnd);
  assert.equal(retry.includes('.height(48)'), true, 'reminder retry must provide a 48vp touch target');
  assert.equal(retry.includes(".accessibilityText('重试创建当前学习提醒')"), true,
    'reminder retry must state its action instead of only reading “重试”');

  const statusStart = header.indexOf('        Row({ space: 8 }) {', header.indexOf('if (this.notificationOpen)'));
  const statusEnd = header.indexOf('\n      }\n    }', statusStart);
  assert.notEqual(statusStart, -1, 'HomeContent reminder status row missing');
  assert.notEqual(statusEnd, -1, 'HomeContent reminder status boundary changed');
  const status = header.slice(statusStart, statusEnd);
  assert.equal(status.includes(".accessibilityGroup(this.notificationState !== 'error')"), true,
    'non-error status must be announced as one group while error keeps retry independently focusable');
  assert.equal(status.includes(
    ".accessibilityText(this.notificationState === 'error' ? '' : this.notificationMessage)"), true,
  'reminder status must expose the current loading or success message');
});

test('服务卡片整卡入口播报行动、进度与推荐依据', () => {
  const source = readSource(planCardPath);
  const formLinkStart = source.indexOf('    FormLink({');
  assert.notEqual(formLinkStart, -1, 'LearningPlanCard FormLink missing');
  const formLink = source.slice(formLinkStart);
  assert.equal(formLink.includes('.accessibilityGroup(true)'), true,
    'LearningPlanCard must expose the whole FormLink as one action');
  const textStart = formLink.indexOf('.accessibilityText(');
  const descriptionStart = formLink.indexOf('.accessibilityDescription(');
  assert.notEqual(textStart, -1, 'LearningPlanCard accessibility text missing');
  assert.notEqual(descriptionStart, -1, 'LearningPlanCard accessibility description missing');
  const textExpression = formLink.slice(textStart, descriptionStart);
  assert.equal(textExpression.includes('this.cta'), true, 'card accessibility text must include the command');
  assert.equal(textExpression.includes('this.title'), true, 'card accessibility text must include the task');
  assert.equal(textExpression.includes('this.progressText'), true, 'card accessibility text must include progress');
  assert.equal(formLink.slice(descriptionStart).includes('this.evidence'), true,
    'card accessibility description must include the recommendation evidence');
});
