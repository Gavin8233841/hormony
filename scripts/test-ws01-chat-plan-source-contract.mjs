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
    'startDate: this.localDateKey(),',
    'this.startSseRequest(req, requestId, cancellation);'
  ], 'Chat send payload');

  const startSse = section(chat, '  private startSseRequest(', '  private streamFailureMessage(', 'Chat SSE request');
  assert.match(startSse, /HttpClient\.postSSE\(Constants\.API_CHAT, JSON\.stringify\(req\)/);
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
  const load = section(chat, '  private async loadLocalHistory(): Promise<void> {', '  private retryLocalHistoryLoad(', 'Chat history load');
  assertOrder(load, [
    'await LocalLearningRepository.getChatHistory();',
    'const restored: DisplayMessage[] = [];',
    'this.messages = restored;',
    'this.historyLoadFailed = false;'
  ], 'Chat history restore');
  assert.match(load, /catch \(error\) \{\s*this\.historyLoadFailed = true;/);

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
    "'已停止继续生成，上方内容不会保存到本机'"
  ], 'Chat cancellation state');
  assert.doesNotMatch(cancel, /saveLocalHistory/);
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
  assert.match(retrySave, /if \(this\.loading \|\| this\.pendingPlan === null\) return;/);
  assert.match(retrySave, /await this\.persistGeneratedPlan\(this\.pendingPlan\);/);
  assert.doesNotMatch(retrySave, /HttpClient\.post/);
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
  assert.match(loadingState, /this\.PlanCheckpoint\('本机状态'/);
  assert.match(loadingState, /this\.PlanCheckpoint\('入口更新'/);

  assert.match(plan, /private goalInputController: TextInputController = new TextInputController\(\);/);
  assert.match(plan, /this\.goalInputController\.stopEditing\(\);/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 12 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
  assert.match(plan, /padding\(\{ left: 16, right: 16, bottom: 16 \+ SafeAreaInsets\.bottomVp\(\) \}\)/);
});
