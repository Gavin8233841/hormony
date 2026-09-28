// Synthetic end-to-end probe: actual Agent Extension source, a test network
// adapter, and the public Tutor SSE endpoint. It does not run inside HarmonyOS
// or establish a XiaoYi platform connection.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const ts = require(require.resolve('typescript', { paths: [resolve(repo, 'apps/web')] }));
const source = readFileSync(resolve(repo,
  'apps/harmonyos/entry/src/main/ets/agentability/XiaoyiAgentAbility.ets'), 'utf8');
const constants = readFileSync(resolve(repo,
  'apps/harmonyos/entry/src/main/ets/common/Constants.ets'), 'utf8');
const baseUrl = constants.match(/static readonly BASE_URL: string = '(https:\/\/[^']+)'/)?.[1];
assert.ok(baseUrl, 'HAP public base URL must be present');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;

let networkPromise;
class HttpRequestCancellation {
  child;
  cancel() { this.child?.kill(); }
}
const HttpClient = {
  postSSE(path, body, onEvent, onDone, onError, _created, cancellation) {
    networkPromise = (async () => {
      try {
        const output = await new Promise((resolve, reject) => {
          const child = spawn('curl', [
            '--silent', '--show-error', '--fail-with-body', '--max-time', '100',
            '-X', 'POST', '-H', 'Content-Type: application/json',
            '-H', 'Accept: text/event-stream', '--data-binary', '@-',
            '-w', '\n__PROBE_STATUS__%{http_code}:%{content_type}', baseUrl + path,
          ]);
          cancellation.child = child;
          let stdout = '';
          let stderr = '';
          child.stdout.setEncoding('utf8');
          child.stderr.setEncoding('utf8');
          child.stdout.on('data', (chunk) => { stdout += chunk; });
          child.stderr.on('data', (chunk) => { stderr += chunk; });
          child.on('error', reject);
          child.on('close', (code) => code === 0 ? resolve(stdout) : reject(new Error(
            `curl exit ${code}: ${stderr.slice(0, 300)}`)));
          child.stdin.end(body);
        });
        const marker = '\n__PROBE_STATUS__';
        const markerAt = output.lastIndexOf(marker);
        assert.ok(markerAt > 0, 'curl should report the response status');
        const status = output.slice(markerAt + marker.length);
        assert.match(status, /^200:text\/event-stream/);
        const responseBody = output.slice(0, markerAt).replace(/\r\n/g, '\n');
        let sawDone = false;
        for (const frame of responseBody.split('\n\n')) {
          const data = frame.split('\n').filter((line) => line.startsWith('data:'))
            .map((line) => line.slice(5).trimStart()).join('\n');
          if (data) {
            const event = JSON.parse(data);
            onEvent(event);
            if (event.type === 'done') sawDone = true;
          }
        }
        assert.ok(sawDone, 'Tutor SSE must finish with done');
        onDone();
      } catch (error) {
        onError({ message: String(error) });
        throw error;
      }
    })();
  },
};
const module = { exports: {} };
const imports = {
  '@kit.AbilityKit': { AgentExtensionAbility: class {} },
  '@kit.ArkTS': { util: { generateRandomUUID: () => crypto.randomUUID() } },
  '../common/HttpClient': { HttpClient, HttpRequestCancellation },
  '../common/Constants': { Constants: { API_XIAOYI_TUTOR: '/api/xiaoyi/tutor' } },
};
vm.runInNewContext(compiled, {
  module, exports: module.exports,
  require(id) {
    assert.ok(id in imports, `Unexpected runtime import: ${id}`);
    return imports[id];
  },
}, { filename: 'XiaoyiAgentAbility.ets' });

const agent = new module.exports.default();
const frames = [];
const proxy = { sendData(data) { frames.push(JSON.parse(data)); } };
agent.onData(proxy, JSON.stringify({
  jsonrpc: '2.0', id: 'live-probe-1', method: 'MessageStream',
  params: { message: {
    messageId: 'synthetic-question-1', role: 'ROLE_USER',
    parts: [{ text: '用一个三节点例子解释二叉搜索树查找。', mediaType: 'text/plain' }],
  } },
}));
assert.equal(frames[0]?.result?.task?.status?.state, 'TASK_STATE_SUBMITTED');
assert.ok(networkPromise, 'Extension should start one Tutor request');
await networkPromise;
const artifact = frames.find((frame) => frame.result?.artifactUpdate)?.result.artifactUpdate;
const completed = frames.find((frame) =>
  frame.result?.statusUpdate?.status?.state === 'TASK_STATE_COMPLETED');
assert.ok(artifact, 'Extension should return an artifact');
assert.ok(completed, 'Extension should return a completed task');
assert.equal(artifact.taskId, frames[0].result.task.id);
assert.equal(completed.result.statusUpdate.contextId, frames[0].result.task.contextId);
const answer = artifact.artifact.parts[0].text;
assert.ok(answer.length > 30);
assert.match(answer, /参考资料：/);
const sourceCount = answer.split('\n').filter((line) => /^\[\d\] /.test(line)).length;
assert.ok(sourceCount >= 1 && sourceCount <= 3);
console.log(JSON.stringify({
  baseUrl, requestCount: 1, frameCount: frames.length,
  taskStates: [frames[0].result.task.status.state, completed.result.statusUpdate.status.state],
  answerChars: answer.length, sourceCount,
}));
