import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const profilePath = path.resolve(scriptDirectory, '../apps/harmonyos/entry/src/main/ets/pages/Profile.ets');
const constantsPath = path.resolve(scriptDirectory, '../apps/harmonyos/entry/src/main/ets/common/Constants.ets');

function readSource(filePath) {
  return readFileSync(filePath, 'utf8').replaceAll('\r\n', '\n');
}

function sourceSection(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `missing source boundary: ${startMarker}`);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `missing source boundary: ${endMarker}`);
  return source.slice(start, end);
}

test('画像只消费按课程与知识点隔离的真实掌握状态', () => {
  const source = readSource(profilePath);
  assert.equal(source.includes('LocalLearningRepository.getTopicMastery()'), true,
    'profile must read persisted Topic mastery');
  assert.equal(source.includes('LocalLearningRepository.getCourses()'), true,
    'profile must validate mastery against the local course catalog');
  for (const staleSource of ['getTagInsights(', '.weakTopics', '.strongTopics', '.learningStyle']) {
    assert.equal(source.includes(staleSource), false,
      `profile must not present unisolated or non-derived evidence: ${staleSource}`);
  }
});

test('画像快照完整读取后一次提交且失败可恢复', () => {
  const source = readSource(profilePath);
  const loadProfile = sourceSection(source,
    '  async loadProfile(): Promise<void> {', '\n  private sortTopicMastery(');
  const masteryRead = loadProfile.indexOf('await LocalLearningRepository.getTopicMastery()');
  const profileCommit = loadProfile.indexOf('this.profile = profile;');
  assert.equal(loadProfile.includes('if (this.loading) return;'), true,
    'repeated retry must not start overlapping reads');
  assert.equal(masteryRead < profileCommit, true,
    'profile state must not expose a partially loaded evidence snapshot');
  for (const reset of ['this.profile = null;', 'this.courses = [];', 'this.topicMastery = [];',
    "this.message = '本地学习画像加载失败';"]) {
    assert.equal(loadProfile.includes(reset), true, `failed load missing reset: ${reset}`);
  }

  const retryNames = source.match(/\.accessibilityText\('重新加载学习画像'\)/g) ?? [];
  const retryActions = source.match(/\.onClick\(\(\): void => \{ this\.loadProfile\(\); \}\)/g) ?? [];
  assert.equal(retryNames.length, 2, 'both profile error states need an explicit screen-reader name');
  assert.equal(retryActions.length, 2, 'both profile error states must retry the same snapshot load');
});

test('知识点排序由未掌握、累计正确率与最近答题时间决定', () => {
  const source = readSource(profilePath);
  const sorting = sourceSection(source,
    '  private sortTopicMastery(items: TopicMastery[]): TopicMastery[] {', '\n  private openLearningMap(');
  assert.equal(sorting.includes('left.mastered !== right.mastered'), true,
    'unmastered topics must be ranked before mastered topics');
  assert.equal(sorting.includes('left.accuracy - right.accuracy'), true,
    'lower cumulative accuracy must rank first');
  assert.equal(sorting.includes("(right.lastPracticedAt ?? '').localeCompare(left.lastPracticedAt ?? '')"), true,
    'equal-accuracy topics need deterministic recency ordering');
});

test('练习入口只写入本地目录中的精确课程 Topic', () => {
  const source = readSource(profilePath);
  const findCourse = sourceSection(source,
    '  private findCourse(item: TopicMastery): Course | undefined {', '\n  private topicCourseTitle(');
  const openQuiz = sourceSection(source,
    '  private openFocusedQuiz(item: TopicMastery): void {', '\n  @Builder\n  GrowthEntry(');
  assert.equal(findCourse.includes('course.id === item.courseId && course.topics.includes(item.topic)'), true,
    'course and Topic must be validated as one exact catalog pair');
  assert.equal(openQuiz.indexOf('if (course === undefined)') < openQuiz.indexOf('AppStorage.setOrCreate'), true,
    'invalid catalog context must be rejected before any navigation state is written');
  assert.equal(openQuiz.includes("AppStorage.setOrCreate<string>('selectedCourseTitle', course.title)"), true,
    'course title must come from the local catalog');
  assert.equal(openQuiz.includes("AppStorage.setOrCreate<string>('selectedQuizFocusTag', '')"), true,
    'topic-level practice must clear a stale tag filter');
});

test('画像操作具备明确名称与可随字体增长的触控区', () => {
  const source = readSource(profilePath);
  const growthEntry = sourceSection(source,
    '  @Builder\n  GrowthEntry(', '\n  @Builder\n  Metric(');
  const topicRow = sourceSection(source,
    '  @Builder\n  TopicMasteryRow(', '\n  @Builder\n  ProfileSkeleton(');
  assert.equal(growthEntry.includes('.constraintSize({ minHeight: 64 })'), true,
    'profile destinations must grow beyond their baseline height');
  assert.equal(growthEntry.includes('.accessibilityText(title)'), true,
    'profile destinations need stable screen-reader names');
  assert.equal(topicRow.includes('.constraintSize({ minHeight: 48 })'), true,
    'topic practice needs a 48vp minimum touch target');
  assert.equal(topicRow.includes(".accessibilityDescription('打开测验，新结果将更新知识点画像')"), true,
    'topic action must explain its state-changing result');
  assert.equal(source.includes('.position('), false,
    'profile content must not depend on fixed x/y positions on narrow screens');
  assert.equal(source.includes(".accessibilityText('打开学习星图')"), true,
    'the responsive learning map entry needs one action name');

  const mapEntry = sourceSection(source,
    '                  .backgroundColor(Constants.COLOR_MAP_CORE)',
    '\n            Column({ space: 10 }) {');
  assert.equal(mapEntry.includes('.fontColor([Constants.COLOR_BRAND_TEXT])'), true,
    'the map entry icon must contrast with its light icon surface');
  assert.equal(mapEntry.includes("Text('学习星图')"), true,
    'the map entry contract must cover its visible title');
  assert.equal(mapEntry.includes('.fontColor(Constants.COLOR_MAP_CORE)'), true,
    'the map entry title must contrast with the dark map surface');
  assert.equal(mapEntry.includes('.fontColor([Constants.COLOR_MAP_CORE])'), true,
    'the map entry chevron must remain visible on the dark map surface');
  assert.equal(mapEntry.includes('.fontColor(Constants.COLOR_TEXT_PRIMARY)'), false,
    'dark primary text is invisible on the dark map surface');
});

test('统计播报明确真实证据来源且颜色引用均已定义', () => {
  const source = readSource(profilePath);
  const constants = readSource(constantsPath);
  assert.equal(source.includes('来自本机答题与学习事件'), true,
    'visible statistics must state their local evidence source');
  assert.equal(source.includes(".accessibilityDescription('统计来自本机已保存的答题与学习事件')"), true,
    'screen-reader statistics must state their evidence source');

  const references = [...source.matchAll(/Constants\.(\w+)/g)].map((match) => match[1]);
  for (const reference of new Set(references)) {
    assert.equal(constants.includes(` ${reference}:`), true,
      `Profile.ets references an undefined design token: ${reference}`);
  }
});
