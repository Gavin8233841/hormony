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
  return relations.map((relation, index) => ({
    ...relation,
    order: index + 1,
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

function reachableSuccessors(node, nodes) {
  const successors = [];
  const pendingIds = [node.id];
  for (let pendingIndex = 0; pendingIndex < pendingIds.length; pendingIndex += 1) {
    const sourceId = pendingIds[pendingIndex];
    for (const item of nodes) {
      if (!item.prerequisiteIds.includes(sourceId) ||
        successors.some((value) => value.id === item.id)) continue;
      successors.push(item);
      pendingIds.push(item.id);
    }
  }
  return successors;
}

function findRecommendedNode(nodes) {
  return nodes.filter((node) => !node.mastered && node.unlocked)
    .sort((left, right) => left.level - right.level || left.order - right.order)[0] ?? null;
}

function recommendedReachableAction(node, nodes) {
  const successors = reachableSuccessors(node, nodes);
  const successor = findRecommendedNode(successors);
  if (successor !== null) return successor;
  const prerequisites = [];
  for (const item of successors) {
    if (item.mastered) continue;
    const target = firstActionablePrerequisite(item, nodes);
    if (target !== null && !prerequisites.some((value) => value.id === target.id)) prerequisites.push(target);
  }
  return findRecommendedNode(prerequisites);
}

function nextActionTarget(node, nodes) {
  if (node.mastered) return recommendedReachableAction(node, nodes) ?? node;
  if (!node.unlocked) return firstActionablePrerequisite(node, nodes);
  return node;
}

const learningMapSource = readSource(learningMapPath);
const relations = JSON.parse(readSource(relationsPath));

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

test('真实 33 Topic DAG 的每个锁定节点都能解析到未掌握且已解锁的前置动作', () => {
  assert.equal(relations.length, 33, 'topic relation asset must contain the real 33 Topics');
  const courseIds = [...new Set(relations.map((item) => item.courseId))];
  assert.equal(courseIds.length, 3, 'topic relation asset must cover the three local courses');

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

test('已掌握节点只在全部可达后继掌握后才回到自身复习', () => {
  const courseIds = [...new Set(relations.map((item) => item.courseId))];
  let checkedReachableStates = 0;
  for (const courseId of courseIds) {
    const courseRelations = relations.filter((item) => item.courseId === courseId);
    const combinations = 2 ** courseRelations.length;
    for (let mask = 0; mask < combinations; mask += 1) {
      const masteredIds = new Set();
      for (let index = 0; index < courseRelations.length; index += 1) {
        if ((mask & (2 ** index)) !== 0) masteredIds.add(courseRelations[index].id);
      }
      const nodes = nodesFor(courseRelations, masteredIds);
      for (const node of nodes.filter((item) => item.mastered)) {
        const incompleteSuccessors = reachableSuccessors(node, nodes).filter((item) => !item.mastered);
        const target = nextActionTarget(node, nodes);
        if (incompleteSuccessors.length === 0) {
          assert.equal(target.id, node.id,
            `${courseId}/${node.topic} should return to itself only at its completed branch end`);
          continue;
        }
        assert.notEqual(target, null, `${courseId}/${node.topic} lost an actionable reachable path`);
        assert.notEqual(target.id, node.id, `${courseId}/${node.topic} incorrectly returned to self review`);
        assert.equal(target.unlocked, true, `${courseId}/${node.topic} resolved a locked action`);
        assert.equal(target.mastered, false, `${courseId}/${node.topic} resolved an already mastered action`);
        checkedReachableStates += 1;
      }
    }
  }
  assert.equal(checkedReachableStates > 0, true,
    'the exhaustive check must exercise mastered nodes with incomplete reachable paths');

  const networkRelations = relations.filter((item) => item.courseId === 'cs103');
  const networkNodes = nodesFor(networkRelations,
    new Set(['cs103_osi_model', 'cs103_physical_link']));
  const osi = networkNodes.find((item) => item.id === 'cs103_osi_model');
  assert.notEqual(osi, undefined, 'cs103 OSI root relation missing');
  assert.equal(recommendedReachableAction(osi, networkNodes)?.id, 'cs103_network_ip',
    'the audited two-hop path must advance from OSI through the mastered link layer to Network/IP');
  const independentlyMasteredNodes = nodesFor(networkRelations, new Set(['cs103_physical_link']));
  const physicalLink = independentlyMasteredNodes.find((item) => item.id === 'cs103_physical_link');
  assert.notEqual(physicalLink, undefined, 'cs103 physical/link relation missing');
  assert.equal(physicalLink.unlocked, false,
    'the regression state must keep the independently mastered node itself locked');
  assert.equal(nextActionTarget(physicalLink, independentlyMasteredNodes)?.id, 'cs103_network_ip',
    'an independently mastered locked node must still advance to its unlocked reachable successor');

  const reachability = sourceSection(learningMapSource,
    '  private reachableSuccessors(node: MapNode): MapNode[] {',
    '\n  private recommendedReachableAction(');
  const reachableAction = sourceSection(learningMapSource,
    '  private recommendedReachableAction(node: MapNode): MapNode | null {',
    '\n  private isReachableSuccessor(');
  const actionTarget = sourceSection(learningMapSource,
    '  private nextActionTarget(node: MapNode): MapNode | null {',
    '\n  private nextActionUsesPractice(');
  assert.equal(reachability.includes('item.prerequisiteIds.includes(sourceId)') &&
    reachability.includes('pendingIds.push(item.id)'), true,
  'the page must traverse all descendant levels rather than only direct successors');
  assert.equal(reachableAction.includes('this.findRecommendedNode(successors)') &&
    reachableAction.includes('this.firstActionablePrerequisite(item)') &&
    reachableAction.includes('this.findRecommendedNode(prerequisiteTargets)'), true,
  'reachable descendants must reuse the existing recommendation order and resolve locked merges');
  assert.equal(actionTarget.includes('this.recommendedReachableAction(node) ?? node'), true,
    'a mastered node may return to itself only when no reachable action remains');
  const masteredBranch = actionTarget.indexOf('if (node.mastery?.mastered === true)');
  const lockedBranch = actionTarget.indexOf('if (!node.unlocked)');
  assert.equal(masteredBranch >= 0 && lockedBranch > masteredBranch, true,
    'independently mastered Topics must resolve reachable actions before the lock branch');
  const masteryLabel = sourceSection(learningMapSource,
    '  private masteryLabel(node: MapNode): string {',
    '\n  private masteredCount(');
  const masteredLabelBranch = masteryLabel.indexOf('if (node.mastery !== null && node.mastery.mastered)');
  const lockedLabelBranch = masteryLabel.indexOf('if (!node.unlocked)');
  assert.equal(masteredLabelBranch >= 0 && lockedLabelBranch > masteredLabelBranch &&
    masteryLabel.includes("' · 前置未完成'"), true,
  'a mastered but relation-locked Topic must announce mastery first and retain the unmet prerequisite fact');
  const recommendationLabel = sourceSection(learningMapSource,
    '  private recommendationLabel(node: MapNode): string {',
    '\n  private selectedNode(');
  assert.equal(recommendationLabel.indexOf('if (node.mastery?.mastered === true)') <
    recommendationLabel.indexOf('if (!node.unlocked)') &&
    recommendationLabel.includes('保留本机测验掌握事实'), true,
  'the detail explanation must not replace persistent mastery with a locked-only description');
  const opacity = sourceSection(learningMapSource,
    '  private nodeOpacity(node: MapNode): number {',
    '\n  private nodeOuterOpacity(');
  assert.equal(opacity.includes('(node.mastery?.mastered === true || node.unlocked) ? 1 : 0.58'), true,
    'a mastered Topic must remain visually present even when its prerequisite relation is incomplete');
  assert.equal(learningMapSource.includes('private firstIncompleteSuccessor('), false,
    'the one-hop successor shortcut must not return');
  assert.equal(learningMapSource.includes('this.isReachableSuccessor(node, target)'), true,
    'labels and screen-reader descriptions must identify multi-hop successors correctly');
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
