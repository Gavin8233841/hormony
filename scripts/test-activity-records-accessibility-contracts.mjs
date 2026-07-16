import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const activityRecordsPath = path.resolve(scriptDirectory,
  '../apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets');

function sourceSection(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `missing source boundary: ${startMarker}`);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `missing source boundary: ${endMarker}`);
  return source.slice(start, end);
}

function readSource() {
  return readFileSync(activityRecordsPath, 'utf8').replaceAll('\r\n', '\n');
}

test('本地记录只在全部读取成功后替换页面快照', () => {
  const source = readSource();
  const loadEvents = sourceSection(source,
    '  private async loadEvents(): Promise<void> {', '\n  private title(event: StudyEvent): string {');

  const loadingIndex = loadEvents.indexOf('this.loading = true;');
  const clearMessageIndex = loadEvents.indexOf("this.message = '';");
  const profileReadIndex = loadEvents.indexOf('await LocalLearningRepository.getProfile()');
  const eventsCommitIndex = loadEvents.indexOf('this.events = events;');
  assert.notEqual(loadingIndex, -1, 'reload must expose loading state');
  assert.notEqual(clearMessageIndex, -1, 'reload must clear the previous error');
  assert.notEqual(profileReadIndex, -1, 'profile evidence read missing');
  assert.notEqual(eventsCommitIndex, -1, 'event snapshot commit missing');
  assert.equal(loadingIndex < clearMessageIndex && clearMessageIndex < profileReadIndex, true,
    'reload state must reset before repository reads');
  assert.equal(profileReadIndex < eventsCommitIndex, true,
    'component state must not mix a new event list with incomplete supporting data');
});

test('空态和已有记录错误态都提供明确的 48vp 重新读取入口', () => {
  const source = readSource();
  const build = source.slice(source.indexOf('  build() {'));
  const retryLabelMatches = build.match(/\.accessibilityText\('重新读取本机学习记录'\)/g) ?? [];
  const retryActionMatches = build.match(/\.onClick\(\(\): void => \{ this\.loadEvents\(\); \}\)/g) ?? [];
  const retryHeightMatches = build.match(/\.constraintSize\(\{ minHeight: 48 \}\)/g) ?? [];

  assert.equal(retryLabelMatches.length, 2, 'both error branches need an unambiguous screen-reader name');
  assert.equal(retryActionMatches.length, 2, 'both error branches must retry the repository read');
  assert.equal(retryHeightMatches.length >= 2, true, 'retry controls must provide 48vp touch targets');
  assert.equal(build.includes(".accessibilityText('正在读取本机学习记录')"), true,
    'loading skeleton needs a stable screen-reader status');
});

test('四周日格使用最小高度承接字体放大', () => {
  const source = readSource();
  const overview = sourceSection(source,
    '  @Builder\n  ActivityOverview() {', '\n  build() {');

  assert.equal(overview.includes('.constraintSize({ minHeight: 42 })'), true,
    'day cells must grow beyond their baseline height when text scales');
  assert.equal(overview.includes('.height(42)'), false,
    'day cells must not clip scaled text to a fixed height');
});

test('筛选项在窄屏等分空间并播报选中状态', () => {
  const source = readSource();
  const filterPill = sourceSection(source,
    '  @Builder\n  FilterPill(value: string) {', '\n  @Builder\n  ActivityOverview() {');
  const filterText = sourceSection(source,
    '  private filterAccessibilityText(value: string): string {', '\n  private eventMatchesFilter(');

  assert.equal(filterPill.includes('.layoutWeight(1)'), true, 'filter pills must share narrow-screen width');
  assert.equal(filterPill.includes('.constraintSize({ minHeight: 48 })'), true,
    'filter pills must retain a 48vp minimum touch target while text grows');
  assert.equal(filterPill.includes('.accessibilityText(this.filterAccessibilityText(value))'), true,
    'filter pills need a dynamic screen-reader name');
  assert.equal(filterText.includes("this.selectedFilter === value ? '已选中' : '未选中'"), true,
    'filter screen-reader name must expose selected state');
});

test('四周节奏按真实事件汇总为单个可解释的无障碍节点', () => {
  const source = readSource();
  const overview = sourceSection(source,
    '  @Builder\n  ActivityOverview() {', '\n  build() {');
  const overviewText = sourceSection(source,
    '  private activityOverviewAccessibilityText(): string {', '\n  private activityDayColor(');

  assert.equal(overview.includes('.accessibilityGroup(true)'), true,
    'activity heatmap must avoid announcing ambiguous day numbers as separate nodes');
  assert.equal(overview.includes('.accessibilityText(this.activityOverviewAccessibilityText())'), true,
    'activity heatmap needs a derived summary');
  for (const evidenceMethod of ['this.streakDays', 'this.activeDaysCount()', 'this.recentEventCount()',
    'this.bestDayLabel()']) {
    assert.equal(overviewText.includes(evidenceMethod), true,
      `activity summary missing real-state evidence: ${evidenceMethod}`);
  }
});

test('记录整卡播报完整事件证据且视觉详情允许两行', () => {
  const source = readSource();
  const eventText = sourceSection(source,
    '  private eventAccessibilityText(event: StudyEvent): string {', '\n  private openEvent(');
  const eventList = sourceSection(source,
    '          ForEach(this.visibleEvents, (event: StudyEvent, index: number): void => {',
    '\n          if (this.visibleEvents.length === 0) {');

  for (const evidenceMethod of ['this.dateLabel(event.timestamp)', 'this.timeLabel(event.timestamp)',
    'this.title(event)', 'this.detail(event)', 'this.eventActionLabel(event)']) {
    assert.equal(eventText.includes(evidenceMethod), true,
      `event screen-reader name missing evidence: ${evidenceMethod}`);
  }
  assert.equal(eventList.includes('.accessibilityGroup(true)'), true,
    'each event card must be announced as one coherent record');
  assert.equal(eventList.includes('.accessibilityText(this.eventAccessibilityText(event))'), true,
    'each event card must expose its complete evidence and action');
  assert.equal(eventList.includes('.maxLines(2)'), true,
    'event evidence needs a second visual line on narrow screens');
  assert.equal(eventList.includes('Flex({ wrap: FlexWrap.Wrap })'), true,
    'time and action metadata must wrap instead of competing for a fixed trailing column');
});
