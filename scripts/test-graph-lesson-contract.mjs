import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const lesson = readFileSync(new URL('../apps/harmonyos/entry/src/main/ets/pages/Lesson.ets', import.meta.url), 'utf8');
const experiences = JSON.parse(readFileSync(
  new URL('../apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json', import.meta.url), 'utf8'));
const graph = experiences.find((item) => item.courseId === 'cs101' && item.topic === '图的表示与遍历');

function section(name) {
  const start = lesson.indexOf(`const ${name}:`);
  assert.ok(start >= 0, `${name} is defined`);
  const end = lesson.indexOf('];', start);
  return lesson.slice(start, end + 2);
}

function edges(name) {
  return [...section(name).matchAll(/\{ from: (\d+), to: (\d+) \}/g)]
    .map((match) => [Number(match[1]), Number(match[2])].join('-'));
}

function adjacency(prompt) {
  const rows = [...prompt.matchAll(/^(\d+): \[([\d, ]*)\]$/gm)];
  assert.equal(rows.length, 5);
  return rows.map((row) => row[2].split(',').map((value) => Number(value.trim())));
}

test('BFS drawing and state labels match the published concept example', () => {
  assert.ok(graph);
  const sourceEdges = graph.visualTitle.match(/边:\s+([^\n]+)/)[1]
    .split(',').map((value) => value.trim());
  assert.deepEqual(edges('BFS_EDGES'), sourceEdges);
  const queues = [...section('BFS_QUEUES').matchAll(/'([^']+)'/g)].map((match) => match[1]);
  const visits = [...section('BFS_VISITS').matchAll(/'([^']+)'/g)].map((match) => match[1]);
  assert.equal(queues.length, graph.workedExampleSteps.length);
  assert.equal(visits.length, queues.length);
  assert.deepEqual(queues, ['0', '1 → 2', '2 → 3', '3 → 4', '4', '空']);
  for (let index = 0; index < 5; index += 1) {
    assert.ok(graph.workedExampleSteps[index].includes(`队列: [${queues[index].replaceAll(' → ', ', ')}]`));
  }
  assert.ok(graph.workedExampleSteps[5].includes('队列为空'));
});

test('DFS drawing matches its own activity graph and does not reveal the traversal before submit', () => {
  const activity = graph.activities.find((item) => item.id === 'cs101-图的表示与遍历-1');
  assert.equal(activity.type, 'output_predict');
  const adj = adjacency(activity.prompt);
  const expectedEdges = new Set();
  adj.forEach((neighbors, from) => neighbors.forEach((to) => {
    expectedEdges.add(`${Math.min(from, to)}-${Math.max(from, to)}`);
  }));
  assert.deepEqual(new Set(edges('DFS_EDGES')), expectedEdges);
  assert.notDeepEqual(new Set(edges('DFS_EDGES')), new Set(edges('BFS_EDGES')));

  const visited = new Set();
  const order = [];
  function dfs(vertex) {
    visited.add(vertex);
    order.push(vertex);
    for (const next of adj[vertex]) if (!visited.has(next)) dfs(next);
  }
  dfs(0);
  assert.equal(order.join(' '), '0 1 2 3 4');
  assert.ok(activity.answer.includes(order.join(' ')));
  const panel = lesson.slice(lesson.indexOf('private DfsGraphExperience('), lesson.indexOf('private MasteryBrief()'));
  assert.match(panel, /if \(this\.feedbackVisible\)/);
  assert.match(lesson, /this\.dfsGraphStepIndex >= GRAPH_NODES\.length - 1/);
});

test('tutor handoff separates unsubmitted hints from submitted review', () => {
  const tutor = lesson.slice(lesson.indexOf('private buildTutorQuestion('), lesson.indexOf('private openFocusedQuizForActivity('));
  const hint = tutor.slice(tutor.indexOf('if (!this.feedbackVisible)'), tutor.indexOf('const question ='));
  assert.doesNotMatch(hint, /activity\.answer|correctAnswer/);
  assert.match(hint, /不透露答案/);
  assert.match(tutor, /question: activity\.prompt\.substring\(0, 500\)/);
  assert.match(tutor, /userAnswer: \(answer === '未作答' \? '' : answer\)\.substring\(0, 300\)/);
  assert.match(tutor, /submitted: this\.feedbackVisible/);
  assert.match(tutor, /correctAnswer: activity\.answer\.substring\(0, 300\)/);
  assert.match(tutor, /'pendingChatContextJson', JSON\.stringify\(context\)/);
});
