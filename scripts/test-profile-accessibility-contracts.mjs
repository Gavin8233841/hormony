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

test('核心画像先展示且知识点辅助失败保留真实快照', () => {
  const source = readSource(profilePath);
  const loadProfile = sourceSection(source,
    '  async loadProfile(): Promise<void> {', '\n  private async loadMasteryContext(');
  const loadMastery = sourceSection(source,
    '  private async loadMasteryContext(): Promise<void> {', '\n  private dataRecoveryLabel(');
  const profileRead = loadProfile.indexOf('await LocalLearningRepository.getProfile()');
  const profileCommit = loadProfile.indexOf('this.profile = profile;');
  const auxiliaryLoad = loadProfile.indexOf('await this.loadMasteryContext();');
  const loadingRelease = loadProfile.lastIndexOf('this.loading = false;', auxiliaryLoad);
  assert.equal(loadProfile.includes('if (this.loading) return;'), true,
    'repeated retry must not start overlapping reads');
  assert.equal(profileRead >= 0 && profileCommit > profileRead && loadingRelease > profileCommit &&
    auxiliaryLoad > loadingRelease, true,
  'core profile facts must render before awaiting Topic mastery context');
  assert.equal(loadProfile.includes('LocalLearningRepository.getCourses()') ||
    loadProfile.includes('LocalLearningRepository.getTopicMastery()'), false,
  'course and Topic mastery reads must stay out of the core profile phase');
  const coreCatchStart = loadProfile.indexOf('} catch (_) {');
  const coreCatchEnd = loadProfile.indexOf('\n    }\n    this.loading = false;', coreCatchStart);
  const coreCatch = loadProfile.slice(coreCatchStart, coreCatchEnd);
  for (const destructiveReset of ['this.profile = null;', 'this.courses = [];', 'this.topicMastery = [];']) {
    assert.equal(coreCatch.includes(destructiveReset), false,
      `refresh failure must preserve the previous snapshot: ${destructiveReset}`);
  }
  assert.equal(coreCatch.includes('当前显示上次读取结果'), true,
    'core refresh failure must explain the retained snapshot');

  const courseRead = loadMastery.indexOf('await LocalLearningRepository.getCourses()');
  const masteryRead = loadMastery.indexOf('await LocalLearningRepository.getTopicMastery()');
  const courseCommit = loadMastery.indexOf('this.courses = courses;');
  const masteryCommit = loadMastery.indexOf('this.topicMastery = topicMastery;');
  assert.equal(courseRead >= 0 && masteryRead > courseRead && courseCommit > masteryRead &&
    masteryCommit > courseCommit, true,
  'auxiliary course and Topic facts must commit as one validated snapshot');
  const auxiliaryCatchStart = loadMastery.indexOf('} catch (_) {');
  const auxiliaryCatchEnd = loadMastery.indexOf('\n    } finally {', auxiliaryCatchStart);
  const auxiliaryCatch = loadMastery.slice(auxiliaryCatchStart, auxiliaryCatchEnd);
  assert.equal(auxiliaryCatch.includes('this.courses = [];') ||
    auxiliaryCatch.includes('this.topicMastery = [];'), false,
  'auxiliary failure must preserve the previous course and mastery snapshot');
  assert.equal(auxiliaryCatch.includes('当前统计与成长入口仍可使用'), true,
    'auxiliary failure must explain which core facts remain usable');
  assert.equal(source.includes('if (this.loading && this.profile === null)'), true,
    'refreshing an existing profile must not replace it with a skeleton');
});

test('旧知识点回调不能覆盖新画像且数据恢复只重试失败阶段', () => {
  const source = readSource(profilePath);
  const loadProfile = sourceSection(source,
    '  async loadProfile(): Promise<void> {', '\n  private async loadMasteryContext(');
  const loadMastery = sourceSection(source,
    '  private async loadMasteryContext(): Promise<void> {', '\n  private dataRecoveryLabel(');
  const invalidation = loadProfile.indexOf('this.masteryLoadSequence += 1;');
  const profileRead = loadProfile.indexOf('await LocalLearningRepository.getProfile()');
  assert.equal(invalidation >= 0 && profileRead >= 0 && invalidation < profileRead, true,
  'a new core load must invalidate the previous auxiliary request first');
  assert.equal(loadMastery.includes('const requestSequence = ++this.masteryLoadSequence;'), true);
  const finalRead = loadMastery.indexOf('await LocalLearningRepository.getTopicMastery()');
  const staleGuard = loadMastery.indexOf('if (requestSequence !== this.masteryLoadSequence) return;', finalRead);
  const firstCommit = loadMastery.indexOf('this.courses = courses;');
  assert.equal(staleGuard > finalRead && firstCommit > staleGuard, true,
    'only the latest auxiliary request may commit its validated snapshot');
  assert.equal(loadMastery.includes(
    'if (requestSequence === this.masteryLoadSequence) this.masteryLoading = false;'), true,
  'a stale auxiliary request must not end a newer loading state');

  const retryData = sourceSection(source,
    '  private retryDataRecovery(): void {', '\n  private sortTopicMastery(');
  assert.match(retryData,
    /if\s*\(this\.dataRecoveryAction === PROFILE_RECOVERY_MASTERY\)\s*\{\s*this\.loadMasteryContext\(\);\s*return;\s*\}\s*this\.loadProfile\(\);/,
    'Topic mastery recovery must retry only auxiliary data and core recovery must retry only profile data');
  assert.equal(source.includes('.onClick((): void => { this.retryDataRecovery(); })'), true,
    'visible data recovery must dispatch the exact failed phase');
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
    '  private openFocusedQuiz(item: TopicMastery): void {', '\n  private navigateFocusedQuiz(');
  const navigateQuiz = sourceSection(source,
    '  private navigateFocusedQuiz(course: Course, topic: string): void {', '\n  private retryNavigation(');
  assert.equal(findCourse.includes('course.id === item.courseId && course.topics.includes(item.topic)'), true,
    'course and Topic must be validated as one exact catalog pair');
  assert.equal(openQuiz.includes('if (course === undefined)') &&
    openQuiz.includes('this.navigateFocusedQuiz(course, item.topic);'), true,
  'invalid catalog context must be rejected before the exact navigation helper is called');
  assert.equal(navigateQuiz.includes("AppStorage.setOrCreate<string>('selectedCourseTitle', course.title)"), true,
    'course title must come from the local catalog');
  assert.equal(navigateQuiz.includes("AppStorage.setOrCreate<string>('selectedQuizFocusTag', '')"), true,
    'topic-level practice must clear a stale tag filter');
});

test('导航失败保存原目标并精确重试路由或课程 Topic', () => {
  const source = readSource(profilePath);
  const openPage = sourceSection(source,
    '  private openPage(url: string, target: string): void {', '\n  private findCourse(');
  const navigateQuiz = sourceSection(source,
    '  private navigateFocusedQuiz(course: Course, topic: string): void {', '\n  private retryNavigation(');
  const retryNavigation = sourceSection(source,
    '  private retryNavigation(): void {', '\n  @Builder\n  GrowthEntry(');
  assert.equal(source.includes('private navigationSequence: number = 0;'), true,
    'navigation failures need one monotonic owner');
  for (const action of [openPage, navigateQuiz]) {
    const requestStart = action.indexOf('const requestSequence = this.beginNavigation();');
    const routeAttempt = action.indexOf('.pushUrl(');
    const staleGuard = action.indexOf('if (requestSequence !== this.navigationSequence) return;');
    const failureCommit = action.indexOf('this.navigationMessage =');
    assert.equal(requestStart >= 0 && routeAttempt > requestStart && staleGuard > routeAttempt &&
      failureCommit > staleGuard, true,
    'only the newest navigation failure may publish a retry target');
  }
  for (const contract of ['this.pendingNavigationKind = PROFILE_NAVIGATION_ROUTE;',
    'this.pendingRoute = url;', 'this.navigationTarget = target;']) {
    assert.equal(openPage.includes(contract), true, `generic route failure missing ${contract}`);
  }
  for (const contract of ['this.pendingNavigationKind = PROFILE_NAVIGATION_QUIZ;',
    'this.pendingCourseId = course.id;', 'this.pendingTopic = topic;']) {
    assert.equal(navigateQuiz.includes(contract), true, `quiz route failure missing ${contract}`);
  }
  assert.equal(retryNavigation.includes('this.openPage(route, target);'), true,
    'generic navigation recovery must retry the original route');
  assert.equal(retryNavigation.includes('item.id === courseId && item.topics.includes(topic)'), true,
    'quiz recovery must revalidate the exact course and Topic pair');
  assert.equal(retryNavigation.includes('this.navigateFocusedQuiz(course, topic);'), true,
    'quiz recovery must rewrite the exact AppStorage context and retry Quiz');
  assert.equal(retryNavigation.includes('this.loadProfile();'), false,
    'navigation recovery must not masquerade as a data reload');
  assert.equal(source.includes('.onClick((): void => { this.retryNavigation(); })'), true,
    'navigation error action must dispatch the stored route retry');
  assert.equal(source.includes(".accessibilityText('重试打开' + this.navigationTarget)"), true,
    'navigation retry must announce its exact target');
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

  const dataError = sourceSection(source,
    '            if (this.dataMessage.length > 0) {',
    '\n            if (this.navigationMessage.length > 0) {');
  assert.equal(dataError.includes('.constraintSize({ minHeight: 48 })'), true,
    'data recovery needs a 48vp minimum target');
  assert.equal(dataError.includes('.accessibilityText(this.dataRecoveryLabel())') &&
    dataError.includes('.accessibilityDescription(this.dataMessage)'), true,
  'data recovery must announce the dynamic failed stage and reason');
  const navigationError = sourceSection(source,
    '            if (this.navigationMessage.length > 0) {',
    '\n            Row({ space: 16 }) {');
  assert.equal(navigationError.includes('.constraintSize({ minHeight: 48 })'), true,
    'navigation recovery needs a 48vp minimum target');
  assert.equal(navigationError.includes(".accessibilityText('重试打开' + this.navigationTarget)") &&
    navigationError.includes('.accessibilityDescription(this.navigationMessage)'), true,
  'navigation recovery must announce the exact target and failure reason');
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
