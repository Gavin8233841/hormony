import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

const root = resolve(import.meta.dirname, '..');
const require = createRequire(join(root, 'apps', 'web', 'package.json'));
const ts = require('typescript');
const playerPath = join(root, 'apps', 'harmonyos', 'entry', 'src', 'main', 'ets', 'common',
  'LocalAudioPlayer.ets');
const lessonPath = join(root, 'apps', 'harmonyos', 'entry', 'src', 'main', 'ets', 'pages', 'Lesson.ets');
const resourcesPath = join(root, 'apps', 'harmonyos', 'entry', 'src', 'main', 'resources', 'rawfile',
  'learning', 'external-resources.json');
const experiencesPath = join(root, 'apps', 'harmonyos', 'entry', 'src', 'main', 'resources', 'rawfile',
  'learning', 'lesson-experiences.json');
const rawfileRoot = join(root, 'apps', 'harmonyos', 'entry', 'src', 'main', 'resources', 'rawfile');

class FakePlayer {
  constructor(actions, duration = 2763, emitInitialized = true) {
    this.actions = actions;
    this.duration = duration;
    this.currentTime = 0;
    this.state = 'idle';
    this.emitInitialized = emitInitialized;
    this.listeners = new Map();
    this.capturedStateListener = null;
  }

  set fdSrc(value) {
    this.actions.push(`fdSrc:${value.fd}:${value.offset}:${value.length}`);
    this.state = 'initialized';
    if (this.emitInitialized) queueMicrotask(() => this.emitState('initialized'));
  }

  on(type, callback) {
    this.listeners.set(type, callback);
    if (type === 'stateChange') this.capturedStateListener = callback;
  }

  off(type, callback) {
    if (this.listeners.get(type) === callback) this.listeners.delete(type);
  }

  async prepare() {
    this.actions.push('prepare');
    this.state = 'prepared';
    this.emitState('prepared');
  }

  async play() {
    this.actions.push('play');
    this.state = 'playing';
    this.emitState('playing');
  }

  async pause() {
    this.actions.push('pause');
    this.state = 'paused';
    this.emitState('paused');
  }

  async release() {
    this.actions.push('release');
    this.state = 'released';
    this.emitState('released');
  }

  emitState(state) {
    this.state = state;
    this.listeners.get('stateChange')?.(state, 1);
  }

  emitTime(timeMs) {
    this.currentTime = timeMs;
    this.listeners.get('timeUpdate')?.(timeMs);
  }

  complete() {
    this.currentTime = this.duration;
    this.emitState('completed');
  }
}

function loadPlayerClass(mediaRuntime) {
  const source = readFileSync(playerPath, 'utf8')
    .replace(/^import .*;\r?\n/gm, '')
    .replace(/\bexport /g, '');
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.None,
      target: ts.ScriptTarget.ES2022
    },
    fileName: playerPath
  }).outputText;
  const context = vm.createContext({
    media: mediaRuntime,
    hilog: { info() {}, warn() {}, error() {} },
    Constants: { HILOG_DOMAIN: 1, HILOG_TAG: 'test' },
    setTimeout,
    clearTimeout,
    queueMicrotask
  });
  vm.runInContext(`${transpiled}\nglobalThis.__LocalAudioPlayer = LocalAudioPlayer;`, context,
    { filename: playerPath });
  return context.__LocalAudioPlayer;
}

function createHarness({ emitInitialized = true, failCreateOnce = false, options } = {}) {
  const actions = [];
  const players = [];
  let createShouldFail = failCreateOnce;
  const mediaRuntime = {
    async createAVPlayer() {
      actions.push('create');
      if (createShouldFail) {
        createShouldFail = false;
        throw new Error('create failed once');
      }
      const player = new FakePlayer(actions, 2763, emitInitialized);
      players.push(player);
      return player;
    }
  };
  const manager = {
    async getRawFd(path) {
      actions.push(`open:${path}`);
      return { fd: 42, offset: 7, length: 89071 };
    },
    async closeRawFd(path) {
      actions.push(`close:${path}`);
    }
  };
  const snapshots = [];
  const Player = loadPlayerClass(mediaRuntime);
  const onSnapshot = (snapshot) => snapshots.push({ ...snapshot });
  const controller = options === undefined ? new Player(manager, onSnapshot) : new Player(manager, onSnapshot, options);
  return { actions, controller, players, snapshots };
}

function latestState(harness) {
  return harness.snapshots.at(-1)?.state;
}

test('真实控制器串行执行 raw FD、initialized、prepare、play、pause、complete 与幂等释放', async () => {
  const path = 'learning/media/en-us-one-could-hear-a-pin-drop.oga';
  const harness = createHarness();
  await harness.controller.toggle(path);
  assert.equal(latestState(harness), 'playing');
  assert.deepEqual(harness.actions.slice(0, 5), [
    `open:${path}`,
    'create',
    'fdSrc:42:7:89071',
    'prepare',
    'play'
  ]);

  harness.players[0].emitTime(1400);
  assert.equal(harness.snapshots.at(-1).currentTimeMs, 1400);
  await harness.controller.toggle(path);
  assert.equal(latestState(harness), 'paused');

  await harness.controller.toggle(path);
  harness.players[0].complete();
  assert.equal(latestState(harness), 'completed');
  assert.equal(harness.snapshots.at(-1).currentTimeMs, 2763);

  await harness.controller.toggle(path);
  assert.equal(latestState(harness), 'playing');
  const lateState = harness.players[0].capturedStateListener;
  await Promise.all([harness.controller.release(), harness.controller.release()]);
  lateState?.('playing', 1);
  assert.equal(latestState(harness), 'released');
  assert.equal(harness.actions.filter((item) => item === 'release').length, 1);
  assert.equal(harness.actions.filter((item) => item === `close:${path}`).length, 1);
  assert.ok(harness.actions.indexOf('release') < harness.actions.indexOf(`close:${path}`));
});

test('create 失败进入可见失败态并以全新 player/raw FD 重试成功', async () => {
  const path = 'learning/media/en-us-bookkeeper.ogg';
  const harness = createHarness({ failCreateOnce: true });
  await harness.controller.toggle(path);
  assert.equal(latestState(harness), 'failed');
  assert.equal(harness.actions.filter((item) => item === `close:${path}`).length, 1);

  await harness.controller.retry(path);
  assert.equal(latestState(harness), 'playing');
  assert.equal(harness.actions.filter((item) => item === `open:${path}`).length, 2);
  assert.equal(harness.actions.filter((item) => item === 'create').length, 2);
  assert.equal(harness.players.length, 1);
  await harness.controller.release();
});

test('可注入 prepare 失败，partial init 仍只 release/close 一次', async () => {
  const path = 'learning/media/en-us-bookkeeper.ogg';
  const harness = createHarness({ options: { failurePoint: 'prepare' } });
  await harness.controller.toggle(path);
  assert.equal(latestState(harness), 'failed');
  assert.equal(harness.actions.filter((item) => item === 'prepare').length, 0);
  assert.equal(harness.actions.filter((item) => item === 'release').length, 1);
  assert.equal(harness.actions.filter((item) => item === `close:${path}`).length, 1);
});

test('离页可取消尚未 initialized 的准备并拒绝迟到回调', async () => {
  const path = 'learning/media/en-us-one-could-hear-a-pin-drop.oga';
  const harness = createHarness({ emitInitialized: false });
  const pending = harness.controller.toggle(path);
  await new Promise((resolve) => setImmediate(resolve));
  const player = harness.players[0];
  const lateState = player.capturedStateListener;
  await harness.controller.release();
  await pending;
  lateState?.('initialized', 1);
  assert.equal(latestState(harness), 'released');
  assert.equal(harness.actions.filter((item) => item === 'prepare').length, 0);
  assert.equal(harness.actions.filter((item) => item === 'release').length, 1);
  assert.equal(harness.actions.filter((item) => item === `close:${path}`).length, 1);
});

test('Lesson 只消费本地 rawFilePath，静态文本默认隐藏且离页释放', () => {
  const source = readFileSync(lessonPath, 'utf8');
  assert.match(source, /LearningContentRepository\.getResources\(this\.courseId\)/);
  assert.match(source, /item\.id === resourceIds\[0\]/);
  assert.match(source, /player\.toggle\(this\.audioResource\.media\.rawFilePath\)/);
  assert.doesNotMatch(source, /audioResource\.media\.mediaUrl/);
  assert.match(source, /@State audioTranscriptVisible: boolean = false/);
  assert.match(source, /静态完整文本（非同步字幕）/);
  assert.match(source, /已随应用离线提供 · 不发起网络请求/);
  assert.match(source, /aboutToDisappear\(\): void \{\s*this\.releaseAudioSession\(false\)/);
  assert.match(source, /player\.release\(\)\.catch/);
  assert.match(source, /accessibilityText\(this\.audioActionAccessibilityText\(\)\)/);
  assert.match(source, /this\.audioResource\.media\.attribution/);
  assert.match(source, /this\.audioPublisher\(\) \+ ' · ' \+ this\.audioLicense\(\)/);
});

test('生成资产引用的两项音频存在、哈希匹配且明确无时间码', () => {
  const resources = JSON.parse(readFileSync(resourcesPath, 'utf8'));
  const experiences = JSON.parse(readFileSync(experiencesPath, 'utf8'));
  const audioResources = resources.filter((resource) => resource.type === 'audio');
  assert.equal(audioResources.length, 2);
  for (const resource of audioResources) {
    assert.ok(resource.media);
    assert.equal(resource.media.transcriptTimed, false);
    assert.ok(resource.media.transcript.length > 0);
    assert.match(resource.media.rawFilePath, /^learning\/media\//);
    const absolutePath = join(rawfileRoot, resource.media.rawFilePath);
    assert.equal(statSync(absolutePath).size, resource.media.byteLength);
    const sha256 = createHash('sha256').update(readFileSync(absolutePath)).digest('hex').toUpperCase();
    assert.equal(sha256, resource.evidence.sha256);
    const experience = experiences.find((item) => item.courseId === resource.courseId);
    assert.ok(experience?.mediaResourceIds?.includes(resource.id));
  }
});
