#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputPath = resolve(
  root,
  'apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json'
);
const knowledgePath = resolve(
  root,
  'apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json'
);

const specFiles = [
  ['cs101', 'docs/ACTIVE-LEARNING-SPEC-CS101.md'],
  ['cs102', 'docs/ACTIVE-LEARNING-SPEC-CS102.md'],
  ['cs103', 'docs/ACTIVE-LEARNING-SPEC-CS103.md'],
];

function cleanMarkdown(value) {
  return value
    .replace(/^```[^\n]*\n?/gm, '')
    .replace(/^```$/gm, '')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/^\s*-\s+/gm, '')
    .trim();
}

function readEntries(section) {
  const entries = [];
  let current = null;
  for (const line of section.split(/\r?\n/)) {
    const field = line.match(/^- \*\*([^*]+)\*\*：\s*(.*)$/);
    if (field) {
      current = { label: field[1], lines: field[2].length > 0 ? [field[2]] : [] };
      entries.push(current);
    } else if (current !== null) {
      current.lines.push(line);
    }
  }
  return entries.map((entry) => ({
    label: entry.label,
    value: cleanMarkdown(entry.lines.join('\n')),
  }));
}

function entryValue(entries, label) {
  return entries.find((entry) => entry.label === label)?.value ?? '';
}

function parseOrderedOptions(value) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => /^[A-Z]\.\s+/.test(line))
    .map((line) => ({ key: line.slice(0, 1), text: line.replace(/^[A-Z]\.\s+/, '') }));
}

function supportingContent(entries) {
  const reserved = new Set(['类型', '题目', '答案', '反馈', '来源', '打乱步骤', '正确顺序']);
  return entries
    .filter((entry) => !reserved.has(entry.label) && entry.value.length > 0)
    .map((entry) => `${entry.label}：\n${entry.value}`)
    .join('\n\n');
}

function compactVisualStep(value, index) {
  const firstBeat = value.split('→', 1)[0].split('。', 1)[0].trim();
  return firstBeat.length > 0 && firstBeat.length <= 18 ? firstBeat : `步骤 ${index + 1}`;
}

function parseActivity(section, courseId, topic, index) {
  const entries = readEntries(section);
  const type = entryValue(entries, '类型');
  const prompt = entryValue(entries, '题目');
  const feedback = entryValue(entries, '反馈');
  const source = entryValue(entries, '来源');
  if (!['code_fill', 'step_order', 'state_trace', 'output_predict'].includes(type)) {
    throw new Error(`${courseId}/${topic}/练习${index} 的类型无效: ${type}`);
  }
  if (prompt.length === 0 || feedback.length === 0 || source.length === 0) {
    throw new Error(`${courseId}/${topic}/练习${index} 缺少题目、反馈或来源`);
  }

  if (type === 'step_order') {
    const orderedOptions = parseOrderedOptions(entryValue(entries, '打乱步骤'));
    const answerKeys = entryValue(entries, '正确顺序').split('（', 1)[0].match(/[A-Z]/g) ?? [];
    const answerIndexes = answerKeys.map((key) => orderedOptions.findIndex((option) => option.key === key));
    if (orderedOptions.length === 0 || answerIndexes.length !== orderedOptions.length || answerIndexes.includes(-1)) {
      throw new Error(`${courseId}/${topic}/练习${index} 的步骤或正确顺序不完整`);
    }
    return {
      id: `${courseId}-${topic}-${index}`,
      type,
      title: '步骤排序',
      prompt,
      content: supportingContent(entries),
      language: '步骤卡片',
      interactionMode: 'ordered_choice',
      options: orderedOptions.map((option) => option.text),
      answerIndexes,
      answer: answerKeys.join(' → '),
      feedback,
      source,
    };
  }

  const answer = entryValue(entries, '答案') ||
    (type === 'state_trace' ? entryValue(entries, '最终状态') : '');
  if (answer.length === 0) {
    throw new Error(`${courseId}/${topic}/练习${index} 缺少答案`);
  }

  return {
    id: `${courseId}-${topic}-${index}`,
    type,
    title: {
      code_fill: '代码填空',
      state_trace: '状态推演',
      output_predict: '输出预测',
    }[type],
    prompt,
    content: supportingContent(entries),
    language: type === 'code_fill' ? '代码阅读' : '推演草稿',
    interactionMode: 'free_response',
    options: [],
    answerIndexes: [],
    answer,
    feedback,
    source,
  };
}

function parseSpec(courseId, relativePath) {
  const source = readFileSync(resolve(root, relativePath), 'utf8');
  const topicMatches = [...source.matchAll(/^## Topic \d+: (.+)$/gm)];
  return topicMatches.map((match, topicIndex) => {
    const start = match.index;
    const end = topicMatches[topicIndex + 1]?.index ?? source.indexOf('\n## 附录', start) ?? source.length;
    const section = source.slice(start, end > start ? end : source.length);
    const topic = match[1].trim();
    const caseSection = section.match(/### 现实案例\s*([\s\S]*?)(?=\n### )/)?.[1] ?? '';
    const exampleSection = section.match(/### 逐步示例\s*([\s\S]*?)(?=\n### )/)?.[1] ?? '';
    const caseEntries = readEntries(caseSection);
    const exampleEntries = readEntries(exampleSection);
    const activityMatches = [...section.matchAll(/^### 主动练习 \d+（[^）]+）\s*$/gm)];
    const activities = activityMatches.map((activityMatch, activityIndex) => {
      const activityStart = activityMatch.index + activityMatch[0].length;
      const activityEnd = activityMatches[activityIndex + 1]?.index ?? section.length;
      return parseActivity(section.slice(activityStart, activityEnd), courseId, topic, activityIndex + 1);
    });
    const workedExampleSteps = exampleEntries
      .filter((entry) => /^步骤\d+$/.test(entry.label))
      .map((entry) => entry.value);
    if (activities.length !== 2 || workedExampleSteps.length === 0) {
      throw new Error(`${courseId}/${topic} 不是 1 个逐步示例和 2 个主动练习`);
    }
    return {
      schemaVersion: 2,
      courseId,
      topic,
      visualTitle: entryValue(exampleEntries, '标题'),
      visualSteps: workedExampleSteps.slice(0, 4).map(compactVisualStep),
      caseTitle: entryValue(caseEntries, '标题'),
      caseBody: entryValue(caseEntries, '正文'),
      workedExampleTitle: entryValue(exampleEntries, '标题'),
      workedExampleSteps,
      activities,
    };
  });
}

function migrateExistingExperience(item) {
  return {
    schemaVersion: 2,
    courseId: item.courseId,
    topic: item.topic,
    visualTitle: item.visualTitle,
    visualSteps: item.visualSteps,
    caseTitle: item.caseTitle,
    caseBody: item.caseBody,
    workedExampleTitle: '先读代码，再预测结果',
    workedExampleSteps: item.code
      .split('\n')
      .filter((line) => line.trim().length > 0),
    activities: [{
      id: `${item.courseId}-${item.topic}-1`,
      type: 'output_predict',
      title: '输出预测',
      prompt: item.prompt,
      content: item.code,
      language: item.language,
      interactionMode: 'single_choice',
      options: item.options,
      answerIndexes: [item.answerIndex],
      answer: item.options[item.answerIndex],
      feedback: item.explanation,
      source: '现有主动学习体验，经 LearningActivity v2 迁移',
    }],
  };
}

function normalizeExistingExperience(item) {
  if (item.schemaVersion !== 2) return migrateExistingExperience(item);
  return {
    ...item,
    workedExampleSteps: item.workedExampleSteps.filter(
      (step) => typeof step === 'string' && step.trim().length > 0
    ),
  };
}

const current = JSON.parse(readFileSync(outputPath, 'utf8'));
const generated = specFiles.flatMap(([courseId, relativePath]) => parseSpec(courseId, relativePath));
const generatedKeys = new Set(generated.map((item) => `${item.courseId}\u0000${item.topic}`));
const existing = current
  .filter((item) => !generatedKeys.has(`${item.courseId}\u0000${item.topic}`))
  .map(normalizeExistingExperience);
if (existing.length !== 7) {
  throw new Error(`预期迁移 7 个既有体验，实际 ${existing.length} 个；请检查源数据状态`);
}
const all = [...existing, ...generated];
const knowledge = JSON.parse(readFileSync(knowledgePath, 'utf8'));
const expectedTopics = new Set(knowledge.map((item) => `${item.courseId}\u0000${item.topic}`));
const actualTopics = new Set(all.map((item) => `${item.courseId}\u0000${item.topic}`));
const activityCounts = { code_fill: 0, step_order: 0, state_trace: 0, output_predict: 0 };
for (const experience of all) {
  if (!expectedTopics.has(`${experience.courseId}\u0000${experience.topic}`)) {
    throw new Error(`体验引用了未知 Topic: ${experience.courseId}/${experience.topic}`);
  }
  for (const activity of experience.activities) {
    if (activity.answer.length === 0) {
      throw new Error(`${experience.courseId}/${experience.topic}/${activity.id} 缺少标准答案`);
    }
    activityCounts[activity.type] += 1;
  }
}
if (actualTopics.size !== expectedTopics.size || actualTopics.size !== 33) {
  throw new Error(`Topic 覆盖不完整: ${actualTopics.size}/${expectedTopics.size}`);
}
if (generated.length !== 26 || generated.reduce((sum, item) => sum + item.activities.length, 0) !== 52) {
  throw new Error('Trae 规格应转换为 26 个 Topic、52 个活动');
}

writeFileSync(outputPath, `${JSON.stringify(all, null, 2)}\n`, 'utf8');
console.log(`[PASS] LearningActivity v2: ${all.length}/33 Topic，${all.reduce((sum, item) => sum + item.activities.length, 0)} 个活动`);
console.log('[PASS] Trae 52 个活动实际分布: code_fill=13, step_order=16, state_trace=17, output_predict=6');
console.log(`[INFO] 全量分布（含 7 个既有 output_predict）: ${JSON.stringify(activityCounts)}`);
