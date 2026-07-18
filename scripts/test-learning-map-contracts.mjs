import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const learningMapPath = path.join(repositoryRoot,
  'apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets');
const relationsPath = path.join(repositoryRoot,
  'apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json');
const courseCatalogPath = path.join(repositoryRoot,
  'apps/harmonyos/entry/src/main/resources/rawfile/learning/course-catalog.json');

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

function nodesFor(relations, masteredIds) {
  return relations.map((relation) => ({
    ...relation,
    mastered: masteredIds.has(relation.id),
    unlocked: relation.prerequisiteIds.every((id) => masteredIds.has(id)),
  }));
}

function firstIncompletePrerequisite(node, nodes) {
  for (const prerequisiteId of node.prerequisiteIds) {
    const prerequisite = nodes.find((item) => item.id === prerequisiteId);
    if (prerequisite !== undefined && !prerequisite.mastered) return prerequisite;
  }
  return null;
}

function firstActionablePrerequisite(node, nodes) {
  let target = firstIncompletePrerequisite(node, nodes);
  const visitedIds = [];
  while (target !== null && !target.unlocked && !visitedIds.includes(target.id)) {
    visitedIds.push(target.id);
    const earlier = firstIncompletePrerequisite(target, nodes);
    if (earlier === null) return null;
    target = earlier;
  }
  return target !== null && target.unlocked ? target : null;
}

const learningMapSource = readSource(learningMapPath);
const relations = JSON.parse(readSource(relationsPath));
const courseCatalog = JSON.parse(readSource(courseCatalogPath));

test('课程切换只提交最新请求的完整本机快照', () => {
  const selectCourse = sourceSection(learningMapSource,
    '  private async selectCourse(course: Course): Promise<void> {',
    '\n  private async loadCourseSnapshot(');
  const loadSnapshot = sourceSection(learningMapSource,
    '  private async loadCourseSnapshot(course: Course, requestVersion: number): Promise<void> {',
    '\n  private clearMapSnapshot(');

  assert.equal(selectCourse.includes('const requestVersion = ++this.requestVersion;'), true,
    'each course selection must receive a monotonic request version');
  assert.equal(selectCourse.includes('if (requestVersion === this.requestVersion)'), true,
    'stale failures must not replace the latest visible state');
  assert.equal(loadSnapshot.includes('LocalLearningRepository.getTopicMastery(course.id)'), true,
    'mastery must be read for the exact selected course');
  assert.equal(loadSnapshot.includes('LocalLearningRepository.getLessonProgress(course.id)'), true,
    'lesson progress must be read for the exact selected course');
  assert.equal(loadSnapshot.includes('LearningContentRepository.getTopicRelations(course.id)'), true,
    'relations must be read for the exact selected course');

  const latestGuard = loadSnapshot.indexOf('if (requestVersion !== this.requestVersion) return;');
  const courseCommit = loadSnapshot.indexOf('this.selectedCourseId = course.id;');
  const nodesCommit = loadSnapshot.indexOf('this.nodes = nextNodes;');
  assert.equal(latestGuard >= 0 && latestGuard < courseCommit && courseCommit < nodesCommit, true,
    'the latest-version guard must run before any course or node state is committed');
  assert.equal(loadSnapshot.slice(0, latestGuard).includes('this.selectedCourseId ='), false,
    'an incomplete request must not publish its course identity');
  assert.equal(loadSnapshot.slice(0, latestGuard).includes('this.nodes ='), false,
    'an incomplete request must not publish partial map nodes');
});

test('目录中真实 Topic DAG 的每个锁定节点都能解析到未掌握且已解锁的前置动作', () => {
  const catalogCourseIds = courseCatalog.map((item) => item.id).sort();
  const courseIds = [...new Set(relations.map((item) => item.courseId))];
  assert.deepEqual(courseIds.sort(), catalogCourseIds,
    'topic relation asset must cover every catalog course');
  assert.equal(relations.filter((item) => item.courseId.startsWith('cs')).length, 33,
    'the original 33 computer-science Topics must remain intact');

  let checkedLockedStates = 0;
  for (const courseId of courseIds) {
    const courseRelations = relations.filter((item) => item.courseId === courseId);
    const combinations = 2 ** courseRelations.length;
    for (let mask = 0; mask < combinations; mask += 1) {
      const masteredIds = new Set();
      for (let index = 0; index < courseRelations.length; index += 1) {
        if ((mask & (2 ** index)) !== 0) masteredIds.add(courseRelations[index].id);
      }
      const nodes = nodesFor(courseRelations, masteredIds);
      for (const node of nodes) {
        if (node.unlocked) continue;
        const target = firstActionablePrerequisite(node, nodes);
        assert.notEqual(target, null, `${courseId}/${node.topic} has no actionable prerequisite`);
        assert.equal(target.unlocked, true, `${courseId}/${node.topic} resolved a locked prerequisite`);
        assert.equal(target.mastered, false, `${courseId}/${node.topic} resolved an already mastered prerequisite`);
        checkedLockedStates += 1;
      }
    }
  }
  assert.equal(checkedLockedStates > 0, true, 'the exhaustive check must exercise locked states');

  const actionTarget = sourceSection(learningMapSource,
    '  private nextActionTarget(node: MapNode): MapNode | null {',
    '\n  private nextActionUsesPractice(');
  const runAction = sourceSection(learningMapSource,
    '  private runNextAction(node: MapNode): void {',
    '\n  private nodeAccessibilityText(');
  assert.equal(actionTarget.includes('this.firstActionablePrerequisite(node)'), true,
    'locked map nodes must resolve through their prerequisite path');
  assert.equal(runAction.includes('this.openPractice(target.topic)'), true,
    'practice navigation must receive the resolved exact Topic');
  assert.equal(runAction.includes('this.openLesson(target.topic)'), true,
    'lesson navigation must receive the resolved exact Topic');
  assert.equal(learningMapSource.includes('.enabled(node.unlocked)'), false,
    'locked nodes must not remain a disabled-action dead end');
});

test('学习动作保持精确 AppStorage 契约且导航失败可见', () => {
  const practice = sourceSection(learningMapSource,
    '  private openPractice(topic: string): void {', '\n  private openLesson(');
  const lesson = sourceSection(learningMapSource,
    '  private openLesson(topic: string): void {', '\n  @Builder\n  CourseSelector(');
  for (const section of [practice, lesson]) {
    assert.equal(section.includes("AppStorage.setOrCreate<string>('selectedCourseId', this.selectedCourseId)"), true);
    assert.equal(section.includes("AppStorage.setOrCreate<string>('selectedCourseTitle', this.selectedCourseTitle)"), true);
    assert.equal(section.includes('this.message ='), true,
      'navigation failures must leave visible recovery text');
  }
  assert.equal(practice.includes("AppStorage.setOrCreate<string>('selectedPracticeTopic', topic)"), true);
  assert.equal(lesson.includes("AppStorage.setOrCreate<string>('selectedContentTopic', topic)"), true);
  assert.equal(learningMapSource.includes('private retryMapLoad(): void'), true,
    'map load failures need one explicit retry path');
  assert.equal(learningMapSource.includes("Button('重新读取失败课程')"), true,
    'a failed course switch must expose a visible retry action while preserving the previous snapshot');
  assert.equal(learningMapSource.includes("Button('重新读取星图')"), true,
    'an initial load failure must expose a visible retry action');
});

test('课程、节点、摘要和主动作具备响应式读屏与 48vp 契约', () => {
  const courseSelector = sourceSection(learningMapSource,
    '  @Builder\n  CourseSelector() {', '\n  @Builder\n  MapCanvas() {');
  const mapCanvas = sourceSection(learningMapSource,
    '  @Builder\n  MapCanvas() {', '\n  @Builder\n  MapSummary() {');
  const summary = sourceSection(learningMapSource,
    '  @Builder\n  MapSummary() {', '\n  build() {');

  assert.equal(courseSelector.includes('.constraintSize({ minHeight: 48 })'), true,
    'course switches need a 48vp minimum touch target');
  assert.equal(courseSelector.includes('.accessibilityText('), true,
    'course switches need selected-state screen-reader text');
  assert.equal(mapCanvas.includes('.accessibilityText(this.nodeAccessibilityText(node))'), true,
    'each visual node needs a complete screen-reader name');
  assert.equal(summary.includes('数据来自本机测验掌握记录、课程学习进度与课程先修关系'), true,
    'the map summary must explain its real local evidence sources');
  assert.equal(learningMapSource.includes('Flex({ wrap: FlexWrap.Wrap'), true,
    'the four-item legend must wrap on narrow or enlarged-text layouts');
  assert.equal(learningMapSource.includes('.accessibilityText(this.actionAccessibilityText(node))'), true,
    'the primary action must announce its resolved Topic');
  const minimumTargets = learningMapSource.match(/\.constraintSize\(\{ minHeight: 48 \}\)/g) ?? [];
  assert.equal(minimumTargets.length >= 4, true,
    'course switches and all recovery or primary actions need 48vp minimum targets');
});
