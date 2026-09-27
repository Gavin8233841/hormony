// Drive the actual ArkTS Extension source with mocked platform/network boundaries.
// This checks protocol behavior locally; it cannot establish a Xiaoyi connection.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourcePath = resolve(repo, 'apps/harmonyos/entry/src/main/ets/agentability/XiaoyiAgentAbility.ets');
const require = createRequire(import.meta.url);
const ts = require(require.resolve('typescript', { paths: [resolve(repo, 'apps/web')] }));
const source = readFileSync(sourcePath, 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;

function harness() {
  const calls = [];
  class HttpRequestCancellation {
    cancelled = false;
    cancel() { this.cancelled = true; }
  }
  const HttpClient = {
    postSSE(path, body, onEvent, onComplete, onError, _options, cancellation) {
      calls.push({ path, body: JSON.parse(body), onEvent, onComplete, onError, cancellation });
    },
  };
  const module = { exports: {} };
  const imports = {
    '@kit.AbilityKit': { AgentExtensionAbility: class {} },
    '../common/HttpClient': { HttpClient, HttpRequestCancellation },
    '../common/Constants': { Constants: { API_XIAOYI_TUTOR: '/api/xiaoyi/tutor' } },
  };
  vm.runInNewContext(compiled, {
    module,
    exports: module.exports,
    require(id) {
      if (!(id in imports)) throw new Error(`Unexpected runtime import: ${id}`);
      return imports[id];
    },
  }, { filename: sourcePath });
  return { agent: new module.exports.default(), calls };
}

function proxy() {
  const responses = [];
  return { responses, sendData(data) { responses.push(JSON.parse(data)); } };
}

function message(id, taskId, question = '什么是二叉搜索树？') {
  return JSON.stringify({
    jsonrpc: '2.0', id, method: 'MessageStream',
    params: { message: { messageId: taskId, role: 'ROLE_USER',
      parts: [{ text: question, mediaType: 'text/plain' }] } },
  });
}

function cancel(id, taskId) {
  return JSON.stringify({ jsonrpc: '2.0', id, method: 'TasksCancel', params: { id: taskId } });
}

test('valid text request returns a completed task with echoed request and context IDs', () => {
  const { agent, calls } = harness();
  const client = proxy();
  agent.onData(client, message('request-1', 'task-1'));
  assert.equal(calls.length, 1);
  assert.equal(calls[0].path, '/api/xiaoyi/tutor');
  assert.equal(calls[0].body.mode, 'xiaoyi_tutor');
  assert.equal(calls[0].body.message, '什么是二叉搜索树？');
  calls[0].onEvent({ type: 'delta', content: '一种有序二叉树。' });
  calls[0].onEvent({ type: 'done' });
  calls[0].onComplete();
  assert.equal(client.responses.length, 1);
  assert.equal(client.responses[0].id, 'request-1');
  assert.equal(client.responses[0].result.task.id, 'task-1');
  assert.equal(client.responses[0].result.task.contextId, 'task-1');
  assert.equal(client.responses[0].result.task.status.state, 'TASK_STATE_COMPLETED');
  assert.equal(client.responses[0].result.task.artifacts[0].parts[0].text, '一种有序二叉树。');
});

test('malformed JSON, invalid part and unsupported method return one protocol error', () => {
  const { agent, calls } = harness();
  const client = proxy();
  agent.onData(client, '{');
  agent.onData(client, JSON.stringify({ jsonrpc: '2.0', id: 'bad-part', method: 'MessageStream',
    params: { message: { messageId: 'task-1', role: 'ROLE_USER',
      parts: [{ text: 42, mediaType: 'text/plain' }] } } }));
  agent.onData(client, JSON.stringify({ jsonrpc: '2.0', id: 'unknown', method: 'LaunchApp' }));
  assert.equal(calls.length, 0);
  assert.deepEqual(client.responses.map((response) => response.error.code), [-32700, -32602, -32601]);
  assert.equal(client.responses[1].id, 'bad-part');
});

test('cancel only affects the originating connection and suppresses late completion', () => {
  const { agent, calls } = harness();
  const first = proxy();
  const other = proxy();
  agent.onData(first, message('request-1', 'task-1'));
  agent.onData(other, cancel('cancel-other', 'task-1'));
  assert.equal(other.responses[0].error.code, -32001);
  assert.equal(calls[0].cancellation.cancelled, false);
  agent.onData(first, cancel('cancel-own', 'task-1'));
  assert.equal(calls[0].cancellation.cancelled, true);
  assert.equal(first.responses[0].id, 'cancel-own');
  assert.equal(first.responses[0].result.status.state, 'TASK_STATE_CANCELED');
  calls[0].onEvent({ type: 'delta', content: 'late' });
  calls[0].onComplete();
  assert.equal(first.responses.length, 1);
});

test('missing terminal event and stream error cannot produce a completed answer', () => {
  const { agent, calls } = harness();
  const first = proxy();
  agent.onData(first, message('request-1', 'task-1'));
  calls[0].onEvent({ type: 'delta', content: 'partial' });
  calls[0].onComplete();
  assert.equal(first.responses[0].result.task.status.state, 'TASK_STATE_FAILED');
  agent.onData(first, message('request-2', 'task-2'));
  calls[1].onError({ code: 'MODEL_TIMEOUT' });
  assert.equal(first.responses[1].result.task.status.state, 'TASK_STATE_FAILED');
});

test('same task ID on separate connections remains isolated', () => {
  const { agent, calls } = harness();
  const first = proxy();
  const second = proxy();
  agent.onData(first, message('request-1', 'shared-id', '问题一'));
  agent.onData(second, message('request-2', 'shared-id', '问题二'));
  assert.equal(calls.length, 2);
  agent.onData(first, cancel('cancel-1', 'shared-id'));
  assert.equal(calls[0].cancellation.cancelled, true);
  assert.equal(calls[1].cancellation.cancelled, false);
  calls[1].onEvent({ type: 'delta', content: '第二个回答' });
  calls[1].onEvent({ type: 'done' });
  calls[1].onComplete();
  assert.equal(second.responses[0].result.task.status.state, 'TASK_STATE_COMPLETED');
});

test('disconnect cancels its tasks, frees capacity and leaves other connections active', () => {
  const { agent, calls } = harness();
  const first = proxy();
  const second = proxy();
  const third = proxy();
  agent.onData(first, message('request-1', 'task-1'));
  agent.onData(second, message('request-2', 'task-2'));
  agent.onData(third, message('request-3', 'task-3'));
  assert.equal(third.responses[0].error.code, -32002);
  agent.onDisconnect({}, first);
  assert.equal(calls[0].cancellation.cancelled, true);
  assert.equal(calls[1].cancellation.cancelled, false);
  agent.onData(third, message('request-4', 'task-3'));
  assert.equal(calls.length, 3);
  calls[0].onEvent({ type: 'done' });
  calls[0].onComplete();
  assert.equal(first.responses.length, 0);
});

test('follow-up history is limited to the original connection and context', () => {
  const { agent, calls } = harness();
  const first = proxy();
  const second = proxy();
  agent.onData(first, message('request-1', 'context-1', '解释进程'));
  calls[0].onEvent({ type: 'delta', content: '进程是资源分配单位。' });
  calls[0].onEvent({ type: 'done' });
  calls[0].onComplete();
  const followUp = JSON.parse(message('request-2', 'task-2', '线程呢？'));
  followUp.params.message.contextId = 'context-1';
  agent.onData(first, JSON.stringify(followUp));
  agent.onData(second, JSON.stringify({ ...followUp, id: 'request-3' }));
  assert.equal(calls[1].body.history.length, 2);
  assert.equal(calls[1].body.history[0].content, '解释进程');
  assert.equal(calls[2].body.history.length, 0);
});
