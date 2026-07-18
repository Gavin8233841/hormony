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

function balancedBlock(source, marker) {
  const markerIndex = source.indexOf(marker);
  assert.notEqual(markerIndex, -1, `missing block marker: ${marker}`);
  const openingBrace = source.indexOf('{', markerIndex);
  assert.notEqual(openingBrace, -1, `missing opening brace: ${marker}`);
  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}') depth -= 1;
    if (depth === 0) return source.slice(markerIndex, index + 1);
  }
  assert.fail(`missing closing brace: ${marker}`);
}

function readSource() {
  return readFileSync(activityRecordsPath, 'utf8').replaceAll('\r\n', '\n');
}

function activityDayColorEvaluator(source) {
  const method = sourceSection(source,
    '  private activityDayColor(day: ActivityDay): string {', '\n  private activityDayTextColor(');
  const bodyStart = method.indexOf('{');
  const bodyEnd = method.lastIndexOf('}');
  assert.notEqual(bodyStart, -1, 'activityDayColor body start missing');
  assert.notEqual(bodyEnd, -1, 'activityDayColor body end missing');
  return new Function('day', 'Constants', method.slice(bodyStart + 1, bodyEnd));
}

test('本地记录只在全部读取成功后替换页面快照', () => {
  const source = readSource();
  const loadEvents = sourceSection(source,
    '  private async loadEvents(): Promise<void> {', '\n  private title(event: StudyEvent): string {');

  const loadingIndex = loadEvents.indexOf('this.loading = true;');
  const clearMessageIndex = loadEvents.indexOf("this.dataMessage = '';");
  const windowIndex = loadEvents.indexOf('.slice(-ACTIVITY_WINDOW_LIMIT).reverse();');
  const profileReadIndex = loadEvents.indexOf('await LocalLearningRepository.getProfile()');
  const eventsCommitIndex = loadEvents.indexOf('this.events = events;');
  assert.notEqual(loadingIndex, -1, 'reload must expose loading state');
  assert.notEqual(clearMessageIndex, -1, 'reload must clear the previous error');
  assert.notEqual(windowIndex, -1, 'activity page must take the newest retained 500-event window');
  assert.notEqual(profileReadIndex, -1, 'profile evidence read missing');
  assert.notEqual(eventsCommitIndex, -1, 'event snapshot commit missing');
  assert.equal(loadingIndex < clearMessageIndex && clearMessageIndex < profileReadIndex, true,
    'reload state must reset before repository reads');
  assert.equal(profileReadIndex < eventsCommitIndex, true,
    'component state must not mix a new event list with incomplete supporting data');
  const requestStart = loadEvents.indexOf('const requestSequence = ++this.loadSequence;');
  const staleGuard = loadEvents.indexOf('if (requestSequence !== this.loadSequence) return;', profileReadIndex);
  assert.equal(requestStart >= 0 && requestStart < profileReadIndex &&
    staleGuard > profileReadIndex && eventsCommitIndex > staleGuard, true,
  'only the latest complete repository snapshot may replace visible activity state');
  assert.equal(loadEvents.includes(
    'if (requestSequence === this.loadSequence) this.loading = false;'), true,
  'a stale read must not end loading owned by a newer request');
  const catchStart = loadEvents.indexOf('} catch (error) {');
  const catchEnd = loadEvents.indexOf('\n    } finally {', catchStart);
  const failureBranch = loadEvents.slice(catchStart, catchEnd);
  for (const destructiveReset of ['this.events = [];', 'this.visibleEvents = [];', 'this.courses = [];',
    'this.planTasks = [];', 'this.recentDays = [];', 'this.streakDays = 0;']) {
    assert.equal(failureBranch.includes(destructiveReset), false,
      `refresh failure must preserve the previous complete snapshot: ${destructiveReset}`);
  }
  assert.equal(failureBranch.includes('当前显示上次读取结果'), true,
    'refresh failure must explain that the previous snapshot remains visible');
});

test('标题与四周摘要明确限定为本页最新 500 条窗口', () => {
  const source = readSource();
  const loadEvents = sourceSection(source,
    '  private async loadEvents(): Promise<void> {', '\n  private title(event: StudyEvent): string {');
  const overviewText = sourceSection(source,
    '  private activityOverviewAccessibilityText(): string {', '\n  private activityDayColor(');
  const build = source.slice(source.indexOf('  build() {'));

  assert.equal(source.includes('const ACTIVITY_WINDOW_LIMIT: number = 500;'), true,
    'retained activity window limit must be explicit');
  assert.equal(loadEvents.includes('.slice(-ACTIVITY_WINDOW_LIMIT).reverse();'), true,
    'the displayed list must be capped to the newest retained window');
  assert.equal(build.includes("'本页近期 ' + this.events.length.toString() + ' 条 · 最多展示 500 条'"), true,
    'title summary must describe a bounded local window instead of lifetime history');
  assert.equal(overviewText.includes('来自本机记录中最新 500 条的页面窗口'), true,
    'screen-reader overview must retain the same bounded-window meaning');
  assert.equal(build.includes("this.events.length.toString() + ' 条活动 · 仅保存在本机'"), false,
    'the old lifetime-total-shaped title must not return');
});

test('数据恢复与导航恢复提供独立的 48vp 动作', () => {
  const source = readSource();
  const build = source.slice(source.indexOf('  build() {'));
  const navigationError = sourceSection(source,
    '          if (this.navigationMessage.length > 0) {',
    '\n          ForEach(this.visibleEvents, (event: StudyEvent, index: number): void => {');
  const retryLabelMatches = build.match(/\.accessibilityText\('重新读取本机学习记录'\)/g) ?? [];
  const retryActionMatches = build.match(/\.onClick\(\(\): void => \{ this\.loadEvents\(\); \}\)/g) ?? [];
  const retryHeightMatches = build.match(/\.constraintSize\(\{ minHeight: 48 \}\)/g) ?? [];

  assert.equal(retryLabelMatches.length, 2, 'both error branches need an unambiguous screen-reader name');
  assert.equal(retryActionMatches.length, 2, 'both error branches must retry the repository read');
  assert.equal(retryHeightMatches.length >= 3, true, 'data and navigation retry controls need 48vp targets');
  assert.equal(navigationError.includes('.onClick((): void => { this.retryNavigation(); })'), true,
    'navigation error must retry the saved navigation action');
  assert.equal(navigationError.includes('this.loadEvents()'), false,
    'navigation error must never fall through to repository loading');
  assert.equal(navigationError.includes(".accessibilityText('重试打开' + this.navigationTarget)"), true,
    'navigation retry must announce the exact dynamic destination');
  assert.equal(navigationError.includes('.accessibilityDescription(this.navigationMessage)'), true,
    'navigation retry must expose its corresponding failure');
  assert.equal(navigationError.includes('.constraintSize({ minHeight: 48 })'), true,
    'navigation retry itself needs a 48vp minimum target');
  assert.equal(build.includes(".accessibilityText('正在读取本机学习记录')"), true,
    'loading skeleton needs a stable screen-reader status');
});

test('导航失败保存并重放精确 route 与 AppStorage 动作，成功只清除当前错误', () => {
  const source = readSource();
  const actionShape = sourceSection(source,
    'interface PendingNavigationAction {', '\n}\n\n@Entry');
  const navigation = sourceSection(source,
    '  private clearNavigationFailure(): void {', '\n  private icon(event: StudyEvent): Resource {');
  const openEvent = sourceSection(source,
    '  private openEvent(event: StudyEvent): void {', '\n  @Builder\n  FilterPill(value: string) {');

  for (const field of ['kind: string;', 'route: string;', 'target: string;', 'failureMessage: string;',
    'courseId: string;', 'courseTitle: string;', 'topic: string;', 'focusTag: string;']) {
    assert.equal(actionShape.includes(field), true, `pending navigation action missing exact field: ${field}`);
  }
  for (const storageAction of [
    "AppStorage.setOrCreate<string>('selectedCourseId', action.courseId)",
    "AppStorage.setOrCreate<string>('selectedCourseTitle', action.courseTitle)",
    "AppStorage.setOrCreate<string>('selectedContentTopic', action.topic)",
    "AppStorage.setOrCreate<string>('selectedPracticeTopic', action.topic)",
    "AppStorage.setOrCreate<string>('selectedQuizTopic', action.topic)",
    "AppStorage.setOrCreate<string>('selectedQuizFocusTag', action.focusTag)"
  ]) {
    assert.equal(navigation.includes(storageAction), true,
      `navigation replay missing AppStorage action: ${storageAction}`);
  }
  assert.equal(navigation.includes('pushUrl({ url: action.route }).then((): void => {'), true,
    'saved route must be used and successful navigation must have a completion branch');
  assert.equal(navigation.includes('attemptSequence === this.navigationAttemptSequence'), true,
    'success must clear only the matching navigation attempt');
  const navigationStart = navigation.indexOf('const attemptSequence = this.beginNavigation();');
  const routeAttempt = navigation.indexOf('pushUrl({ url: action.route })');
  const staleFailureGuard = navigation.indexOf(
    'if (attemptSequence !== this.navigationAttemptSequence) return;');
  const failureCommit = navigation.indexOf('this.pendingNavigationAction = action;');
  assert.equal(navigationStart >= 0 && routeAttempt > navigationStart &&
    staleFailureGuard > routeAttempt && failureCommit > staleFailureGuard, true,
  'only the latest navigation failure may publish a retry action');
  assert.equal(navigation.includes('this.pendingNavigationAction = action;'), true,
    'failed action must be retained verbatim');
  assert.match(navigation,
    /if\s*\(action === null\) return;[\s\S]*if\s*\(!this\.navigationActionValid\(action\)\)[\s\S]*this\.navigate\(action\);/,
    'retry must validate and then replay only the retained action');
  assert.equal(navigation.includes('course.topics.includes(action.topic)'), true,
    'Topic routes must still belong to the current local course catalog at retry time');
  assert.equal(navigation.includes('course.title !== action.courseTitle'), true,
    'retry must not write a stale course title after the local catalog changes');
  assert.equal(navigation.includes('this.loadEvents()'), false,
    'navigation retry must never replace its exact action with a data reload');

  const taskBranch = balancedBlock(openEvent, "if (event.type === 'task_completed') {");
  const lessonBranch = balancedBlock(openEvent,
    "if ((event.type === 'lesson_activity' || event.type === 'lesson_completed') && hasExactTopic) {");
  const quizBranch = balancedBlock(openEvent,
    "if ((event.type === 'quiz_submitted' || event.type === 'quiz_mastered') && hasExactTopic) {");
  const curatedBranch = balancedBlock(quizBranch, "if (event.source === 'curated') {");
  const aiBranch = balancedBlock(quizBranch, "} else if (event.source === 'ai') {");
  const quizFallback = sourceSection(quizBranch, '} else {', '\n      }');
  const finalFallback = openEvent.slice(openEvent.lastIndexOf('this.navigate({'));
  const mappings = [
    [taskBranch, 'NAVIGATION_PLAN', 'pages/Plan'],
    [lessonBranch, 'NAVIGATION_LESSON', 'pages/Lesson'],
    [curatedBranch, 'NAVIGATION_PRACTICE', 'pages/Practice'],
    [aiBranch, 'NAVIGATION_QUIZ', 'pages/Quiz'],
    [quizFallback, 'NAVIGATION_COURSE_DETAIL', 'pages/CourseDetail'],
    [finalFallback, 'NAVIGATION_COURSE_DETAIL', 'pages/CourseDetail'],
  ];
  for (const [branch, kind, route] of mappings) {
    assert.equal(branch.includes(`kind: ${kind}`) && branch.includes(`route: '${route}'`), true,
      `${kind} must stay paired with ${route}`);
  }

  const applyContext = balancedBlock(navigation,
    'private applyNavigationContext(action: PendingNavigationAction): void {');
  const planReturn = applyContext.indexOf('if (action.kind === NAVIGATION_PLAN) return;');
  const courseContext = applyContext.indexOf(
    "AppStorage.setOrCreate<string>('selectedCourseId', action.courseId)");
  assert.equal(planReturn >= 0 && courseContext > planReturn, true,
    'Plan must return before writing course context');
  const lessonContext = balancedBlock(applyContext, 'if (action.kind === NAVIGATION_LESSON) {');
  const practiceContext = balancedBlock(applyContext, '} else if (action.kind === NAVIGATION_PRACTICE) {');
  const quizContext = balancedBlock(applyContext, '} else if (action.kind === NAVIGATION_QUIZ) {');
  assert.equal(lessonContext.includes("'selectedContentTopic'"), true,
    'Lesson must write only its exact Topic key');
  assert.equal(practiceContext.includes("'selectedPracticeTopic'"), true,
    'Practice must write only its exact Topic key');
  assert.equal(quizContext.includes("'selectedQuizTopic'") &&
    quizContext.includes("'selectedQuizFocusTag'"), true,
  'Quiz must write its exact Topic and focus-tag keys');
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

test('筛选项以非颜色符号显示选中态并允许文字换行', () => {
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
  assert.equal(filterPill.includes("SymbolGlyph($r('sys.symbol.checkmark'))"), true,
    'selected filter needs a visible non-color checkmark');
  assert.equal(filterPill.includes('if (this.selectedFilter === value)'), true,
    'checkmark visibility must follow the same selected state');
  assert.equal(filterPill.includes('.maxLines(1)'), false,
    'filter labels must not be forced onto one clipped line');
  assert.equal(filterPill.includes('.textOverflow({ overflow: TextOverflow.Ellipsis })'), false,
    'filter labels must not hide selected text behind ellipsis');
  assert.equal(filterText.includes("this.selectedFilter === value ? '已选中' : '未选中'"), true,
    'filter screen-reader name must expose selected state');
});

test('四周节奏从 recentDays.completed 汇总可见与读屏完成天数', () => {
  const source = readSource();
  const overview = sourceSection(source,
    '  @Builder\n  ActivityOverview() {', '\n  build() {');
  const overviewText = sourceSection(source,
    '  private activityOverviewAccessibilityText(): string {', '\n  private activityDayColor(');
  const completedDays = sourceSection(source,
    '  private completedDaysCount(): number {', '\n  private recentEventCount(');
  const activityDays = sourceSection(source,
    '  private buildActivityDays(events: StudyEvent[]): ActivityDay[] {', '\n  private activityWeeks(');

  assert.equal(overview.includes('.accessibilityGroup(true)'), true,
    'activity heatmap must avoid announcing ambiguous day numbers as separate nodes');
  assert.equal(overview.includes('.accessibilityText(this.activityOverviewAccessibilityText())'), true,
    'activity heatmap needs a derived summary');
  for (const evidenceMethod of ['this.streakDays', 'this.activeDaysCount()', 'this.completedDaysCount()',
    'this.recentEventCount()', 'this.bestDayLabel()']) {
    assert.equal(overviewText.includes(evidenceMethod), true,
      `activity summary missing real-state evidence: ${evidenceMethod}`);
  }
  assert.equal(completedDays.includes('day.completed'), true,
    'completed-day count must derive from recentDays.completed');
  assert.equal(overview.includes("this.completedDaysCount().toString() + ' 天有完成节点'"), true,
    'completed-day count must be visible, not screen-reader-only');
  assert.equal(overview.includes("Text('完成节点')"), true,
    'green legend must describe completion semantics');
  assert.equal(overview.includes('Flex({ wrap: FlexWrap.Wrap })'), true,
    'legend labels and swatches must wrap together on narrow screens');
  assert.equal(overview.includes("Text('多')"), false,
    'green must no longer be described as generic high activity');
  for (const completionType of ["event.type === 'quiz_mastered'", "event.type === 'lesson_completed'",
    "event.type === 'task_completed'"]) {
    assert.equal(activityDays.includes(completionType), true,
      `completion-day derivation missing event type: ${completionType}`);
  }
});

test('一次完成节点为绿色，三次普通活动仍为普通活动色', () => {
  const source = readSource();
  const activityDayColor = activityDayColorEvaluator(source);
  const colors = {
    COLOR_BG_TAG: 'empty',
    COLOR_SUCCESS: 'completed',
    COLOR_BRAND: 'ordinary-high',
    COLOR_BRAND_LIGHT: 'ordinary-low'
  };

  assert.equal(activityDayColor({ count: 1, completed: true }, colors), colors.COLOR_SUCCESS,
    'one completion event must produce completion green');
  assert.equal(activityDayColor({ count: 3, completed: false }, colors), colors.COLOR_BRAND,
    'three ordinary events must remain ordinary activity blue');
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
