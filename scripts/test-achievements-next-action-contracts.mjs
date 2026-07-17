import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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
  experiences: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json'),
  quizzes: path.join(repositoryRoot,
    'apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json'),
};

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

function topicKey(courseId, topic) {
  return `${courseId}\u0000${topic}`;
}

function completionRatio(item) {
  return Math.min(Math.max(item.current / Math.max(item.target, 1), 0), 1);
}

function remainingCount(item) {
  return Math.max(item.target - item.current, 0);
}

function selectNextAchievement(definitions, currentById) {
  let next = null;
  for (const definition of definitions) {
    const item = { ...definition, current: currentById[definition.id] ?? 0 };
    if (item.current >= item.target) continue;
    if (next === null) {
      next = item;
      continue;
    }
    const remainingDelta = remainingCount(item) - remainingCount(next);
    const ratioDelta = completionRatio(item) - completionRatio(next);
    if (remainingDelta < 0 || (remainingDelta === 0 && ratioDelta > 0.001)) next = item;
  }
  return next?.id ?? null;
}

function questionsByTopic(quizzes) {
  const result = new Map();
  for (const question of quizzes) {
    const key = topicKey(question.courseId, question.topic);
    const bucket = result.get(key) ?? [];
    bucket.push(question);
    result.set(key, bucket);
  }
  return result;
}

function firstPracticeTarget(topics, questionIndex) {
  return topics.find((item) => (questionIndex.get(topicKey(item.courseId, item.topic))?.length ?? 0) > 0) ?? null;
}

function firstActivityTarget(experiences, completedActivityIds) {
  for (const experience of experiences) {
    const activityId = experience.activities[0]?.id ?? '';
    if (activityId.length > 0 && !completedActivityIds.has(activityId)) {
      return { courseId: experience.courseId, topic: experience.topic, activityId };
    }
  }
  return null;
}

function firstMasteryTarget(topics, masteredTopicKeys, questionIndex) {
  for (const item of topics) {
    const key = topicKey(item.courseId, item.topic);
    if (!masteredTopicKeys.has(key) && (questionIndex.get(key)?.length ?? 0) > 0) return item;
  }
  return null;
}

const achievementsSource = readSource(paths.achievements);
const localRepositorySource = readSource(paths.localRepository);
const experiences = JSON.parse(readSource(paths.experiences));
const quizzes = JSON.parse(readSource(paths.quizzes));

test('成就页完整读取 ArkData 行动上下文后一次提交快照且失败可恢复', () => {
  const load = sourceSection(achievementsSource,
    '  private async loadAchievements(): Promise<void> {', '\n  private isUnlocked(');
  const achievementsRead = load.indexOf('const achievements = await LocalLearningRepository.getAchievements();');
  const coursesRead = load.indexOf('const courses = await LocalLearningRepository.getCourses() ?? [];');
  const eventsRead = load.indexOf('const studyEvents = await LocalLearningRepository.getStudyEvents();');
  const achievementsCommit = load.indexOf('this.achievements = achievements;');
  const coursesCommit = load.indexOf('this.courses = courses;');
  const eventsCommit = load.indexOf('this.studyEvents = studyEvents;');

  assert.equal(load.includes('if (this.loading) return;'), true,
    'repeated recovery taps must not overlap ArkData reads');
  assert.equal(achievementsRead >= 0 && achievementsRead < coursesRead && coursesRead < eventsRead, true,
    'the three exact local sources must all be read');
  assert.equal(eventsRead < achievementsCommit && achievementsCommit < coursesCommit && coursesCommit < eventsCommit, true,
    'no visible state may be committed before all local sources succeed');
  for (const reset of ['this.achievements = [];', 'this.courses = [];', 'this.studyEvents = [];',
    "this.message = '成就进度与学习入口读取失败，请重新读取';"]) {
    assert.equal(load.includes(reset), true, `failed load missing reset: ${reset}`);
  }
  assert.equal(achievementsSource.includes("Button('重新读取成就进度')"), true,
    'the empty failure state needs an explicit recovery action');
  assert.equal(achievementsSource.includes("Button('重新读取真实进度')"), true,
    'an inline action or navigation failure needs an explicit recovery action');
});

test('下一目标选择剩余动作最少并使用完成比例稳定处理并列', () => {
  const definitions = [
    { id: 'first_quiz', target: 1 },
    { id: 'active_learning_3', target: 3 },
    { id: 'task_5', target: 5 },
    { id: 'mastery_3', target: 3 },
  ];
  const repositoryAchievements = sourceSection(localRepositorySource,
    '  static async getAchievements(): Promise<AchievementProgress[]> {',
    '\n  private static uniqueEvents(');
  for (const expected of [
    "achievement('first_quiz', '初次练习', '完成第一次练习', results.length, 1,",
    "achievement('active_learning_3', '主动学习', '完成 3 个课程互动练习',",
    "achievement('task_5', '稳步前进', '完成 5 项学习任务', completedTasks.length, 5,",
    "achievement('mastery_3', '掌握新知', '掌握 3 个知识点', masteredTopics.length, 3,",
  ]) {
    assert.equal(repositoryAchievements.includes(expected), true, `achievement definition changed: ${expected}`);
  }

  const truthTable = [
    [{}, 'first_quiz'],
    [{ first_quiz: 1, active_learning_3: 2 }, 'active_learning_3'],
    [{ first_quiz: 1, task_5: 4 }, 'task_5'],
    [{ first_quiz: 1, mastery_3: 2 }, 'mastery_3'],
    [{ first_quiz: 1, active_learning_3: 2, task_5: 4, mastery_3: 2 }, 'task_5'],
    [{ first_quiz: 1, active_learning_3: 3, task_5: 5, mastery_3: 3 }, null],
  ];
  for (const [currentById, expected] of truthTable) {
    assert.equal(selectNextAchievement(definitions, currentById), expected);
  }

  const selection = sourceSection(achievementsSource,
    '  private nextAchievement(): AchievementProgress | null {', '\n  private activeCourse(');
  assert.equal(selection.includes('this.remainingCount(item) - this.remainingCount(next)'), true);
  assert.equal(selection.includes('this.completionRatio(item) - this.completionRatio(next)'), true);
  assert.equal(selection.includes('remainingDelta < 0 || (remainingDelta === 0 && ratioDelta > 0.001)'), true);
});

test('真实课程资产为练习、未计数互动和未掌握 Topic 提供可执行目标', () => {
  assert.equal(experiences.length, 33, 'lesson experiences must cover the real 33 Topics');
  const topics = experiences.map((item) => ({ courseId: item.courseId, topic: item.topic }));
  const keys = topics.map((item) => topicKey(item.courseId, item.topic));
  assert.equal(new Set(keys).size, 33, 'course/Topic pairs must be unique');
  const questionIndex = questionsByTopic(quizzes);
  assert.equal(questionIndex.size, 33, 'question assets must cover the real 33 Topics');
  for (const key of keys) {
    assert.equal((questionIndex.get(key)?.length ?? 0) >= 5, true, `missing executable questions for ${key}`);
  }
  assert.notEqual(firstPracticeTarget(topics, questionIndex), null);

  const allActivityIds = experiences.flatMap((item) => item.activities.map((activity) => activity.id));
  assert.equal(allActivityIds.length, 59, 'lesson assets must expose the real 59 activities');
  assert.equal(new Set(allActivityIds).size, 59, 'all activity ids must be globally unique');
  const firstActivityIds = experiences.map((item) => item.activities[0]?.id ?? '');
  assert.equal(firstActivityIds.every((id) => id.length > 0), true, 'every Topic needs a first activity');
  assert.equal(new Set(firstActivityIds).size, 33, 'first activity ids must be unique by Topic');
  assert.notEqual(firstActivityTarget(experiences, new Set()), null,
    'an empty activity history must expose a first action');
  for (let first = 0; first < allActivityIds.length; first += 1) {
    for (let second = first; second < allActivityIds.length; second += 1) {
      const completed = new Set();
      completed.add(allActivityIds[first]);
      completed.add(allActivityIds[second]);
      const target = firstActivityTarget(experiences, completed);
      assert.notEqual(target, null, 'a locked three-activity milestone must have an uncounted activity');
      assert.equal(completed.has(target.activityId), false);
    }
  }

  for (const remainingKey of keys) {
    const mastered = new Set(keys.filter((key) => key !== remainingKey));
    const target = firstMasteryTarget(topics, mastered, questionIndex);
    assert.notEqual(target, null);
    assert.equal(topicKey(target.courseId, target.topic), remainingKey);
  }
  assert.equal(firstMasteryTarget(topics, new Set(keys), questionIndex), null);

  const practice = sourceSection(achievementsSource,
    '  private practiceTarget(): AchievementActionTarget | null {', '\n  private activityCompleted(');
  const activity = sourceSection(achievementsSource,
    '  private activityTarget(): AchievementActionTarget | null {', '\n  private topicMastered(');
  const mastery = sourceSection(achievementsSource,
    '  private masteryTarget(): AchievementActionTarget | null {', '\n  private actionTarget(');
  assert.equal(practice.includes('LearningContentRepository.getQuestions(course.id, topic).length > 0'), true);
  assert.equal(activity.includes('LearningContentRepository.getLessonExperience(course.id, topic)'), true);
  assert.equal(activity.includes('!this.activityCompleted(activityId)'), true);
  assert.equal(mastery.includes('!this.topicMastered(course.id, topic)'), true);
  assert.equal(mastery.includes('LearningContentRepository.getQuestions(course.id, topic).length > 0'), true);
});

test('四类里程碑保持精确路由字段、48vp 恢复与完整读屏语义', () => {
  const openAction = sourceSection(achievementsSource,
    '  private openNextAchievement(): void {', '\n  build() {');
  for (const contract of [
    ["item.id === 'first_quiz'", "selectedPracticeTopic", "pages/Practice"],
    ["item.id === 'active_learning_3'", "selectedContentTopic", "pages/Lesson"],
    ["item.id === 'task_5'", '', "pages/Plan"],
    ["item.id === 'mastery_3'", "selectedQuizTopic", "pages/Quiz"],
  ]) {
    assert.equal(openAction.includes(contract[0]), true);
    if (contract[1].length > 0) assert.equal(openAction.includes(`'${contract[1]}'`), true);
    assert.equal(openAction.includes(`'${contract[2]}'`), true);
  }
  assert.equal(openAction.includes("AppStorage.setOrCreate<string>('selectedQuizFocusTag', '')"), true,
    'mastery action must clear a stale tag filter');
  assert.equal(achievementsSource.includes('.accessibilityText(this.nextActionAccessibilityText())'), true);
  assert.equal(achievementsSource.includes('.accessibilityText(this.achievementAccessibilityText(item))'), true);
  assert.equal(achievementsSource.includes('Flex({ wrap: FlexWrap.Wrap'), true,
    'achievement headings must wrap for narrow or enlarged-text layouts');
  const minimumTargets = achievementsSource.match(/\.constraintSize\(\{ minHeight: 48 \}\)/g) ?? [];
  assert.equal(minimumTargets.length >= 3, true,
    'primary and both recovery actions need 48vp minimum targets');
});
