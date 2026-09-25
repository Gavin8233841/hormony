import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

function source(relativePath) {
  return readFileSync(resolve(repositoryRoot, relativePath), 'utf8').replace(/\r\n/g, '\n');
}

function section(text, startMarker, endMarker, label) {
  const start = text.indexOf(startMarker);
  assert.notEqual(start, -1, `${label}: missing start marker ${startMarker}`);
  const end = text.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `${label}: missing end marker ${endMarker}`);
  return text.slice(start, end);
}

function assertOrder(text, markers, label) {
  let cursor = -1;
  for (const marker of markers) {
    const index = text.indexOf(marker, cursor + 1);
    assert.notEqual(index, -1, `${label}: missing ${marker}`);
    assert.ok(index > cursor, `${label}: ${marker} is out of order`);
    cursor = index;
  }
}

function occurrences(text, marker) {
  let count = 0;
  let cursor = 0;
  while (true) {
    const index = text.indexOf(marker, cursor);
    if (index === -1) return count;
    count += 1;
    cursor = index + marker.length;
  }
}

const httpClient = source('apps/harmonyos/entry/src/main/ets/common/HttpClient.ets');
const chat = source('apps/harmonyos/entry/src/main/ets/pages/Chat.ets');
const plan = source('apps/harmonyos/entry/src/main/ets/pages/Plan.ets');
const home = source('apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets');
const localRepository = source('apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets');

function compileLocalLearningRepository() {
  const imports = [
    "import { relationalStore } from '@kit.ArkData';",
    "import { common } from '@kit.AbilityKit';",
    `import {
  ChatMessage,
  AchievementProgress,
  Course,
  LessonProgress,
  PlanTaskUpdateReceipt,
  StudyPlan,
  TopicMastery,
  UserProfile
} from '../model/DataModels';`,
    `import {
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail,
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight,
  LegacyQuizHistorySnapshot,
  LegacyQuizTopicHistorySnapshot,
  QuizLearningState,
  QuizWriteReceipt,
  TopicMasteryMilestone
} from '../model/LearningMetadataModels';`,
    "import { LearningContentRepository } from './LearningContentRepository';",
    "import { QuizLearningStateReducer } from './QuizLearningStateReducer';"
  ];
  let transformed = localRepository;
  for (const expectedImport of imports) {
    assert.equal(transformed.includes(expectedImport), true,
      `LocalLearningRepository import changed: ${expectedImport}`);
    transformed = transformed.replace(expectedImport, '');
  }
  assert.equal(transformed.includes('export class LocalLearningRepository'), true);
  transformed = transformed.replace('export class LocalLearningRepository', 'class LocalLearningRepository');
  transformed = `const LearningContentRepository = globalThis.__learningContentRepository;
const QuizLearningStateReducer = globalThis.__quizLearningStateReducer;
${transformed}
globalThis.__LocalLearningRepository = LocalLearningRepository;
`;
  return stripTypeScriptTypes(transformed, { mode: 'transform', sourceMap: false });
}

test('Chat submits the native TextInput value to the real SSE endpoint', () => {
  const input = section(chat, '          TextInput({', '\n\n          Button() {', 'Chat input');
  assert.match(input, /text:\s*\$\$this\.inputText/);
  assert.match(input, /\.onChange\(\(value: string\) => \{\s*this\.inputText = value;/);
  assert.match(input, /\.onSubmit\(\(_enterKey: EnterKeyType, event: SubmitEvent\): void => \{\s*this\.inputText = event\.text;\s*this\.sendMessage\(event\.text\);/);

  const send = section(chat, '  sendMessage(question?: string): void {', '  private isActiveRequest(', 'Chat send');
  assertOrder(send, [
    'const content = question !== undefined ? question.trim() : this.inputText.trim();',
    "role: 'user'",
    'const message = content;',
    'const req: ChatRequest = {',
    'message: message,',
    'startDate: this.localDateKey(),',
    'this.startSseRequest(req, requestId, cancellation);'
  ], 'Chat send payload');

  const startSse = section(chat, '  private startSseRequest(', '  private streamFailureMessage(', 'Chat SSE request');
  assert.match(startSse, /HttpClient\.postSSE\(Constants\.API_CHAT, JSON\.stringify\(req\)/);
});

test('Chat keeps request identity monotonic across page leave and re-entry', () => {
  const requestState = section(chat, '  private currentRequest:', '  // 推荐问题', 'Chat request state');
  assertOrder(requestState, [
    'private currentRequest: http.HttpRequest | null = null;',
    'private currentCancellation: HttpRequestCancellation | null = null;',
    'private isCancelled: boolean = false;',
    'private receivedDone: boolean = false;',
    'private requestSequence: number = 0;',
    'private activeRequestId: number = 0;',
    'private historySaveQueued: boolean = false;',
    'private lifecycleRunId: number = 0;',
    'private pageActive: boolean = false;'
  ], 'Chat request identity fields');

  const lifecycle = section(chat, '  aboutToAppear(): void {', '  private canSend(): boolean {', 'Chat lifecycle');
  const appear = section(lifecycle, '  aboutToAppear(): void {', '  aboutToDisappear(): void {', 'Chat appear');
  assertOrder(appear, [
    'this.lifecycleRunId += 1;',
    'const lifecycleRunId = this.lifecycleRunId;',
    'this.pageActive = true;',
    'this.isCancelled = false;',
    'this.currentRequest = null;',
    'this.currentCancellation = null;',
    'this.receivedDone = false;',
    'this.activeRequestId = 0;',
    'this.loadLocalHistory(lifecycleRunId);',
    'this.probeCloudAgent(lifecycleRunId);'
  ], 'Chat re-entry state');
  assert.doesNotMatch(appear, /requestSequence/);
  const disappear = section(chat, '  aboutToDisappear(): void {', '  private isActiveLifecycle(', 'Chat disappear');
  assertOrder(disappear, [
    'this.pageActive = false;',
    'this.lifecycleRunId += 1;',
    'this.cancelCurrentRequest(false);'
  ], 'Chat leave lifecycle invalidation');
  const activeLifecycle = section(chat, '  private isActiveLifecycle(', '  private canSend(): boolean {',
    'Chat active lifecycle');
  assert.match(activeLifecycle, /return this\.pageActive && this\.lifecycleRunId === lifecycleRunId;/);

  const cancel = section(chat, '  private cancelCurrentRequest(', '  private retryMessage(', 'Chat request invalidation');
  assertOrder(cancel, [
    'this.isCancelled = true;',
    'this.activeRequestId = 0;',
    'const request = this.currentRequest;',
    'const cancellation = this.currentCancellation;',
    'this.currentRequest = null;',
    'this.currentCancellation = null;',
    'cancellation.cancel();',
    'this.loading = false;',
    'this.receivedDone = false;'
  ], 'Chat leave invalidates the active request');

  const send = section(chat, '  sendMessage(question?: string): void {', '  private isActiveRequest(', 'Chat request allocation');
  assertOrder(send, [
    'this.loading = true;',
    'this.isCancelled = false;',
    'this.receivedDone = false;',
    'this.requestSequence += 1;',
    'const requestId = this.requestSequence;',
    'const cancellation = new HttpRequestCancellation();',
    'this.activeRequestId = requestId;',
    'this.currentCancellation = cancellation;',
    'LocalLearningRepository.getProfile().then((profile): void => {',
    'this.startSseRequest(req, requestId, cancellation);'
  ], 'Chat request identity allocation');
  assert.equal(occurrences(send, 'this.startSseRequest(req, requestId, cancellation);'), 2);

  const active = section(chat, '  private isActiveRequest(', '  private startSseRequest(', 'Chat active request');
  assert.match(active, /return requestId === this\.activeRequestId && !this\.isCancelled;/);
  const startSse = section(chat, '  private startSseRequest(', '  private streamFailureMessage(', 'Chat SSE identity guards');
  assert.match(startSse, /if \(!this\.isActiveRequest\(requestId\) \|\| !this\.loading\) return;/);
  assert.equal(occurrences(startSse, 'if (!this.isActiveRequest(requestId))'), 4);
  const created = section(startSse, '      (reqInstance: http.HttpRequest) => {', '      cancellation', 'Chat delayed request creation');
  assertOrder(created, [
    'if (!this.isActiveRequest(requestId)) {',
    'reqInstance.destroy();',
    'return;',
    'this.currentRequest = reqInstance;'
  ], 'Chat rejects stale created requests');

  const probe = section(chat, '  private async probeCloudAgent(', '  private scrollToBottom(', 'Chat cloud probe');
  assert.match(probe, /lifecycleRunId: number = this\.lifecycleRunId/);
  assert.equal(occurrences(probe, 'if (!this.isActiveLifecycle(lifecycleRunId)) return;'), 3);
  assert.match(probe, /finally \{\s*if \(this\.isActiveLifecycle\(lifecycleRunId\)\) \{\s*this\.probing = false;/);
});

test('HttpClient cancellation prevents POST and SSE fallback requests', () => {
  const cancellation = section(httpClient, 'export class HttpRequestCancellation {', 'export class HttpClient {', 'HTTP cancellation');
  assertOrder(cancellation, [
    'cancel(): void {',
    'this.cancelled = true;',
    'this.request = null;',
    'request.destroy();'
  ], 'Cancellation destroys the active request');

  const post = section(httpClient, '  static async post<T>(', '  /**\n   * 发送 PATCH 请求', 'HTTP POST');
  assertOrder(post, [
    'for (const baseUrl of Constants.API_BASE_URLS) {',
    'if (cancellation?.isCancelled()) {',
    "throw new Error('REQUEST_CANCELLED');",
    'const httpRequest = http.createHttp();',
    'const response = await httpRequest.request(',
    'if (cancellation?.isCancelled()) {',
    "throw new Error('REQUEST_CANCELLED');",
    'if (response.responseCode !== 200)'
  ], 'POST cancellation checkpoints');
  assertOrder(post, [
    '} catch (e) {',
    "if (cancellation?.isCancelled() || error.message === 'REQUEST_CANCELLED') {",
    "throw new Error('REQUEST_CANCELLED');",
    'lastNetworkError = error;'
  ], 'POST cancellation exits before retry');

  const postSse = section(httpClient, '  static postSSE(', '\n  }\n}', 'HTTP SSE');
  assertOrder(postSse, [
    'const startRequest = (baseIndex: number): void => {',
    'if (cancellation?.isCancelled()) return;',
    'const httpRequest = http.createHttp();'
  ], 'SSE cancellation before request creation');
  const rejectedRequest = section(postSse, '      }).catch((e: Error) => {', '      });\n    };', 'SSE rejected request');
  assertOrder(rejectedRequest, [
    'cleanup();',
    'if (cancellation?.isCancelled()) return;',
    'if (!receivedData && baseIndex + 1 < Constants.API_BASE_URLS.length) {',
    'startRequest(baseIndex + 1);'
  ], 'SSE cancellation exits before fallback');
});

test('SSE done and error paths are exclusive and preserve structured failures', () => {
  const postSse = section(httpClient, '  static postSSE(', '\n  }\n}', 'HTTP SSE');
  const consume = section(postSse, '    const consumeText = (text: string): boolean => {', '    const startRequest = ', 'SSE parser');
  assertOrder(consume, [
    'const evt: StreamEvent = JSON.parse(jsonStr);',
    'onEvent(evt);',
    "if (evt.type === 'done' && !doneCalled) {",
    'doneCalled = true;',
    'onDone();'
  ], 'SSE done event');

  const finishStream = section(postSse, '      const finishStream = (): void => {', '      const finishHttpError', 'SSE success terminal');
  assertOrder(finishStream, [
    "if (eventBuffer.trim().length > 0) {",
    "consumeText('\\n\\n');",
    'if (!doneCalled) {',
    'doneCalled = true;',
    'onDone();',
    'cleanup();'
  ], 'SSE success terminal');

  const finishError = section(postSse, '      const finishHttpError = (): void => {', "      httpRequest.on('dataReceive'", 'SSE error terminal');
  assertOrder(finishError, [
    'if (cleanedUp) return;',
    'HttpClient.statusError(responseCode, responseText);',
    'statusError.statusCode, statusError.errorCode,',
    'statusError.userMessage',
    'cleanup();'
  ], 'SSE structured HTTP error');

  const dataEnd = section(postSse, "      httpRequest.on('dataEnd', () => {", '      httpRequest.requestInStream', 'SSE data end');
  assertOrder(dataEnd, [
    'streamEnded = true;',
    'if (responseCode === 200) {',
    'finishStream();',
    '} else if (responseCode > 0) {',
    'finishHttpError();'
  ], 'SSE waits for HTTP status');

  const chatSse = section(chat, '  private startSseRequest(', '  private streamFailureMessage(', 'Chat SSE request');
  assertOrder(chatSse, [
    "if (evt.type === 'error') {",
    'last.failed = true;',
    "last.errorCode = evt.code ?? '';",
    "} else if (evt.type === 'done') {",
    'this.receivedDone = true;'
  ], 'Chat event terminal state');
  const doneHandler = section(chatSse, '      () => {', '      (err: HttpStreamError) => {', 'Chat done handler');
  assertOrder(doneHandler, [
    'if (last.failed || last.cancelled) {',
    'if (!this.receivedDone) {',
    'if (last.content.length === 0) {',
    'this.saveLocalHistory();'
  ], 'Chat saves only a complete done answer');
  const errorHandler = section(chatSse, '      (err: HttpStreamError) => {', '      (reqInstance: http.HttpRequest) => {', 'Chat error handler');
  assertOrder(errorHandler, [
    'last.failed = true;',
    'last.statusMessage = this.requestFailureMessage(err);',
    'last.httpStatus = err.statusCode;',
    'last.errorCode = err.errorCode;'
  ], 'Chat preserves stream failure evidence');
  assert.equal(occurrences(chatSse, 'this.saveLocalHistory();'), 1);
});

test('Chat restores and serializes only complete local conversation turns', () => {
  const load = section(chat, '  private async loadLocalHistory(lifecycleRunId: number): Promise<void> {',
    '  private retryLocalHistoryLoad(', 'Chat history load');
  assertOrder(load, [
    'await LocalLearningRepository.getChatHistory();',
    'if (!this.isActiveLifecycle(lifecycleRunId)) return;',
    'const restored: DisplayMessage[] = [];',
    'this.messages = restored;',
    'this.historyLoadFailed = false;'
  ], 'Chat history restore');
  assert.match(load, /catch \(error\) \{\s*if \(!this\.isActiveLifecycle\(lifecycleRunId\)\) return;\s*this\.historyLoadFailed = true;/);
  assert.match(load, /finally \{\s*if \(this\.isActiveLifecycle\(lifecycleRunId\)\) \{\s*this\.historyLoading = false;/);
  const retryLoad = section(chat, '  private retryLocalHistoryLoad(): void {', '  private cancelCurrentRequest(',
    'Chat history retry');
  assert.match(retryLoad, /this\.loadLocalHistory\(this\.lifecycleRunId\);/);

  const completeHistory = section(chat, '  private completeChatHistory(', '  private async saveLocalHistory(', 'Complete chat history');
  assert.match(completeHistory, /assistantMessage\.role === 'assistant' && assistantMessage\.content\.length > 0 &&\s*!assistantMessage\.failed && !assistantMessage\.cancelled && !assistantMessage\.streaming/);
  assert.match(completeHistory, /return history\.slice\(-24\);/);

  const send = section(chat, '  sendMessage(question?: string): void {', '  private isActiveRequest(', 'Chat send');
  assertOrder(send, [
    'this.completeChatHistory(this.messages.slice(0, this.messages.length - 2), false)',
    '.slice(-12)',
    'content: item.content.slice(0, 1000)',
    'startDate: this.localDateKey(),',
    'history: requestHistory'
  ], 'Chat request history boundary');

  const save = section(chat, '  private async saveLocalHistory(): Promise<void> {', '  private retryLocalHistorySave(', 'Chat history save');
  assertOrder(save, [
    'if (this.historySaving) {',
    'this.historySaveQueued = true;',
    'const history = this.completeChatHistory(this.messages, true);',
    'await LocalLearningRepository.saveChatHistory(history);',
    '} catch (_) {',
    'this.historySaveFailed = true;',
    '} finally {',
    'this.historySaving = false;',
    'if (this.historySaveQueued) {',
    'this.saveLocalHistory();'
  ], 'Chat serialized local save');

  const cancel = section(chat, '  private cancelCurrentRequest(', '  private retryMessage(', 'Chat cancellation');
  assertOrder(cancel, [
    'this.activeRequestId = 0;',
    'cancellation.cancel();',
    'last.cancelled = true;',
    "'已停止回答，这段内容未保存'"
  ], 'Chat cancellation state');
  assert.doesNotMatch(cancel, /saveLocalHistory/);
});

test('Chat retry replaces only the failed turn and preserves recovery input', () => {
  const retry = section(chat, '  private retryMessage(', '  private async probeCloudAgent(', 'Chat message retry');
  assertOrder(retry, [
    'const question = msg.retryQuestion.trim();',
    'if (question.length === 0 || this.loading || this.historyLoading || this.historySaving ||',
    'this.historyLoadFailed) return;',
    'if (!this.cloudAgentReady) {',
    'this.inputText = question;',
    'if (!this.probing) this.probeCloudAgent();',
    'return;',
    'const targetIndex = this.messages.indexOf(msg);',
    'if (targetIndex < 0) return;',
    'const next: DisplayMessage[] = [];',
    'for (let index = 0; index < this.messages.length; index++) {',
    'const item = this.messages[index];',
    "const pairedUser = index === targetIndex - 1 && item.role === 'user' && item.content === question;",
    'if (index !== targetIndex && !pairedUser) next.push(item);',
    'this.messages = next;',
    'this.sendMessage(question);'
  ], 'Chat retry recovery');
  assert.equal(occurrences(retry, 'this.messages = next;'), 1);
  assert.equal(occurrences(retry, 'this.sendMessage(question);'), 1);
});

test('Chat keeps citations, code, and tables readable', () => {
  const readable = section(chat, '  private readableMarkdown(', '  private pushReadableTable(', 'Readable markdown');
  assert.match(readable, /if \(trimmed\.startsWith\('```'\)\)/);
  assert.match(readable, /if \(inCode\) \{\s*lines\.push\(line\);/);
  assert.match(readable, /if \(this\.looksLikeTableLine\(trimmed\)\)/);
  assert.match(readable, /this\.appendTableRow\(tableRows, tableText, trimmed\);/);

  const tableFallback = section(chat, '  private pushReadableTable(', '  private pushTableBlock(', 'Readable table');
  assert.match(tableFallback, /lines\.push\('表格整理'\);/);
  assert.match(tableFallback, /lines\.push\('- ' \+ header\[cellIndex\] \+ '：' \+ cells\[cellIndex\]\);/);

  const bubble = section(chat, '  MessageBubble(msg: DisplayMessage) {', '  @Builder\n  MessageStatus(', 'Chat message bubble');
  assert.match(bubble, /this\.MarkdownContent\(this\.readableMarkdown\(msg\.content\), msg\.failed\)/);
  assert.match(bubble, /if \(msg\.citations\.length > 0\)/);
  assert.match(bubble, /msg\.citationExpanded = !msg\.citationExpanded;/);

  const markdown = section(chat, '  MarkdownContent(content: string, failed: boolean) {', '\n  }\n\n}', 'Markdown renderer');
  assert.match(markdown, /block\.type === 'code'/);
  assert.match(markdown, /\.scrollable\(ScrollDirection\.Horizontal\)/);
  assert.match(markdown, /block\.type === 'table'/);
});

test('Plan generation preserves the last saved plan and isolates stale reads', () => {
  const load = section(plan, '  private async loadPlan(): Promise<void> {', '  private async toggleTask(', 'Plan load');
  assertOrder(load, [
    'const readRunId = this.planReadRunId + 1;',
    'this.planReadRunId = readRunId;',
    'const plan = await LocalLearningRepository.getPlan();',
    'if (this.planReadRunId !== readRunId || this.loading) return;',
    'this.tasks = plan.tasks;'
  ], 'Plan stale-read isolation');

  const generate = section(plan, '  async generate(): Promise<void> {', '  pageTransition() {', 'Plan generation');
  assertOrder(generate, [
    'const requestedGoal = this.goal.trim();',
    'const requestedDays = this.days;',
    'const profile = await LocalLearningRepository.getProfile();',
    'goal: requestedGoal,',
    'durationDays: requestedDays,',
    'startDate: this.localDateKey(),',
    'const response = await HttpClient.post<AgentStudyPlan>(Constants.API_PLAN, JSON.stringify(req), request);',
    'const validation = this.validatePlanResponse(response);',
    'this.pendingPlan = plan;',
    'await this.persistGeneratedPlan(plan);'
  ], 'Plan freezes request inputs before awaits');
  assert.doesNotMatch(generate, /this\.tasks\s*=\s*\[\]/);
  assertOrder(generate, [
    'if (error instanceof HttpStatusError) {',
    'this.errorHttpStatus = error.statusCode;',
    'this.errorCode = error.errorCode;'
  ], 'Plan preserves structured HTTP errors');

  const persist = section(plan, '  private async persistGeneratedPlan(', '  private async retryPendingPlanSave(', 'Plan persistence');
  assertOrder(persist, [
    'await LocalLearningRepository.savePlan(plan);',
    '} catch (_) {',
    "this.retryAction = 'save';",
    'return false;',
    'this.tasks = plan.tasks;',
    'this.pendingPlan = null;',
    'await LearningFormUpdater.refreshAll();'
  ], 'Plan replaces UI only after local save');

  const retrySave = section(plan, '  private async retryPendingPlanSave(): Promise<void> {', '  private cleanText(', 'Plan save retry');
  assert.match(retrySave,
    /if \(this\.loading \|\| this\.updatingTaskId\.length > 0 \|\| this\.pendingPlan === null\) return;/);
  assert.match(retrySave, /await this\.persistGeneratedPlan\(this\.pendingPlan\);/);
  assert.doesNotMatch(retrySave, /HttpClient\.post/);
});

test('Plan preserves a failed pending save across re-entry and rejects stale generation callbacks', () => {
  const requestState = section(plan, '  private activeRequest:', '  private durationOptions:',
    'Plan lifecycle request state');
  assertOrder(requestState, [
    'private activeRequest: HttpRequestCancellation | null = null;',
    'private generationRunId: number = 0;',
    'private planReadRunId: number = 0;',
    'private lifecycleRunId: number = 0;',
    'private pageActive: boolean = false;',
    'private hasLoadedPlanOnce: boolean = false;',
    'private pendingPlan: AgentStudyPlan | null = null;'
  ], 'Plan lifecycle request fields');

  const lifecycle = section(plan, '  onPageShow(): void {', '  get canGenerate(): boolean {',
    'Plan page lifecycle');
  const appear = section(lifecycle, '  onPageShow(): void {', '  onPageHide(): void {',
    'Plan page re-entry');
  assertOrder(appear, [
    'this.lifecycleRunId += 1;',
    'this.pageActive = true;',
    'this.loadPlan();'
  ], 'Plan activates a new lifecycle before local restore');
  const disappear = section(plan, '  onPageHide(): void {', '  onBackPress(): boolean {',
    'Plan page leave');
  assertOrder(disappear, [
    'this.pageActive = false;',
    'this.lifecycleRunId += 1;',
    'this.planReadRunId += 1;',
    'this.planLoading = false;',
    'if (this.loading && this.progressStep >= 3) return;',
    'this.cancelPlanGeneration(false);'
  ], 'Plan invalidates network callbacks but lets an entered local save settle');

  const backPress = section(plan, '  onBackPress(): boolean {', '  get canGenerate(): boolean {',
    'Plan system back');
  assertOrder(backPress, [
    'if (this.updatingTaskId.length > 0) {',
    "this.message = '正在保存任务，请稍候';",
    'return true;',
    'if (this.loading && this.progressStep >= 3) {',
    "this.message = '正在保存计划，请稍候';",
    'return true;',
    'this.cancelPlanGeneration(false);',
    'return false;'
  ], 'Plan consumes system back while local writes must stay mounted');
  assert.doesNotMatch(plan, /aboutToDisappear\(\): void/);

  const load = section(plan, '  private async loadPlan(): Promise<void> {', '  private async toggleTask(',
    'Plan pending-save restore');
  assertOrder(load, [
    "if (this.pendingPlan !== null && this.retryAction === 'save') {",
    'this.planLoading = false;',
    'return;',
    'if (this.loading) {',
    'const readRunId = this.planReadRunId + 1;',
    "this.retryAction = 'none';",
    'const plan = await LocalLearningRepository.getPlan();'
  ], 'Plan keeps pending save recovery before resetting load state');
  assert.doesNotMatch(load, /this\.pendingPlan\s*=/);
  assertOrder(load, [
    'if (plan !== null) {',
    'if (!this.hasLoadedPlanOnce) {',
    'this.goal = plan.goal;',
    'this.savedPlanGoal = plan.goal;',
    'this.tasks = plan.tasks;',
    'this.hasLoadedPlanOnce = true;'
  ], 'Plan retains the saved task list without overwriting a later goal on re-entry');

  const persist = section(plan, '  private async persistGeneratedPlan(',
    '  private async retryPendingPlanSave(', 'Plan pending save failure');
  const persistFailure = section(persist, '    } catch (_) {', '\n    }\n\n    this.tasks = plan.tasks;',
    'Plan pending save failure branch');
  assertOrder(persistFailure, [
    "this.retryAction = 'save';",
    'return false;'
  ], 'Plan exposes save-only retry after ArkData failure');
  assert.doesNotMatch(persistFailure, /this\.pendingPlan\s*=|this\.tasks\s*=/);

  const activeGeneration = section(plan, '  private isActiveGeneration(',
    '  private cancelPlanGeneration(', 'Plan active lifecycle generation');
  assert.match(activeGeneration,
    /private isActiveGeneration\(runId: number, lifecycleRunId: number,\s*request: HttpRequestCancellation\): boolean \{/);
  assert.match(activeGeneration,
    /return this\.pageActive && this\.lifecycleRunId === lifecycleRunId && this\.loading &&\s*this\.generationRunId === runId && this\.activeRequest === request && !request\.isCancelled\(\);/);

  const generate = section(plan, '  async generate(): Promise<void> {', '  pageTransition() {',
    'Plan lifecycle generation');
  assertOrder(generate, [
    'if (requestedGoal.length === 0 || this.loading || this.planLoading ||\n' +
      '      this.updatingTaskId.length > 0 || !this.pageActive) return;',
    'const lifecycleRunId = this.lifecycleRunId;',
    'const runId = this.generationRunId + 1;',
    'const profile = await LocalLearningRepository.getProfile();',
    'if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;',
    'const response = await HttpClient.post<AgentStudyPlan>(Constants.API_PLAN, JSON.stringify(req), request);',
    'if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;',
    'const validation = this.validatePlanResponse(response);',
    'this.pendingPlan = plan;',
    'await this.persistGeneratedPlan(plan);'
  ], 'Plan checks the page lifecycle before a network result can enter persistence');
  assert.equal(occurrences(generate,
    'if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;'), 3);
  const generationFailure = section(generate, '    } catch (e) {', '    } finally {',
    'Plan stale generation failure');
  assertOrder(generationFailure, [
    'if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;',
    "this.retryAction = 'generate';"
  ], 'Plan ignores stale failures after leave and re-entry');
});

test('Plan serializes task writes against the latest persisted plan and conflicting actions', () => {
  assert.match(plan, /@State updatingTaskId: string = '';/);

  const canGenerate = section(plan, '  get canGenerate(): boolean {', '  private taskTypeLabel(',
    'Plan generation availability');
  assert.match(canGenerate,
    /return !this\.loading && !this\.planLoading && this\.updatingTaskId\.length === 0 &&\s*this\.goal\.trim\(\)\.length > 0;/);

  const openTask = section(plan, '  private openTask(', '  private pushPage(', 'Plan task navigation guard');
  assertOrder(openTask, [
    'if (this.updatingTaskId.length > 0) {',
    "this.message = '正在保存任务，请稍候';",
    'return;',
    'if (!this.hasTaskTarget(task)) {'
  ], 'Plan blocks task navigation while a task write is pending');

  const load = section(plan, '  private async loadPlan(): Promise<void> {', '  private async toggleTask(',
    'Plan task-write load guard');
  assertOrder(load, [
    'if (this.updatingTaskId.length > 0) {',
    'this.planLoading = false;',
    'return;',
    'const readRunId = this.planReadRunId + 1;'
  ], 'Plan blocks a competing local plan read');

  const toggle = section(plan, '  private async toggleTask(', '  @Builder\n  PlanSkeleton()',
    'Plan serialized task write');
  assertOrder(toggle, [
    'if (this.updatingTaskId.length > 0 || this.loading || this.planLoading) return;',
    'const taskId = task.id;',
    'const desiredDone = !Boolean(task.done);',
    'const feedbackLifecycleRunId = this.lifecycleRunId;',
    'this.updatingTaskId = taskId;',
    'receipt = await LocalLearningRepository.updatePlanTask(taskId, desiredDone);',
    'this.tasks = receipt.plan.tasks;',
    '} finally {',
    'if (this.updatingTaskId === taskId) {',
    "this.updatingTaskId = '';",
    'if (receipt === null) return;',
    'await LearningFormUpdater.refreshAll();',
    'if (receipt.changed && receipt.task.done === true) {',
    'if (!this.pageActive || this.lifecycleRunId !== feedbackLifecycleRunId) return;'
  ], 'Plan locks before reading and publishes only a saved latest snapshot');
  assert.doesNotMatch(toggle, /LocalLearningRepository\.(getPlan|savePlan)\(|for \(const item of this\.tasks\)/);

  const goBack = section(plan, '  private goBack(): void {', '  private isActiveGeneration(',
    'Plan task-write back guard');
  assertOrder(goBack, [
    'if (this.updatingTaskId.length > 0) {',
    "this.message = '正在保存任务，请稍候';",
    'return;',
    'if (this.loading && this.progressStep >= 3) {'
  ], 'Plan keeps the page mounted until the task write settles');

  const taskControls = section(plan, '                  Button(this.actionLabel(t))',
    '                }\n              }\n              .width', 'Plan task write controls');
  assert.match(taskControls,
    /\.enabled\(this\.hasTaskTarget\(t\) && this\.updatingTaskId\.length === 0\)/);
  assert.match(taskControls,
    /Button\(this\.updatingTaskId === t\.id \? '保存中' : \(t\.done \? '恢复' : '完成'\)\)/);
  assert.match(taskControls, /\.enabled\(this\.updatingTaskId\.length === 0\)/);
  assert.equal(occurrences(taskControls, '.constraintSize({ minWidth: 64, minHeight: 48 })'), 2);
  assert.equal(occurrences(taskControls, '.width(64)'), 0);
  assert.equal(occurrences(taskControls, '.height(48)'), 0);
  assert.match(taskControls, /\.accessibilityText\(this\.actionLabel\(t\) \+ '：' \+ ProactiveLearningService\.planTaskTitle\(t\)\)/);
  assert.match(taskControls, /\.accessibilityText\(\(t\.done \? '恢复待完成：' : '标记完成：'\) \+\s*ProactiveLearningService\.planTaskTitle\(t\)\)/);

  const retryControls = section(plan, "              Button(this.retryAction === 'load' ? '重新读取' :",
    '            }\n          }', 'Plan retry control guard');
  assert.match(retryControls,
    /\.enabled\(!this\.loading && !this\.planLoading && this\.updatingTaskId\.length === 0\)/);
});

test('Plan writes are serialized in the repository across Plan and Home entry points', async () => {
  const queues = section(localRepository, '  private static initializationTask:',
    '  static async initialize(', 'Local repository queues');
  assert.match(queues, /private static planQueue: Promise<void> = Promise\.resolve\(\);/);

  const runPlanTask = section(localRepository, '  private static runPlanTask<T>(',
    '  private static isExactCourseTopic(', 'Plan queue');
  assertOrder(runPlanTask, [
    'LocalLearningRepository.planQueue.then((): Promise<T> => task())',
    'LocalLearningRepository.planQueue = running.then((): void => {}, (): void => {});',
    'return running;'
  ], 'Plan queue continues after both success and failure');

  const planStore = section(localRepository, '  static async getPlan(): Promise<StudyPlan | null> {',
    '  static async getFormIds(', 'Plan repository writes');
  assertOrder(planStore, [
    'static async getPlan(): Promise<StudyPlan | null> {',
    'LocalLearningRepository.runPlanTask(',
    'static async savePlan(plan: StudyPlan): Promise<void> {',
    'LocalLearningRepository.runPlanTask(',
    'static async updatePlanTask(taskId: string, done: boolean): Promise<PlanTaskUpdateReceipt> {',
    'LocalLearningRepository.runPlanTask(',
    'const plan = await LocalLearningRepository.getValue<StudyPlan>(KEY_PLAN);',
    'const changed = Boolean(task.done) !== done;',
    'task.done = done;',
    'if (changed) await LocalLearningRepository.putValue<StudyPlan>(KEY_PLAN, plan);'
  ], 'All plan reads and writers share one queue');

  const homeToggle = section(home, '  private async toggleTask(task: PlanTask): Promise<void> {',
    '  private async publishReminder(', 'Home plan task update');
  assertOrder(homeToggle, [
    "if (this.updatingTaskId.length > 0 || this.notificationState === 'loading') return;",
    'const desiredDone = !Boolean(task.done);',
    'receipt = await LocalLearningRepository.updatePlanTask(taskId, desiredDone);',
    'this.planTasks = nextTasks;',
    'if (receipt === null) return;',
    'await LearningFormUpdater.refreshAll();',
    'if (receipt.changed && receipt.task.done === true) {',
    'await LocalLearningRepository.appendStudyEvent(event);',
    '} finally {',
    "if (this.updatingTaskId === taskId) this.updatingTaskId = '';"
  ], 'Home uses the same atomic plan writer');
  assert.doesNotMatch(homeToggle, /LocalLearningRepository\.(getPlan|savePlan)\(/);

  const context = {
    __learningContentRepository: { getTopics: () => [] },
    __quizLearningStateReducer: {}
  };
  vm.runInNewContext(compileLocalLearningRepository(), context);
  const Repository = context.__LocalLearningRepository;
  let storedPlan = {
    planId: 'plan-1',
    userId: 'user-1',
    goal: '并发写入验证',
    tasks: [
      { id: 'task-a', title: 'A', date: '2026-07-17', estimatedMin: 10, type: 'reading', done: false },
      { id: 'task-b', title: 'B', date: '2026-07-17', estimatedMin: 10, type: 'reading', done: false }
    ]
  };
  const clone = (value) => JSON.parse(JSON.stringify(value));
  let readCount = 0;
  let writeCount = 0;
  let failNextWrite = false;
  let releaseFirstWrite;
  let markFirstWriteStarted;
  const firstWriteStarted = new Promise((resolveStarted) => { markFirstWriteStarted = resolveStarted; });
  const firstWriteGate = new Promise((resolveWrite) => { releaseFirstWrite = resolveWrite; });
  Repository.getValue = async (key) => {
    assert.equal(key, 'plan');
    readCount += 1;
    return clone(storedPlan);
  };
  Repository.putValue = async (key, value) => {
    assert.equal(key, 'plan');
    writeCount += 1;
    if (writeCount === 1) {
      markFirstWriteStarted();
      await firstWriteGate;
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw new Error('fixed write failure');
    }
    storedPlan = clone(value);
  };

  const first = Repository.updatePlanTask('task-a', true);
  await firstWriteStarted;
  const duplicate = Repository.updatePlanTask('task-a', true);
  const different = Repository.updatePlanTask('task-b', true);
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(readCount, 1, 'later writers must not read while the first write is pending');
  releaseFirstWrite();
  const [firstReceipt, duplicateReceipt, differentReceipt] = await Promise.all([first, duplicate, different]);
  assert.equal(firstReceipt.changed, true);
  assert.equal(duplicateReceipt.changed, false, 'same desired state must be idempotent across pages');
  assert.equal(differentReceipt.changed, true);
  assert.deepEqual(storedPlan.tasks.map((task) => task.done), [true, true]);

  failNextWrite = true;
  await assert.rejects(Repository.savePlan(clone(storedPlan)), /fixed write failure/);
  const recovered = await Repository.updatePlanTask('task-a', false);
  assert.equal(recovered.task.done, false, 'a failed writer must not poison the plan queue');
  assert.deepEqual(storedPlan.tasks.map((task) => task.done), [false, true]);
});

test('Plan submits the native TextInput value and preserves the local calendar date', () => {
  const input = section(plan, '          TextInput({', '\n          this.GoalSuggestions()', 'Plan input');
  assert.match(input, /text:\s*\$\$this\.goal/);
  assert.match(input, /\.maxLength\(500\)/);
  assert.match(input, /\.onChange\(\(v: string\) => \{ this\.goal = v; \}\)/);
  assert.match(input, /\.onSubmit\(\(_enterKey: EnterKeyType, event: SubmitEvent\): void => \{\s*this\.goal = event\.text;\s*this\.generate\(\);/);

  const generate = section(plan, '  async generate(): Promise<void> {', '  pageTransition() {', 'Plan generation');
  assert.match(generate, /startDate: this\.localDateKey\(\)/);
});

test('Plan exposes cancellable wait stages, keyboard dismissal, and safe-area spacing', () => {
  const cancel = section(plan, '  private cancelPlanGeneration(', '  private planSavedMessage(', 'Plan cancellation');
  assertOrder(cancel, [
    'if (!this.loading || this.progressStep >= 3) return;',
    'const hadSavedPlan = this.tasks.length > 0;',
    'this.generationRunId += 1;',
    'if (request !== null) request.cancel();',
    'this.loading = false;',
    "'已取消生成，' + this.savedPlanLabel() + '仍可继续执行'"
  ], 'Plan cancellation keeps the saved plan');

  const progress = section(plan, '  private runWaitClock(', '  private currentPlanStepIndex(', 'Plan wait clock');
  assertOrder(progress, [
    '}, 10000);',
    '}, 30000);',
    '}, 60000);'
  ], 'Plan wait milestones');

  const loadingState = section(plan, '  PlanLoadingState() {', '  @Builder\n  AgentTraceCard()', 'Plan loading UI');
  assert.match(loadingState, /Button\('取消'\)/);
  assert.match(loadingState, /\.enabled\(this\.progressStep < 3\)/);
  assert.match(loadingState, /this\.PlanCheckpoint\('了解进度'/);
  assert.match(loadingState, /this\.PlanCheckpoint\('准备完成'/);

  assert.match(plan, /private goalInputController: TextInputController = new TextInputController\(\);/);
  assert.match(plan, /this\.goalInputController\.stopEditing\(\);/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 12 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 16 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
});
