import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
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

  const lifecycle = section(chat, '  aboutToAppear(): void {', '  get canSend(): boolean {', 'Chat lifecycle');
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
  const activeLifecycle = section(chat, '  private isActiveLifecycle(', '  get canSend(): boolean {',
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
    "'已停止继续生成，上方内容不会保存到本机'"
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
  assert.match(retrySave, /if \(this\.loading \|\| this\.pendingPlan === null\) return;/);
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

  const lifecycle = section(plan, '  aboutToAppear(): void {', '  get canGenerate(): boolean {',
    'Plan page lifecycle');
  const appear = section(lifecycle, '  aboutToAppear(): void {', '  aboutToDisappear(): void {',
    'Plan page re-entry');
  assertOrder(appear, [
    'this.lifecycleRunId += 1;',
    'this.pageActive = true;',
    'this.loadPlan();'
  ], 'Plan activates a new lifecycle before local restore');
  const disappear = section(plan, '  aboutToDisappear(): void {', '  get canGenerate(): boolean {',
    'Plan page leave');
  assertOrder(disappear, [
    'this.pageActive = false;',
    'this.lifecycleRunId += 1;',
    'this.planReadRunId += 1;',
    'this.planLoading = false;',
    'if (this.loading && this.progressStep >= 3) return;',
    'this.cancelPlanGeneration(false);'
  ], 'Plan invalidates network callbacks but lets an entered local save settle');

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
    'if (requestedGoal.length === 0 || this.loading || this.planLoading || !this.pageActive) return;',
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
  assert.match(loadingState, /this\.PlanCheckpoint\('本机状态'/);
  assert.match(loadingState, /this\.PlanCheckpoint\('入口更新'/);

  assert.match(plan, /private goalInputController: TextInputController = new TextInputController\(\);/);
  assert.match(plan, /this\.goalInputController\.stopEditing\(\);/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 12 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 16 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
});
