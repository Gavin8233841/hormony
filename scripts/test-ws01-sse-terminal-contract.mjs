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

function emittedTypes(text, emitter) {
  const pattern = new RegExp(`\\b${emitter}\\(\\{\\s*type:\\s*"([^"]+)"`, 'g');
  return [...text.matchAll(pattern)].map((match) => match[1]);
}

function assertUniqueDoneTerminal(types, label) {
  assert.equal(types.filter((type) => type === 'done').length, 1, `${label}: expected one done event`);
  assert.equal(types.at(-1), 'done', `${label}: done must be the final event`);
}

function compileSseConsumer(httpClient, onEvent, onDone) {
  const parserSource = section(
    httpClient,
    '    const consumeText = (text: string): boolean => {',
    '\n\n    const startRequest = ',
    'HttpClient SSE parser'
  )
    .replace('const consumeText = (text: string): boolean => {', 'const consumeText = (text) => {')
    .replace('const dataLines: string[] = [];', 'const dataLines = [];')
    .replace('let sawDoneEvent: boolean = false;', 'let sawDoneEvent = false;')
    .replace('const evt: StreamEvent = JSON.parse(jsonStr);', 'const evt = JSON.parse(jsonStr);');

  const factory = new Function(
    'onEvent',
    'onDone',
    `"use strict";
      let doneCalled = false;
      let eventBuffer = '';
      ${parserSource}
      return {
        consumeText,
        state: () => ({ doneCalled, eventBuffer })
      };`
  );
  return factory(onEvent, onDone);
}

function compileChatStartSse(chat, httpClientStub) {
  const methodSource = section(
    chat,
    '  private startSseRequest(req: ChatRequest, requestId: number, cancellation: HttpRequestCancellation): void {',
    '\n  private streamFailureMessage(',
    'Chat SSE callbacks'
  )
    .replace(
      'private startSseRequest(req: ChatRequest, requestId: number, cancellation: HttpRequestCancellation): void {',
      'function startSseRequest(req, requestId, cancellation) {'
    )
    .replace('(evt: StreamEvent) => {', '(evt) => {')
    .replace('(err: HttpStreamError) => {', '(err) => {')
    .replace('(reqInstance: http.HttpRequest) => {', '(reqInstance) => {');

  const factory = new Function(
    'HttpClient',
    'Constants',
    `"use strict";
      ${methodSource}
      return startSseRequest;`
  );
  return factory(httpClientStub, { API_CHAT: '/api/chat' });
}

function compileStatusError(httpClient) {
  const methodSource = section(
    httpClient,
    '  private static statusError(statusCode: number, result: string): HttpStatusError {',
    '\n\n  /**',
    'HttpClient status error parser'
  )
    .replace(
      'private static statusError(statusCode: number, result: string): HttpStatusError {',
      'function statusError(statusCode, result) {'
    )
    .replace("let errorCode: string = '';", "let errorCode = '';")
    .replace("let userMessage: string = '';", "let userMessage = '';")
    .replace('const payload: ApiErrorPayload = JSON.parse(result);', 'const payload = JSON.parse(result);');

  class TestHttpStatusError extends Error {
    constructor(statusCode, errorCode, userMessage) {
      super(`HTTP ${statusCode}${errorCode.length > 0 ? ` [${errorCode}]` : ''}` +
        `${userMessage.length > 0 ? `: ${userMessage}` : ''}`);
      this.statusCode = statusCode;
      this.errorCode = errorCode;
      this.userMessage = userMessage;
    }
  }

  return new Function(
    'HttpStatusError',
    `"use strict";
      ${methodSource}
      return statusError;`
  )(TestHttpStatusError);
}

function runFinishHttpError(httpClient, statusError, responseCode, responseText) {
  const postSse = section(httpClient, '  static postSSE(', '\n  }\n}', 'HttpClient postSSE');
  const finishSource = section(
    postSse,
    '      const finishHttpError = (): void => {',
    "\n\n      httpRequest.on('dataReceive'",
    'HttpClient non-2xx terminal'
  ).replace('const finishHttpError = (): void => {', 'const finishHttpError = () => {');

  class TestHttpStreamError {
    constructor(message, statusCode, errorCode, userMessage) {
      this.message = message;
      this.statusCode = statusCode;
      this.errorCode = errorCode;
      this.userMessage = userMessage;
    }
  }

  let receivedError = null;
  let cleanupCount = 0;
  const execute = new Function(
    'HttpClient',
    'HttpStreamError',
    'onError',
    'cleanup',
    'responseCode',
    'responseText',
    'cleanedUp',
    `"use strict";
      ${finishSource}
      finishHttpError();`
  );
  execute(
    { statusError },
    TestHttpStreamError,
    (error) => { receivedError = error; },
    () => { cleanupCount += 1; },
    responseCode,
    responseText,
    false
  );
  return { receivedError, cleanupCount };
}

function indexOfBytes(haystack, needle) {
  outer: for (let index = 0; index <= haystack.length - needle.length; index += 1) {
    for (let offset = 0; offset < needle.length; offset += 1) {
      if (haystack[index + offset] !== needle[offset]) continue outer;
    }
    return index;
  }
  return -1;
}

function feedUtf8Chunks(consumer, payload, splitPoints) {
  const bytes = new TextEncoder().encode(payload);
  const decoder = new TextDecoder('utf-8');
  let cursor = 0;
  for (const splitPoint of splitPoints) {
    const text = decoder.decode(bytes.slice(cursor, splitPoint), { stream: true });
    if (text.length > 0) consumer.consumeText(text);
    cursor = splitPoint;
  }
  const text = decoder.decode(bytes.slice(cursor), { stream: true });
  if (text.length > 0) consumer.consumeText(text);
  const tail = decoder.decode();
  if (tail.length > 0) consumer.consumeText(tail);
}

const httpClient = source('apps/harmonyos/entry/src/main/ets/common/HttpClient.ets');
const chat = source('apps/harmonyos/entry/src/main/ets/pages/Chat.ets');
const route = source('apps/web/src/app/api/chat/route.ts');
const orchestrator = source('apps/web/src/lib/agents/orchestrator.ts');
const streamTypes = source('apps/web/src/lib/types.ts');

test('the web StreamEvent and every chat branch have one final done event', () => {
  const eventContract = section(
    streamTypes,
    'export type StreamEvent =',
    ';\n\n// ========== ',
    'Web StreamEvent'
  );
  const declaredTypes = [...eventContract.matchAll(/\{\s*type:\s*"([^"]+)"/g)]
    .map((match) => match[1]);
  assert.deepEqual(declaredTypes, ['thinking', 'delta', 'citation', 'trace', 'error', 'done']);

  const safetyBranch = section(
    orchestrator,
    '  if (!safety.passed) {',
    '\n\n  // 4.',
    'orchestrator safety branch'
  );
  const safetyEvents = emittedTypes(safetyBranch, 'emit');
  assert.deepEqual(safetyEvents, ['error', 'done']);
  assert.match(safetyBranch, /emit\(\{ type: "done", sessionId \}\);\n    return;/);
  assertUniqueDoneTerminal(safetyEvents, 'orchestrator safety branch');

  const normalBranch = section(
    orchestrator,
    '  // 4. ',
    '\n}',
    'orchestrator normal branch'
  );
  const normalEvents = emittedTypes(normalBranch, 'emit');
  assert.deepEqual(normalEvents, ['delta', 'citation', 'done']);
  assertUniqueDoneTerminal(normalEvents, 'orchestrator normal branch');

  const streamErrorBranch = section(
    route,
    '        if (orchestrateError) {',
    '\n      } catch (err) {',
    'route stream error branch'
  );
  const streamErrorEvents = emittedTypes(streamErrorBranch, 'sse');
  assert.deepEqual(streamErrorEvents, ['error', 'done']);
  assertUniqueDoneTerminal(streamErrorEvents, 'route stream error branch');
});

test('the production SSE parser survives UTF-8 and JSON chunk boundaries plus multiple data lines', () => {
  const events = [];
  let doneCount = 0;
  const consumer = compileSseConsumer(
    httpClient,
    (event) => events.push(event),
    () => { doneCount += 1; }
  );
  assert.match(httpClient, /decoder\.decodeToString\(new Uint8Array\(data\), \{ stream: true \}\)/);

  const delta = JSON.stringify({ type: 'delta', content: '\u5206\u5757\u5185\u5bb9' });
  const propertyBoundary = delta.indexOf(',"content"') + 1;
  assert.ok(propertyBoundary > 0);
  const stream = `data: ${delta.slice(0, propertyBoundary)}\r\ndata: ${delta.slice(propertyBoundary)}\r\n\r\n` +
    `data: ${JSON.stringify({ type: 'done', sessionId: 'session-1' })}\r\n\r\n`;
  const bytes = new TextEncoder().encode(stream);
  const multibyteOffset = indexOfBytes(bytes, new TextEncoder().encode('\u5206'));
  assert.ok(multibyteOffset >= 0);
  feedUtf8Chunks(consumer, stream, [1, 7, multibyteOffset + 1, multibyteOffset + 2, bytes.length - 3]);

  assert.deepEqual(events, [
    { type: 'delta', content: '\u5206\u5757\u5185\u5bb9' },
    { type: 'done', sessionId: 'session-1' }
  ]);
  assert.equal(doneCount, 1);
  assert.equal(consumer.state().doneCalled, true);
  assert.equal(consumer.state().eventBuffer.trim(), '');
});

test('the production SSE parser invokes its terminal callback only once', () => {
  const events = [];
  let doneCount = 0;
  const consumer = compileSseConsumer(
    httpClient,
    (event) => events.push(event.type),
    () => { doneCount += 1; }
  );
  const doneFrame = `data: ${JSON.stringify({ type: 'done', sessionId: 'session-2' })}\n\n`;

  consumer.consumeText(doneFrame);
  consumer.consumeText(doneFrame);
  consumer.consumeText('\n\n');

  assert.deepEqual(events, ['done', 'done']);
  assert.equal(doneCount, 1);
});

test('an SSE error followed by done never saves the failed Chat turn', () => {
  let callbacks = null;
  const httpClientStub = {
    postSSE(path, body, onEvent, onDone, onError, onCreated, cancellation) {
      callbacks = { path, body, onEvent, onDone, onError, onCreated, cancellation };
    }
  };
  const startSseRequest = compileChatStartSse(chat, httpClientStub);
  let saveCount = 0;
  const assistant = {
    role: 'assistant',
    content: '',
    citations: [],
    agentTrace: [],
    thinking: [],
    streaming: true,
    failed: false,
    cancelled: false,
    statusMessage: '',
    httpStatus: 0,
    errorCode: '',
    statusExpanded: false,
    retryQuestion: 'question'
  };
  const state = {
    messages: [assistant],
    loading: true,
    isCancelled: false,
    receivedDone: false,
    activeRequestId: 41,
    currentRequest: null,
    currentCancellation: {},
    cloudAgentReady: true,
    serviceMessage: '',
    isActiveRequest(requestId) {
      return requestId === this.activeRequestId && !this.isCancelled;
    },
    streamFailureMessage(code, message) {
      return message.length > 0 ? message : code;
    },
    requestFailureMessage(error) {
      return error.message;
    },
    scrollToBottom() {},
    saveLocalHistory() {
      saveCount += 1;
    }
  };

  startSseRequest.call(state, { userId: 'demo', message: 'question' }, 41, state.currentCancellation);
  assert.notEqual(callbacks, null);
  assert.equal(callbacks.path, '/api/chat');
  const consumer = compileSseConsumer(httpClient, callbacks.onEvent, callbacks.onDone);
  consumer.consumeText(
    `data: ${JSON.stringify({ type: 'error', code: 'SAFETY_BLOCKED', message: 'blocked' })}\n\n` +
    `data: ${JSON.stringify({ type: 'done', sessionId: 'session-error' })}\n\n`
  );

  assert.equal(state.receivedDone, true);
  assert.equal(state.loading, false);
  assert.equal(state.messages[0].failed, true);
  assert.equal(state.messages[0].errorCode, 'SAFETY_BLOCKED');
  assert.equal(saveCount, 0);
});

test('a non-2xx JSON body preserves HTTP status, error, and code', () => {
  const statusError = compileStatusError(httpClient);
  const result = runFinishHttpError(
    httpClient,
    statusError,
    422,
    JSON.stringify({ error: '  invalid context  ', code: '  INVALID_CONTEXT  ' })
  );

  assert.equal(result.cleanupCount, 1);
  assert.notEqual(result.receivedError, null);
  assert.equal(result.receivedError.statusCode, 422);
  assert.equal(result.receivedError.errorCode, 'INVALID_CONTEXT');
  assert.equal(result.receivedError.userMessage, 'invalid context');
  assert.equal(result.receivedError.message, 'HTTP 422 [INVALID_CONTEXT]: invalid context');
});
