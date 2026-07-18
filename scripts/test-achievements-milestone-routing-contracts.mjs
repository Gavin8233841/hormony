import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const paths = {
  achievements: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/pages/Achievements.ets'),
  localRepository: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets'),
  metadataModels: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/model/LearningMetadataModels.ets'),
  quizStateReducer: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/common/QuizLearningStateReducer.ets'),
  practice: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/pages/Practice.ets'),
  lesson: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/pages/Lesson.ets'),
  quiz: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/ets/pages/Quiz.ets'),
};

function readSource(filePath) {
  if (!existsSync(filePath)) return '';
  return readFileSync(filePath, 'utf8').replaceAll('\r\n', '\n');
}

function balancedBlockAt(source, markerIndex, label) {
  assert.notEqual(markerIndex, -1, `missing source boundary: ${label}`);
  const openingBrace = source.indexOf('{', markerIndex);
  assert.notEqual(openingBrace, -1, `missing opening brace: ${label}`);
  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}') depth -= 1;
    if (depth === 0) return source.slice(markerIndex, index + 1);
  }
  assert.fail(`missing closing brace: ${label}`);
}

function balancedBlock(source, marker) {
  return balancedBlockAt(source, source.indexOf(marker), marker);
}

function appStorageWriteKeys(source) {
  return Array.from(source.matchAll(/AppStorage\.setOrCreate<string>\('([^']+)'/g),
    (match) => match[1]);
}

function pushedPages(source) {
  return Array.from(source.matchAll(/this\.pushPage\('([^']+)'/g), (match) => match[1]);
}

const achievementsSource = readSource(paths.achievements);
const localRepositorySource = readSource(paths.localRepository);
const metadataModelsSource = readSource(paths.metadataModels);
const quizStateReducerSource = readSource(paths.quizStateReducer);
const practiceSource = readSource(paths.practice);
const lessonSource = readSource(paths.lesson);
const quizSource = readSource(paths.quiz);

test('500 条事件窗口淘汰 quiz_mastered 后长期掌握里程碑仍是成就事实源', () => {
  const masteryFact = {
    courseId: 'course-for-window-test',
    topic: 'topic-for-window-test',
    masteredAt: '2026-01-01T00:00:00.000Z',
  };
  const masteredEvent = {
    id: 'mastered-before-window',
    type: 'quiz_mastered',
    timestamp: masteryFact.masteredAt,
    courseId: masteryFact.courseId,
    topic: masteryFact.topic,
  };
  const laterEvents = Array.from({ length: 500 }, (_, index) => ({
    id: `later-${index}`,
    type: 'task_completed',
    timestamp: new Date(Date.UTC(2026, 0, 2, 0, 0, index)).toISOString(),
    taskId: `task-${index}`,
  }));
  const retainedEvents = [masteredEvent, ...laterEvents].slice(-500);
  const persistedQuizState = JSON.parse(JSON.stringify({ masteryMilestones: [masteryFact] }));

  assert.equal(retainedEvents.length, 500);
  assert.equal(retainedEvents.some((event) => event.type === 'quiz_mastered'), false,
    'the bounded StudyEvent window must demonstrate eviction of the earlier mastery event');
  assert.deepEqual(persistedQuizState.masteryMilestones, [masteryFact],
    'the durable mastery fact must survive independently of the bounded event window');

  const quizLearningState = balancedBlock(metadataModelsSource,
    'export interface QuizLearningState {');
  assert.equal(quizLearningState.includes('masteryMilestones: TopicMasteryMilestone[];'), true,
    'QuizLearningState must persist the long-lived mastery facts');

  const applyResult = balancedBlock(quizStateReducerSource,
    '  static applyResult(state: QuizLearningState, result: QuizResult): boolean {');
  const recordIndex = applyResult.indexOf('QuizLearningStateReducer.recordMasteryMilestone(state, result);');
  const compactIndex = applyResult.indexOf(
    'state.quizEvents = QuizLearningStateReducer.compactQuizEvents(state.quizEvents);');
  assert.equal(recordIndex >= 0 && compactIndex > recordIndex, true,
    'the milestone must be recorded before the bounded quiz-event list is compacted');
  assert.equal(quizStateReducerSource.includes('const QUIZ_EVENT_LIMIT: number = 500;'), true);

  const readMilestones = balancedBlock(localRepositorySource,
    '  static async getMasteryMilestones(): Promise<TopicMasteryMilestone[]> {');
  assert.equal(readMilestones.includes(
    'const state = await LocalLearningRepository.getQuizLearningState();'), true);
  assert.equal(readMilestones.includes('state.masteryMilestones'), true);
  assert.equal(readMilestones.includes('getStudyEvents()'), false,
    'the public mastery reader must not reconstruct long-lived facts from the bounded event window');

  const getAchievements = balancedBlock(localRepositorySource,
    '  static async getAchievements(): Promise<AchievementProgress[]> {');
  assert.equal(getAchievements.includes(
    'const state = await LocalLearningRepository.getQuizLearningState();'), true);
  assert.equal(getAchievements.includes('state.masteryMilestones.slice()'), true);
  assert.equal(getAchievements.includes("uniqueEvents(events, 'quiz_mastered'"), false,
    'mastery_3 must not regress to bounded StudyEvent reconstruction');

  assert.equal(achievementsSource.includes(
    "import { TopicMasteryMilestone } from '../model/LearningMetadataModels';"), true);
  assert.equal(achievementsSource.includes(
    '@State masteryMilestones: TopicMasteryMilestone[] = [];'), true);
  const topicMastered = balancedBlock(achievementsSource,
    '  private topicMastered(courseId: string, topic: string): boolean {');
  assert.equal(topicMastered.includes('this.masteryMilestones'), true);
  assert.equal(topicMastered.includes('this.studyEvents'), false);
  assert.equal(topicMastered.includes("event.type === 'quiz_mastered'"), false,
    'the next mastery action must use durable milestones rather than the evictable event window');
});

test('四个成就动作分支各自只写精确 AppStorage 并前往唯一消费页', () => {
  const openAction = balancedBlock(achievementsSource,
    '  private openNextAchievement(): void {');
  const courseContext = balancedBlock(achievementsSource,
    '  private setCourseContext(course: Course): void {');
  assert.deepEqual(appStorageWriteKeys(courseContext), ['selectedCourseId', 'selectedCourseTitle']);

  const expectedBranches = [
    {
      id: 'first_quiz',
      storageKeys: ['selectedPracticeTopic'],
      page: 'pages/Practice',
    },
    {
      id: 'active_learning_3',
      storageKeys: ['selectedContentTopic'],
      page: 'pages/Lesson',
    },
    {
      id: 'task_5',
      storageKeys: [],
      page: 'pages/Plan',
    },
    {
      id: 'mastery_3',
      storageKeys: ['selectedQuizTopic', 'selectedQuizFocusTag'],
      page: 'pages/Quiz',
    },
  ];

  for (const expected of expectedBranches) {
    const marker = `if (item.id === '${expected.id}') {`;
    const branch = balancedBlock(openAction, marker);
    assert.deepEqual(appStorageWriteKeys(branch), expected.storageKeys,
      `${expected.id} must write only its consumer's exact AppStorage keys`);
    assert.deepEqual(pushedPages(branch), [expected.page],
      `${expected.id} must navigate only to ${expected.page}`);
    assert.equal(branch.includes('return;'), true, `${expected.id} must terminate its routing branch`);
  }

  const taskBranchIndex = openAction.indexOf("if (item.id === 'task_5') {");
  const courseContextIndex = openAction.indexOf('this.setCourseContext(target.course);');
  const firstQuizIndex = openAction.indexOf("if (item.id === 'first_quiz') {");
  assert.equal(taskBranchIndex >= 0 && taskBranchIndex < courseContextIndex && courseContextIndex < firstQuizIndex,
    true, 'Plan needs no course context; all Topic actions must receive course id and title first');

  const masteryBranch = balancedBlock(openAction, "if (item.id === 'mastery_3') {");
  assert.equal(masteryBranch.includes(
    "AppStorage.setOrCreate<string>('selectedQuizFocusTag', '');"), true,
    'mastery routing must clear a stale quiz tag before opening the exact Topic');

  const practiceAppear = balancedBlock(practiceSource, '  aboutToAppear(): void {');
  for (const exactRead of [
    "this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';",
    "this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';",
    "const selectedTopic = (AppStorage.get<string>('selectedPracticeTopic') ?? '').trim();",
    "this.topic = courseTopics.includes(selectedTopic) ? selectedTopic : '';",
  ]) {
    assert.equal(practiceAppear.includes(exactRead), true, `Practice missing route input: ${exactRead}`);
  }
  const lessonAppear = balancedBlock(lessonSource, '  aboutToAppear(): void {');
  for (const exactRead of [
    "this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';",
    "this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';",
    "this.topic = AppStorage.get<string>('selectedContentTopic') ?? '';",
  ]) {
    assert.equal(lessonAppear.includes(exactRead), true, `Lesson missing route input: ${exactRead}`);
  }
  const quizAppear = balancedBlock(quizSource, '  aboutToAppear(): void {');
  for (const exactRead of [
    "this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';",
    "this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';",
    "const selectedTopic = AppStorage.get<string>('selectedQuizTopic') ?? '';",
    "const selectedFocusTag = AppStorage.get<string>('selectedQuizFocusTag') ?? '';",
  ]) {
    assert.equal(quizAppear.includes(exactRead), true, `Quiz missing route input: ${exactRead}`);
  }
});

test('两阶段加载在辅助入口失败时保留已读取的真实成就', () => {
  const loadAchievements = balancedBlock(achievementsSource,
    '  private async loadAchievements(): Promise<void> {');
  const loadActionContext = balancedBlock(achievementsSource,
    '  private async loadActionContext(): Promise<void> {');
  const achievementRead = loadAchievements.indexOf(
    'this.achievements = await LocalLearningRepository.getAchievements();');
  const actionLoad = loadAchievements.indexOf('await this.loadActionContext();');
  const skeletonRelease = loadAchievements.lastIndexOf('this.loading = false;', actionLoad);
  const courseRead = loadActionContext.indexOf(
    'const courses = await LocalLearningRepository.getCourses() ?? [];');
  const milestoneRead = loadActionContext.indexOf(
    'const masteryMilestones = await LocalLearningRepository.getMasteryMilestones();');
  const eventRead = loadActionContext.indexOf(
    'const studyEvents = await LocalLearningRepository.getStudyEvents();');
  const milestoneCommit = loadActionContext.indexOf('this.masteryMilestones = masteryMilestones;');

  assert.equal(achievementRead >= 0, true, 'the first phase must read achievements directly');
  assert.equal(achievementRead < skeletonRelease && skeletonRelease < actionLoad, true,
    'the primary achievement fact must render after releasing the skeleton and before auxiliary reads');
  assert.equal(courseRead >= 0 && milestoneRead >= 0 && eventRead >= 0, true,
    'course, milestone and activity context must stay in the auxiliary method');
  assert.equal(milestoneCommit > milestoneRead, true,
    'the durable mastery context must be committed only after it is read');

  const catchMarker = '} catch (error) {';
  const firstCatch = balancedBlockAt(loadAchievements,
    loadAchievements.indexOf(catchMarker), 'primary achievement catch');
  const secondCatch = balancedBlockAt(loadActionContext,
    loadActionContext.indexOf(catchMarker), 'auxiliary action context catch');
  assert.equal(firstCatch.includes('this.achievements = [];'), true,
    'a failed primary achievement read must expose the empty failure state');
  assert.equal(firstCatch.includes('return;'), true,
    'the auxiliary phase must not run after the primary fact read fails');
  assert.equal(secondCatch.includes('this.achievements = [];'), false,
    'an auxiliary entry failure must preserve the already rendered achievements');
  assert.equal(secondCatch.includes('this.courses = [];'), true);
  assert.equal(secondCatch.includes('this.studyEvents = [];'), true);
  assert.equal(secondCatch.includes('this.masteryMilestones = [];'), true);

  assert.equal(achievementsSource.includes(
    '} else if (this.achievements.length === 0) {'), true,
    'an auxiliary error message must not replace a non-empty achievement list');
});

test('再次读取主成就时旧辅助快照不能覆盖最新事实', () => {
  assert.equal(achievementsSource.includes('private actionLoadSequence: number = 0;'), true,
    'the page needs a monotonic owner for auxiliary snapshots');
  const loadAchievements = balancedBlock(achievementsSource,
    '  private async loadAchievements(): Promise<void> {');
  const invalidateOldAction = loadAchievements.indexOf('this.actionLoadSequence += 1;');
  const achievementRead = loadAchievements.indexOf(
    'this.achievements = await LocalLearningRepository.getAchievements();');
  assert.equal(invalidateOldAction >= 0 && invalidateOldAction < achievementRead, true,
    'a new primary read must invalidate the previous auxiliary request before awaiting ArkData');

  const loadActionContext = balancedBlock(achievementsSource,
    '  private async loadActionContext(): Promise<void> {');
  assert.equal(loadActionContext.includes('if (this.actionLoading) return;'), false,
    'a new primary snapshot must be able to start fresh auxiliary reads while the old request settles');
  const requestStart = loadActionContext.indexOf(
    'const requestSequence = ++this.actionLoadSequence;');
  const finalRead = loadActionContext.indexOf(
    'const masteryMilestones = await LocalLearningRepository.getMasteryMilestones();');
  const staleSuccessGuard = loadActionContext.indexOf(
    'if (requestSequence !== this.actionLoadSequence) return;', finalRead);
  const firstCommit = loadActionContext.indexOf('this.courses = courses;');
  assert.equal(requestStart >= 0 && finalRead > requestStart &&
    staleSuccessGuard > finalRead && firstCommit > staleSuccessGuard, true,
  'only the newest auxiliary request may commit courses, events and mastery milestones');

  const catchIndex = loadActionContext.indexOf('} catch (error) {');
  const staleFailureGuard = loadActionContext.indexOf(
    'if (requestSequence !== this.actionLoadSequence) return;', catchIndex);
  const failureClear = loadActionContext.indexOf('this.courses = [];', catchIndex);
  assert.equal(staleFailureGuard > catchIndex && failureClear > staleFailureGuard, true,
    'a stale auxiliary failure must not clear the latest action context');
  assert.equal(loadActionContext.includes(
    'if (requestSequence === this.actionLoadSequence) this.actionLoading = false;'), true,
  'a stale request must not end the loading state owned by a newer auxiliary read');
});
