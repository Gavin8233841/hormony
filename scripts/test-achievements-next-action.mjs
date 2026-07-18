#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const paths = {
  achievements: resolve(root, 'apps/harmonyos/entry/src/main/ets/pages/Achievements.ets'),
  localRepository: resolve(root, 'apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets'),
  contentRepository: resolve(root, 'apps/harmonyos/entry/src/main/ets/common/LearningContentRepository.ets'),
  experiences: resolve(
    root,
    'apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json'
  ),
  quizzes: resolve(root, 'apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json'),
};

function invariant(condition, message) {
  if (!condition) throw new Error(message);
}

function equal(actual, expected, message) {
  invariant(Object.is(actual, expected), `${message}: expected ${String(expected)}, received ${String(actual)}`);
}

function deepEqual(actual, expected, message) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  invariant(actualJson === expectedJson, `${message}: expected ${expectedJson}, received ${actualJson}`);
}

function readJsonArray(path, label) {
  const value = JSON.parse(readFileSync(path, 'utf8'));
  invariant(Array.isArray(value), `${label} must be a JSON array`);
  return value;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function extractDelimited(source, openIndex, openCharacter, closeCharacter) {
  invariant(source[openIndex] === openCharacter, `missing opening ${openCharacter} at offset ${openIndex}`);
  let depth = 0;
  let quote = '';
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = openIndex; index < source.length; index += 1) {
    const character = source[index];
    const next = source[index + 1] ?? '';

    if (lineComment) {
      if (character === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (character === '*' && next === '/') {
        blockComment = false;
        index += 1;
      }
      continue;
    }
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
    if (character === '/' && next === '/') {
      lineComment = true;
      index += 1;
      continue;
    }
    if (character === '/' && next === '*') {
      blockComment = true;
      index += 1;
      continue;
    }
    if (character === "'" || character === '"' || character === '`') {
      quote = character;
      continue;
    }
    if (character === openCharacter) depth += 1;
    if (character === closeCharacter) {
      depth -= 1;
      if (depth === 0) {
        return { body: source.slice(openIndex + 1, index), endIndex: index };
      }
    }
  }
  throw new Error(`unclosed ${openCharacter} at offset ${openIndex}`);
}

function extractMethodBody(source, methodName) {
  const pattern = new RegExp(
    `^\\s*(?:(?:private|public|protected|static|async)\\s+)*${escapeRegExp(methodName)}\\s*\\(`,
    'm'
  );
  const match = pattern.exec(source);
  invariant(match !== null, `method ${methodName} was not found`);
  const openIndex = source.indexOf('{', match.index + match[0].length);
  invariant(openIndex >= 0, `method ${methodName} has no body`);
  return extractDelimited(source, openIndex, '{', '}').body;
}

function extractAchievementBranch(methodBody, achievementId) {
  const pattern = new RegExp(
    `\\bif\\s*\\(\\s*item\\.id\\s*===\\s*['"]${escapeRegExp(achievementId)}['"]\\s*\\)\\s*\\{`
  );
  const match = pattern.exec(methodBody);
  invariant(match !== null, `branch for ${achievementId} was not found`);
  const openIndex = methodBody.indexOf('{', match.index);
  return extractDelimited(methodBody, openIndex, '{', '}').body;
}

function splitTopLevelArguments(source) {
  const result = [];
  let start = 0;
  let roundDepth = 0;
  let squareDepth = 0;
  let curlyDepth = 0;
  let quote = '';
  let escaped = false;

  for (let index = 0; index < source.length; index += 1) {
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
    if (character === '(') roundDepth += 1;
    else if (character === ')') roundDepth -= 1;
    else if (character === '[') squareDepth += 1;
    else if (character === ']') squareDepth -= 1;
    else if (character === '{') curlyDepth += 1;
    else if (character === '}') curlyDepth -= 1;
    else if (character === ',' && roundDepth === 0 && squareDepth === 0 && curlyDepth === 0) {
      result.push(source.slice(start, index).trim());
      start = index + 1;
    }
  }
  result.push(source.slice(start).trim());
  return result;
}

function achievementDefinitions(localRepositorySource) {
  const body = extractMethodBody(localRepositorySource, 'getAchievements');
  const needle = 'LocalLearningRepository.achievement';
  const definitions = [];
  let offset = 0;

  while (offset < body.length) {
    const callIndex = body.indexOf(needle, offset);
    if (callIndex < 0) break;
    const openIndex = body.indexOf('(', callIndex + needle.length);
    invariant(openIndex >= 0, 'achievement call has no opening parenthesis');
    const call = extractDelimited(body, openIndex, '(', ')');
    const args = splitTopLevelArguments(call.body);
    invariant(args.length >= 5, 'achievement call must provide id, labels, current, and target');
    const idMatch = args[0].match(/^(['"])([^'"]+)\1$/);
    invariant(idMatch !== null, `achievement id must be a string literal: ${args[0]}`);
    invariant(/^\d+$/.test(args[4]), `achievement target must be an integer literal for ${idMatch[2]}`);
    definitions.push({ id: idMatch[2], target: Number(args[4]) });
    offset = call.endIndex + 1;
  }
  return definitions;
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

function topicKey(courseId, topic) {
  return `${courseId}\u0000${topic}`;
}

function questionBuckets(quizzes) {
  const buckets = new Map();
  for (const question of quizzes) {
    invariant(typeof question.courseId === 'string' && question.courseId.length > 0,
      'quiz question must have a courseId');
    invariant(typeof question.topic === 'string' && question.topic.length > 0,
      'quiz question must have a topic');
    const key = topicKey(question.courseId, question.topic);
    const previous = buckets.get(key) ?? [];
    previous.push(question);
    buckets.set(key, previous);
  }
  return buckets;
}

function findQuestionTarget(orderedTopics, questionsByTopic, excludedTopics = new Set()) {
  for (const item of orderedTopics) {
    const key = topicKey(item.courseId, item.topic);
    if (!excludedTopics.has(key) && (questionsByTopic.get(key)?.length ?? 0) > 0) return item;
  }
  return null;
}

function completedActivityIds(events) {
  return new Set(events
    .filter((event) => event.type === 'lesson_activity' && typeof event.taskId === 'string')
    .map((event) => event.taskId));
}

function findIncompleteFirstActivity(experiences, events) {
  const completed = completedActivityIds(events);
  for (const experience of experiences) {
    const activity = experience.activities[0];
    if (activity !== undefined && !completed.has(activity.id)) {
      return { courseId: experience.courseId, topic: experience.topic, activityId: activity.id };
    }
  }
  return null;
}

function activityEvent(activityId) {
  return { type: 'lesson_activity', taskId: activityId };
}

function hasAppStorageSet(source, key) {
  const pattern = new RegExp(
    `AppStorage\\.setOrCreate\\s*(?:<[^>]+>)?\\s*\\(\\s*['"]${escapeRegExp(key)}['"]`
  );
  return pattern.test(source);
}

function hasRoute(source, route) {
  const pattern = new RegExp(`this\\.pushPage\\s*\\(\\s*['"]${escapeRegExp(route)}['"]`);
  return pattern.test(source);
}

const achievementsSource = readFileSync(paths.achievements, 'utf8');
const localRepositorySource = readFileSync(paths.localRepository, 'utf8');
const contentRepositorySource = readFileSync(paths.contentRepository, 'utf8');
const experiences = readJsonArray(paths.experiences, 'lesson-experiences.json');
const quizzes = readJsonArray(paths.quizzes, 'quizzes.json');

const checks = [];
let failures = 0;

function check(name, test) {
  try {
    test();
    checks.push({ name, passed: true });
    console.log(`[PASS] ${name}`);
  } catch (error) {
    failures += 1;
    checks.push({ name, passed: false });
    console.error(`[FAIL] ${name}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

check('achievement definitions and minimum-action ordering truth table', () => {
  const definitions = achievementDefinitions(localRepositorySource);
  deepEqual(definitions, [
    { id: 'first_quiz', target: 1 },
    { id: 'active_learning_3', target: 3 },
    { id: 'task_5', target: 5 },
    { id: 'mastery_3', target: 3 },
  ], 'achievement ids, order, and targets changed');

  const truthTable = [
    ['empty history selects the one-action milestone', {}, 'first_quiz'],
    ['activity milestone is one action away', { first_quiz: 1, active_learning_3: 2 }, 'active_learning_3'],
    ['plan milestone is one action away', { first_quiz: 1, task_5: 4 }, 'task_5'],
    ['mastery milestone is one action away', { first_quiz: 1, mastery_3: 2 }, 'mastery_3'],
    [
      'equal remaining actions use the higher completion ratio',
      { first_quiz: 1, active_learning_3: 2, task_5: 4, mastery_3: 2 },
      'task_5',
    ],
    [
      'equal remaining actions and ratios preserve repository order',
      { first_quiz: 1, active_learning_3: 2, task_5: 0, mastery_3: 2 },
      'active_learning_3',
    ],
    [
      'unlocked milestones are skipped',
      { first_quiz: 1, active_learning_3: 3, task_5: 5, mastery_3: 2 },
      'mastery_3',
    ],
    [
      'all milestones unlocked has no next action',
      { first_quiz: 1, active_learning_3: 3, task_5: 5, mastery_3: 3 },
      null,
    ],
  ];
  const selectedIds = new Set();
  for (const [label, currentById, expected] of truthTable) {
    const actual = selectNextAchievement(definitions, currentById);
    equal(actual, expected, label);
    if (actual !== null) selectedIds.add(actual);
  }
  deepEqual([...selectedIds].sort(), definitions.map((item) => item.id).sort(),
    'truth table must exercise every achievement id');

  const nextBody = extractMethodBody(achievementsSource, 'nextAchievement');
  const remainingBody = extractMethodBody(achievementsSource, 'remainingCount');
  invariant(/this\.isUnlocked\s*\(\s*item\s*\)/.test(nextBody),
    'nextAchievement must skip unlocked milestones');
  invariant(/this\.remainingCount\s*\(\s*item\s*\)/.test(nextBody) &&
    /this\.remainingCount\s*\(\s*next\s*\)/.test(nextBody),
  'nextAchievement must compare remaining action counts');
  invariant(/remainingDelta\s*<\s*0/.test(nextBody),
    'nextAchievement must prioritize fewer remaining actions');
  invariant(/remainingDelta\s*===\s*0\s*&&\s*ratioDelta\s*>\s*0(?:\.\d+)?/.test(nextBody),
    'nextAchievement must apply the completion-ratio tie break');
  invariant(/Math\.max\s*\(\s*item\.target\s*-\s*item\.current\s*,\s*0\s*\)/.test(remainingBody),
    'remainingCount must clamp target minus current at zero');
});

check('all catalog topics provide practice questions and an unmastered quiz target', () => {
  const orderedTopics = experiences.map((item) => {
    invariant(typeof item.courseId === 'string' && item.courseId.length > 0,
      'lesson experience must have a courseId');
    invariant(typeof item.topic === 'string' && item.topic.length > 0,
      'lesson experience must have a topic');
    return { courseId: item.courseId, topic: item.topic };
  });
  const experienceKeys = orderedTopics.map((item) => topicKey(item.courseId, item.topic));
  equal(new Set(experienceKeys).size, experiences.length,
    'lesson experience course/topic pairs must be unique');

  const questionsByTopic = questionBuckets(quizzes);
  equal(questionsByTopic.size, experiences.length, 'quiz course/topic coverage');
  for (const key of experienceKeys) {
    invariant(questionsByTopic.has(key), `missing quiz questions for ${key.replace('\u0000', '/')}`);
    invariant((questionsByTopic.get(key)?.length ?? 0) >= 5,
      `fewer than five quiz questions for ${key.replace('\u0000', '/')}`);
  }
  for (const key of questionsByTopic.keys()) {
    invariant(experienceKeys.includes(key), `quiz questions reference an unknown lesson topic ${key.replace('\u0000', '/')}`);
  }

  const firstPractice = findQuestionTarget(orderedTopics, questionsByTopic);
  invariant(firstPractice !== null, 'no topic can start the first practice');
  deepEqual(firstPractice, orderedTopics[0], 'first practice must resolve to the first populated topic');

  const finalTopic = orderedTopics[orderedTopics.length - 1];
  const masteredExceptFinal = new Set(experienceKeys.slice(0, -1));
  deepEqual(findQuestionTarget(orderedTopics, questionsByTopic, masteredExceptFinal), finalTopic,
    'mastery continuation must select the remaining unmastered topic');
  equal(findQuestionTarget(orderedTopics, questionsByTopic, new Set(experienceKeys)), null,
    'all mastered topics must have no mastery target');

  const practiceBody = extractMethodBody(achievementsSource, 'practiceTarget');
  const masteryBody = extractMethodBody(achievementsSource, 'masteryTarget');
  const topicMasteredBody = extractMethodBody(achievementsSource, 'topicMastered');
  invariant(/LearningContentRepository\.getQuestions\s*\(\s*course\.id\s*,\s*topic\s*\)\.length\s*>\s*0/.test(practiceBody),
    'practiceTarget must require questions for its course/topic');
  invariant(/!\s*this\.topicMastered\s*\(\s*course\.id\s*,\s*topic\s*\)/.test(masteryBody),
    'masteryTarget must skip mastered course/topic pairs');
  invariant(/event\.type\s*===\s*['"]quiz_mastered['"]/.test(topicMasteredBody) &&
    /event\.courseId\s*===\s*courseId/.test(topicMasteredBody) &&
    /event\.topic\s*===\s*topic/.test(topicMasteredBody),
  'topicMastered must use quiz_mastered with the exact course/topic pair');

  const getQuestionsBody = extractMethodBody(contentRepositorySource, 'getQuestions');
  invariant(/questionsByTopic/.test(getQuestionsBody) && /courseId/.test(getQuestionsBody) && /topic/.test(getQuestionsBody),
    'LearningContentRepository.getQuestions must use the course/topic index');
});

check('unique activity ids preserve a growth target while active_learning_3 is locked', () => {
  const flattened = [];
  const firstActivities = [];
  for (const experience of experiences) {
    invariant(Array.isArray(experience.activities) && experience.activities.length > 0,
      `${experience.courseId}/${experience.topic} has no learning activity`);
    for (const activity of experience.activities) {
      invariant(typeof activity.id === 'string' && activity.id.length > 0,
        `${experience.courseId}/${experience.topic} has an activity without an id`);
      flattened.push({
        courseId: experience.courseId,
        topic: experience.topic,
        activityId: activity.id,
      });
    }
    firstActivities.push({
      courseId: experience.courseId,
      topic: experience.topic,
      activityId: experience.activities[0].id,
    });
  }
  invariant(flattened.length >= experiences.length,
    'every lesson experience must expose at least one learning activity');
  equal(new Set(flattened.map((item) => item.activityId)).size, flattened.length,
    'learning activity ids must be unique');
  equal(firstActivities.length, experiences.length, 'first activity count');
  equal(new Set(firstActivities.map((item) => item.activityId)).size, experiences.length,
    'each topic must expose a unique first activity id');

  deepEqual(findIncompleteFirstActivity(experiences, []), firstActivities[0],
    'empty activity history must select the first topic activity');
  deepEqual(findIncompleteFirstActivity(experiences, [
    { type: 'quiz_mastered', taskId: flattened[0].activityId },
    { type: 'lesson_activity', taskId: 'unknown-activity-id' },
  ]), firstActivities[0], 'non-lesson and unknown task ids must not hide the first topic activity');

  let lockedHistories = 0;
  const verifyLockedHistory = (completedIds, label) => {
    invariant(new Set(completedIds).size < 3, `${label} is outside the locked milestone range`);
    const events = completedIds.map(activityEvent);
    const target = findIncompleteFirstActivity(experiences, events);
    invariant(target !== null, `${label} has no next first-activity target`);
    invariant(!completedActivityIds(events).has(target.activityId),
      `${label} selected an already-counted taskId`);
    lockedHistories += 1;
  };

  verifyLockedHistory([], 'zero completed activities');
  for (let first = 0; first < flattened.length; first += 1) {
    verifyLockedHistory([flattened[first].activityId], `one completed activity at index ${first}`);
    for (let second = first + 1; second < flattened.length; second += 1) {
      verifyLockedHistory(
        [flattened[first].activityId, flattened[second].activityId],
        `two completed activities at indexes ${first}/${second}`
      );
    }
  }
  equal(lockedHistories, 1 + flattened.length + (flattened.length * (flattened.length - 1)) / 2,
    'exhaustive locked-history count');

  const duplicateEvents = [
    activityEvent(firstActivities[0].activityId),
    activityEvent(firstActivities[0].activityId),
  ];
  deepEqual(findIncompleteFirstActivity(experiences, duplicateEvents), firstActivities[1],
    'duplicate taskId events must still advance to an uncounted first activity');

  const activityCompletedBody = extractMethodBody(achievementsSource, 'activityCompleted');
  const activityTargetBody = extractMethodBody(achievementsSource, 'activityTarget');
  invariant(/event\.type\s*===\s*['"]lesson_activity['"]/.test(activityCompletedBody) &&
    /event\.taskId\s*===\s*activityId/.test(activityCompletedBody),
  'activityCompleted must match lesson_activity by taskId');
  invariant(/\.activities\s*\[\s*0\s*\]\s*\?\.\s*id/.test(activityTargetBody),
    'activityTarget must use each topic first activity id');
  invariant(/!\s*this\.activityCompleted\s*\(/.test(activityTargetBody),
    'activityTarget must reject an already-counted first activity taskId');

  const achievementsBody = extractMethodBody(localRepositorySource, 'getAchievements');
  const uniqueEventsBody = extractMethodBody(localRepositorySource, 'uniqueEvents');
  invariant(/uniqueEvents\s*\(\s*events\s*,\s*['"]lesson_activity['"]\s*,\s*true\s*\)/.test(achievementsBody),
    'active_learning_3 must count lesson_activity events by task');
  invariant(/byTask\s*\?\s*\(\s*event\.taskId\s*\?\?\s*event\.id\s*\)/.test(uniqueEventsBody),
    'by-task achievement counting must use taskId with event id fallback');

  const getExperienceBody = extractMethodBody(contentRepositorySource, 'getLessonExperience');
  invariant(/entry\.courseId\s*===\s*courseId/.test(getExperienceBody) &&
    /entry\.topic\s*===\s*topic/.test(getExperienceBody),
  'getLessonExperience must use the exact course/topic pair');
});

check('four achievement routes preserve exact AppStorage contracts', () => {
  const openBody = extractMethodBody(achievementsSource, 'openNextAchievement');
  const courseContextBody = extractMethodBody(achievementsSource, 'setCourseContext');
  invariant(hasAppStorageSet(courseContextBody, 'selectedCourseId'),
    'setCourseContext must write selectedCourseId');
  invariant(hasAppStorageSet(courseContextBody, 'selectedCourseTitle'),
    'setCourseContext must write selectedCourseTitle');
  invariant(/this\.setCourseContext\s*\(\s*target\.course\s*\)/.test(openBody),
    'topic routes must prepare their shared course context');

  const expectedRoutes = [
    { id: 'first_quiz', route: 'pages/Practice', keys: ['selectedPracticeTopic'] },
    { id: 'active_learning_3', route: 'pages/Lesson', keys: ['selectedContentTopic'] },
    { id: 'task_5', route: 'pages/Plan', keys: [] },
    { id: 'mastery_3', route: 'pages/Quiz', keys: ['selectedQuizTopic', 'selectedQuizFocusTag'] },
  ];
  for (const expected of expectedRoutes) {
    const branch = extractAchievementBranch(openBody, expected.id);
    invariant(hasRoute(branch, expected.route), `${expected.id} must route to ${expected.route}`);
    for (const key of expected.keys) {
      invariant(hasAppStorageSet(branch, key), `${expected.id} must write ${key}`);
    }
  }

  const masteryBranch = extractAchievementBranch(openBody, 'mastery_3');
  invariant(!hasAppStorageSet(masteryBranch, 'selectedContentTopic'),
    'mastery_3 must not overwrite selectedContentTopic with an already-mastered topic');
});

const passed = checks.length - failures;
console.log(`[SUMMARY] ${passed}/${checks.length} achievement next-action checks passed`);
if (failures > 0) process.exitCode = 1;
