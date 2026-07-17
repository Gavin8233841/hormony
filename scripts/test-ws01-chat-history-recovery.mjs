import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const chat = readFileSync(
  resolve(repositoryRoot, 'apps/harmonyos/entry/src/main/ets/pages/Chat.ets'),
  'utf8'
).replace(/\r\n/g, '\n');

function methodBody(source, signature, label) {
  const signatureIndex = source.indexOf(signature);
  assert.notEqual(signatureIndex, -1, `${label}: missing ${signature}`);
  const openBrace = source.indexOf('{', signatureIndex + signature.length);
  assert.notEqual(openBrace, -1, `${label}: missing opening brace`);

  let depth = 0;
  let quote = '';
  let escaped = false;
  for (let index = openBrace; index < source.length; index += 1) {
    const character = source[index];
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
    if (character === "'" || character === '"' || character === '`') {
      quote = character;
      continue;
    }
    if (character === '{') depth += 1;
    if (character === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(openBrace + 1, index);
    }
  }
  assert.fail(`${label}: missing closing brace`);
}

function arkBodyToJavaScript(body) {
  return body
    .replace(/const restored: string\[\] =/g, 'const restored =')
    .replace(/const restored: Citation\[\] =/g, 'const restored =')
    .replace(/const restored: DisplayMessage\[\] =/g, 'const restored =')
    .replace(/const message: DisplayMessage =/g, 'const message =')
    .replace(/let pendingUser: DisplayMessage \| null =/g, 'let pendingUser =');
}

function compileMethod(signature, parameters, label, dependencies = {}) {
  const body = arkBodyToJavaScript(methodBody(chat, signature, label));
  const dependencyNames = Object.keys(dependencies);
  const dependencyValues = Object.values(dependencies);
  const factory = new Function(
    ...dependencyNames,
    `return ${signature.startsWith('  private async ') ? 'async ' : ''}function(${parameters.join(', ')}) {${body}};`
  );
  return factory(...dependencyValues);
}

function recoveryHarness(repository) {
  const harness = {
    cloudAgentReady: true,
    loading: false,
    historyLoading: true,
    historySaving: false,
    historyLoadFailed: false,
    historySaveFailed: false,
    historyMessage: '',
    inputText: '继续提问',
    messages: []
  };
  harness.restoredHistoryStrings = compileMethod(
    '  private restoredHistoryStrings(', ['values'], 'history string evidence'
  );
  harness.restoredHistoryCitations = compileMethod(
    '  private restoredHistoryCitations(', ['values'], 'history citations'
  );
  harness.restoredHistoryMessage = compileMethod(
    '  private restoredHistoryMessage(', ['item'], 'history message'
  );
  harness.restoredCompleteHistory = compileMethod(
    '  private restoredCompleteHistory(', ['history'], 'complete history'
  );
  harness.loadLocalHistory = compileMethod(
    '  private async loadLocalHistory(', [], 'history load', { LocalLearningRepository: repository }
  );
  harness.skipUnreadableHistory = compileMethod(
    '  private skipUnreadableHistory(', [], 'skip unreadable history'
  );
  harness.canSend = compileMethod('  get canSend()', [], 'send availability');
  harness.sendButtonHint = compileMethod('  private sendButtonHint()', [], 'history status hint');
  return harness;
}

function damagedHistoryFixture() {
  return [
    null,
    { role: 'assistant', content: '没有问题的孤立回答' },
    { role: 'system', content: '非法角色不能恢复' },
    { role: 'user', content: '   ' },
    {
      role: 'user',
      content: '  什么是二叉树？  ',
      citations: { doc: '不是数组' },
      agentTrace: '不是数组',
      thinking: [' ', 'Profile', 7]
    },
    {
      role: 'assistant',
      content: '  每个节点最多有两个孩子。  ',
      citations: [null, 9, { doc: '' }, { doc: ' 课程讲义 ' }, { doc: ' 树章节 ', snippet: ' 定义 ' }],
      agentTrace: { agent: '不是数组' },
      thinking: ['Tutor', '', false]
    },
    { role: 'user', content: '没有回答的尾部问题' }
  ];
}

test('restores only complete user and assistant pairs from damaged ArkData records', () => {
  const harness = recoveryHarness({ getChatHistory: async () => [] });
  const restored = harness.restoredCompleteHistory(damagedHistoryFixture());

  assert.deepEqual(restored, [
    {
      role: 'user',
      content: '什么是二叉树？',
      citations: [],
      agentTrace: [],
      thinking: ['Profile'],
      agentExpanded: false,
      citationExpanded: false,
      streaming: false,
      failed: false,
      cancelled: false,
      statusMessage: '',
      httpStatus: 0,
      errorCode: '',
      statusExpanded: false,
      retryQuestion: ''
    },
    {
      role: 'assistant',
      content: '每个节点最多有两个孩子。',
      citations: [{ doc: '课程讲义' }, { doc: '树章节', snippet: '定义' }],
      agentTrace: [],
      thinking: ['Tutor'],
      agentExpanded: false,
      citationExpanded: false,
      streaming: false,
      failed: false,
      cancelled: false,
      statusMessage: '',
      httpStatus: 0,
      errorCode: '',
      statusExpanded: false,
      retryQuestion: ''
    }
  ]);
});

test('damaged records remain observable without blocking a new question', async () => {
  const fixture = damagedHistoryFixture();
  const harness = recoveryHarness({ getChatHistory: async () => fixture });

  await harness.loadLocalHistory.call(harness);

  assert.equal(harness.historyLoading, false);
  assert.equal(harness.historyLoadFailed, false);
  assert.equal(harness.messages.length, 2);
  assert.equal(harness.historyMessage, '已恢复 2 条，跳过 5 条损坏记录');
  assert.equal(harness.sendButtonHint.call(harness), harness.historyMessage);
  assert.equal(harness.canSend.call(harness), true, 'skipped damaged records must not disable sending');
});

test('an unreadable top-level payload can be skipped and then releases sending', async () => {
  const harness = recoveryHarness({
    getChatHistory: async () => ({ role: 'user', content: '顶层不是数组' })
  });

  await harness.loadLocalHistory.call(harness);

  assert.equal(harness.historyLoading, false);
  assert.equal(harness.historyLoadFailed, true);
  assert.equal(harness.canSend.call(harness), false);
  assert.equal(harness.sendButtonHint.call(harness), '本机会话暂时无法读取，可重试或跳过旧会话');

  harness.skipUnreadableHistory.call(harness);

  assert.equal(harness.historyLoadFailed, false);
  assert.deepEqual(harness.messages, []);
  assert.equal(harness.historyMessage, '已跳过旧会话，新回答完成后会保存到本机');
  assert.equal(harness.canSend.call(harness), true, 'skipping an unreadable payload must release sending');
});

test('history recovery actions and status are connected to the visible Chat UI', () => {
  assert.match(chat, /Text\(this\.sendButtonHint\(\)\.length > 0 \? this\.sendButtonHint\(\) : ' '\)/);
  assert.match(chat, /Button\(this\.historyLoadFailed \? '重新读取'/);
  assert.match(chat, /if \(this\.historyLoadFailed\) \{\s*Button\('跳过旧会话'\)/);
  assert.match(chat, /this\.skipUnreadableHistory\(\);/);
});
