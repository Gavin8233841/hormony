import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDirectory, '..');

function source(relativePath) {
  return readFileSync(path.join(root, relativePath), 'utf8').replaceAll('\r\n', '\n');
}

function methodBlock(input, methodName) {
  const declaration = new RegExp(
    `(?:^|\\n)\\s*(?:export\\s+)?(?:function\\s+)?(?:private\\s+)?(?:async\\s+)?${methodName}\\s*\\(`,
    'm'
  ).exec(input);
  assert.notEqual(declaration, null, `${methodName} declaration missing`);
  const opening = input.indexOf('{', declaration.index + declaration[0].length);
  assert.notEqual(opening, -1, `${methodName} body missing`);
  let depth = 0;
  for (let index = opening; index < input.length; index += 1) {
    if (input[index] === '{') depth += 1;
    if (input[index] === '}') {
      depth -= 1;
      if (depth === 0) return input.slice(opening, index + 1);
    }
  }
  assert.fail(`${methodName} closing brace missing`);
}

const home = source('apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets');
const course = source('apps/harmonyos/entry/src/main/ets/pages/Course.ets');
const detail = source('apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets');
const lesson = source('apps/harmonyos/entry/src/main/ets/pages/Lesson.ets');
const chat = source('apps/harmonyos/entry/src/main/ets/pages/Chat.ets');
const plan = source('apps/harmonyos/entry/src/main/ets/pages/Plan.ets');
const builders = source('apps/harmonyos/entry/src/main/ets/common/Builders.ets');
const constants = source('apps/harmonyos/entry/src/main/ets/common/Constants.ets');

function constantColor(name) {
  const match = new RegExp(`${name}: string = '(#[0-9a-fA-F]{6})';`).exec(constants);
  assert.notEqual(match, null, `${name} color missing`);
  return match[1];
}

function luminance(hex) {
  const channels = hex.match(/[0-9a-fA-F]{2}/g).map((value) => parseInt(value, 16) / 255)
    .map((value) => value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrast(foreground, background) {
  const foregroundLuminance = luminance(foreground);
  const backgroundLuminance = luminance(background);
  return (Math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
    (Math.min(foregroundLuminance, backgroundLuminance) + 0.05);
}

test('首页只在真实主动行动读取成功后开放主操作', () => {
  const load = methodBlock(home, 'loadNextAction');
  const card = methodBlock(home, 'ContinueCard');

  assert.match(home, /@State nextActionLoading: boolean = true;/);
  assert.match(home, /@State nextActionReady: boolean = false;/);
  assert.match(home, /@State nextActionError: boolean = false;/);
  assert.match(load, /const runId = this\.nextActionRunId \+ 1;/);
  assert.match(load, /if \(this\.nextActionRunId !== runId\) return;/);
  assert.match(load, /this\.nextActionReady = true;/);
  assert.match(load, /this\.nextActionError = true;/);
  assert.doesNotMatch(load, /ProactiveLearningService\.fallback/);
  assert.match(card, /if \(this\.nextActionLoading\)/);
  assert.match(card, /else if \(this\.nextActionError \|\| !this\.nextActionReady\)/);
  assert.match(card, /this\.loadNextAction\(\)/);
  assert.match(card, /else \{/);
});

test('课程列表完整失败可原地重试且旧读取不能覆盖新结果', () => {
  const load = methodBlock(course, 'loadCourses');

  assert.match(course, /private loadRunId: number = 0;/);
  assert.match(load, /const runId = this\.loadRunId \+ 1;/);
  assert.match(load, /if \(this\.loadRunId !== runId\) return;/);
  assert.match(course, /Button\('重新加载课程'\)/);
  assert.match(course, /this\.loadCourses\(\)/);
  assert.doesNotMatch(course, /下拉或重新进入页面重试/);
  assert.match(course, /\.constraintSize\(\{ minHeight: 48 \}\)/);
});

test('课程列表把真实已开始和最近学习的课程前置且保留目录顺序兜底', () => {
  const updatedAt = methodBlock(course, 'courseUpdatedAt');
  const visible = methodBlock(course, 'visibleCourses');

  assert.match(updatedAt, /item\.courseId !== course\.id/);
  assert.match(updatedAt, /item\.completedChunkIds\.length === 0/);
  assert.match(updatedAt, /item\.updatedAt > updatedAt/);
  assert.match(visible, /left\.progress > 0 \|\| hasCourseStarted\(this\.resumeState\(left\)\)/);
  assert.match(visible, /rightStarted \? 1 : -1/);
  assert.match(visible, /this\.courseUpdatedAt\(right\)\.localeCompare\(this\.courseUpdatedAt\(left\)\)/);
  assert.match(visible, /this\.courses\.indexOf\(left\) - this\.courses\.indexOf\(right\)/);
  assert.match(course, /ForEach\(this\.visibleCourses\(\)/);
});

test('课程详情加载期间不发布伪续学状态并提供唯一下一步', () => {
  const load = methodBlock(detail, 'loadProgress');

  assert.match(detail, /@State loading: boolean = true;/);
  assert.match(detail, /private loadRunId: number = 0;/);
  assert.match(load, /const runId = this\.loadRunId \+ 1;/);
  assert.match(load, /const resumeState = resolveCourseResumeState\(this\.courseId, this\.topics, lessonProgress\);/);
  assert.match(load, /if \(this\.loadRunId !== runId\) return;/);
  assert.match(detail, /private NextTopicAction\(\)/);
  assert.match(detail, /Button\('重新读取进度'\)/);
  assert.match(detail, /this\.CourseDetailSkeleton\(\)/);
  assert.match(detail, /' 个小节 · '/);
  assert.doesNotMatch(detail, /' 个知识切片 · '/);
  assert.match(detail, /topic === this\.nextTopic\(\) \? Constants\.COLOR_BRAND : Constants\.COLOR_TEXT_TERTIARY/);
});

test('Lesson 底部主操作推进到首个未完成互动', () => {
  const label = methodBlock(lesson, 'finalActionLabel');
  const nextIndex = methodBlock(lesson, 'nextPendingActivityIndex');
  const focus = methodBlock(lesson, 'focusActiveActivity');

  assert.match(nextIndex, /!this\.attemptedActivityIds\.includes\(activity\.id\)/);
  assert.match(label, /const nextIndex = this\.nextPendingActivityIndex\(\);/);
  assert.match(label, /nextIndex \+ 1/);
  assert.match(focus, /const nextIndex = this\.nextPendingActivityIndex\(\);/);
  assert.match(focus, /this\.goToActivity\(nextIndex\);/);
});

test('Lesson 真实后续动作路由失败时保留可见重试反馈', () => {
  const quiz = methodBlock(lesson, 'openFocusedQuizForActivity');
  const practice = methodBlock(lesson, 'openPractice');

  assert.match(quiz, /pushUrl\(\{ url: 'pages\/Quiz' \}\)/);
  assert.match(quiz, /this\.message = '同标签测验打开失败，请重试';/);
  assert.match(practice, /pushUrl\(\{ url: 'pages\/Practice' \}\)/);
  assert.match(practice, /this\.message = '本节进度已保存，但主题练习打开失败，请重试';/);
});

test('Lesson 单选先选择再由明确提交动作写入证据', () => {
  const choose = methodBlock(lesson, 'chooseSingle');
  const submit = methodBlock(lesson, 'submitSingle');
  const practice = methodBlock(lesson, 'PracticeExperience');

  assert.match(choose, /this\.selectedIndexes = \[index\];/);
  assert.doesNotMatch(choose, /markActivityAttempted/);
  assert.match(submit, /this\.selectedIndexes\.length !== 1/);
  assert.match(submit, /this\.markActivityAttempted\(activity, this\.activityIsCorrect\(\)\);/);
  assert.match(practice, /Button\(this\.feedbackVisible \? '答案已提交' : '提交答案'\)/);
  assert.match(practice, /this\.submitSingle\(\)/);
});

test('Lesson 分步示例默认折叠并只按学习者请求逐步揭示', () => {
  const reset = methodBlock(lesson, 'resetActivityInput');
  const count = methodBlock(lesson, 'visibleWorkedExampleStepCount');
  const advance = methodBlock(lesson, 'advanceWorkedExample');
  const practice = methodBlock(lesson, 'PracticeExperience');

  assert.match(lesson, /@State workedExampleRevealCount: number = 0;/);
  assert.match(reset, /this\.workedExampleRevealCount = 0;/);
  assert.match(count, /Math\.min\(this\.workedExampleRevealCount, this\.experience\.workedExampleSteps\.length\)/);
  assert.match(advance, /this\.workedExampleRevealCount >= total \? 0 : this\.workedExampleRevealCount \+ 1/);
  assert.match(practice, /this\.experience\.workedExampleSteps\.slice\(0, this\.visibleWorkedExampleStepCount\(\)\)/);
  assert.match(practice, /Button\(this\.workedExampleActionLabel\(\)\)/);
  assert.doesNotMatch(practice, /ForEach\(this\.experience\.workedExampleSteps,/);
});

test('Lesson 长文本与关键触控不因固定行数和小高度截断', () => {
  const mastery = methodBlock(lesson, 'MasteryBrief');
  const signal = methodBlock(lesson, 'MasterySignal');
  const option = methodBlock(lesson, 'ActivityOption');

  assert.match(mastery, /Column\(\{ space: 8 \}\)/);
  assert.match(signal, /Row\(\{ space: 10 \}\)/);
  assert.doesNotMatch(signal, /maxLines/);
  assert.doesNotMatch(option, /maxLines/);
  assert.doesNotMatch(option, /TextOverflow\.Ellipsis/);
  assert.doesNotMatch(lesson, /\.height\((?:40|42|44)\)/);
  assert.match(lesson, /Constants\.COLOR_ERROR/);
});

test('共享返回控件提供 48vp 触控区与可访问名称', () => {
  const titleBar = methodBlock(builders, 'TitleBar');
  const gradientHeader = methodBlock(builders, 'GradientHeader');

  for (const header of [titleBar, gradientHeader]) {
    assert.match(header, /Button\(\{ type: ButtonType\.Normal \}\)/);
    assert.match(header, /\.width\(48\)/);
    assert.match(header, /\.height\(48\)/);
    assert.match(header, /\.accessibilityText\('返回上一页'\)/);
  }
});

test('Chat 核心操作在大字号与读屏下保留 48vp 和对象化语义', () => {
  const actionName = methodBlock(chat, 'sendButtonAccessibilityText');
  const build = methodBlock(chat, 'build');
  const bubble = methodBlock(chat, 'MessageBubble');
  const status = methodBlock(chat, 'MessageStatus');
  const process = methodBlock(chat, 'AnswerProcessCard');
  const markdown = methodBlock(chat, 'MarkdownContent');

  for (const label of ['停止回答', '发送问题', '重新连接云端学伴', '正在连接云端学伴', '发送问题不可用']) {
    assert.match(actionName, new RegExp(`return '${label}';`));
  }
  assert.match(build, /\.width\(48\)\s*\.height\(48\)/);
  assert.match(build, /\.accessibilityText\(this\.sendButtonAccessibilityText\(\)\)/);
  assert.match(build, /\.accessibilityText\('输入学习问题'\)/);
  assert.match(build, /\.accessibilityText\('重新连接云端学伴'\)/);
  assert.match(build, /\.accessibilityText\(this\.historyLoadFailed \? '重新读取本机会话' : '重试保存本机会话'\)/);
  assert.doesNotMatch(build, /\.height\((?:28|32|44)\)/);
  assert.doesNotMatch(build, /\.maxLines\(1\)\s*\.textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\)/);

  for (const block of [bubble, status, process]) {
    assert.match(block, /\.constraintSize\(\{ minHeight: 48 \}\)/);
    assert.match(block, /\.focusable\(true\)/);
    assert.match(block, /\.accessibilityText\(/);
  }
  assert.match(bubble, /'参考资料，共 ' \+\s*msg\.citations\.length\.toString\(\) \+ ' 条'/);
  assert.match(status, /'展开这次回答的错误详情'/);
  assert.match(status, /'重试上一条问题'/);
  assert.match(process, /'展开回答生成过程'/);
  assert.doesNotMatch(status, /\.height\((?:28|36)\)/);
  assert.match(markdown, /Button\('解释这段'\)/);
  assert.match(markdown, /\.accessibilityText\('让学伴解释当前代码片段'\)/);
  assert.doesNotMatch(markdown, /\.height\(28\)/);
});

test('Plan 制定与恢复操作在大字号和读屏下保持完整', () => {
  const suggestions = methodBlock(plan, 'GoalSuggestions');
  const loading = methodBlock(plan, 'PlanLoadingState');
  const evidence = methodBlock(plan, 'AgentTraceCard');
  const checkpoint = methodBlock(plan, 'PlanCheckpoint');
  const checkpointName = methodBlock(plan, 'checkpointAccessibilityText');
  const build = methodBlock(plan, 'build');

  assert.match(suggestions, /Button\(suggestion\)[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)/);
  assert.match(suggestions, /\.accessibilityText\('使用建议目标：' \+ suggestion\)/);
  assert.match(suggestions, /\.enabled\(!this\.loading && !this\.planLoading && this\.retryAction !== 'save'\)/);
  assert.doesNotMatch(suggestions, /\.height\(34\)/);
  assert.match(loading, /Button\('取消'\)[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)/);
  assert.match(loading, /\.accessibilityText\('取消生成学习计划'\)/);
  assert.doesNotMatch(loading, /\.maxLines\(2\)|TextOverflow\.Ellipsis/);
  assert.match(evidence, /\.constraintSize\(\{ minHeight: 48 \}\)/);
  assert.match(evidence, /\.focusable\(true\)/);
  assert.match(evidence, /'展开'\) \+ '规划依据，共 '/);
  assert.match(checkpoint, /\.accessibilityGroup\(true\)\s*\.accessibilityText\(this\.checkpointAccessibilityText\(title, detail, index\)\)/);
  for (const state of ['已完成', '进行中', '未开始']) {
    assert.match(checkpointName, new RegExp(`'${state}'`));
  }

  assert.match(build, /TextInput\(\{[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)[\s\S]*?\.accessibilityText\('输入学习目标'\)/);
  assert.match(build, /Button\(option\.toString\(\) \+ ' 天'\)[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)[\s\S]*?\.accessibilityText\(this\.durationAccessibilityText\(option\)\)/);
  assert.match(build, /\.accessibilityText\(this\.generateAccessibilityText\(\)\)/);
  assert.match(build, /\.accessibilityText\(this\.retryAccessibilityText\(\)\)/);
  assert.match(build, /'展开计划错误详情'/);
  assert.match(build, /\.focusable\(true\)/);
  assert.doesNotMatch(build, /\.height\((?:28|32|38|44)\)/);
  assert.match(plan, /@State editorExpanded: boolean = false;/);
  assert.match(build, /if \(!this\.loading && !this\.planLoading\) \{/);
  assert.match(build, /if \(this\.tasks\.length === 0 \|\| this\.editorExpanded\)/);
  assert.match(build, /Button\('调整目标与周期'\)/);
  assert.match(build, /this\.editorExpanded = true;/);
  assert.match(build, /Button\('收起编辑'\)/);
  assert.match(build, /this\.editorExpanded = false;/);
  assert.match(build, /Button\('收起编辑'\)[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)/);
  assert.match(build, /Button\('调整目标与周期'\)[\s\S]*?\.constraintSize\(\{ minHeight: 48 \}\)/);
  assert.match(build, /\.enabled\(this\.canGenerate && this\.retryAction !== 'save'\)/);
  const saveGuards = build.match(/this\.retryAction !== 'save'/g) ?? [];
  assert.ok(saveGuards.length >= 4, 'Plan input, duration, generation and adjustment must lock during save retry');
  assert.match(build, /this\.retryAction === 'save' \? '保存刚生成的计划'/);
  assert.match(build, /else if \(this\.shouldAdjustPlanInput\(\)\) this\.beginPlanAdjustment\(\);/);
  assert.match(build, /Text\(this\.errorExpanded \? '收起错误详情' : '查看错误详情'\)[\s\S]*?\.focusable\(true\)[\s\S]*?'展开计划错误详情'/);
  assert.match(plan, /if \(this\.retryAction === 'save'\) return '请先保存刚生成的计划';/);
  assert.match(plan, /if \(this\.errorCode === 'SAFETY_BLOCKED' \|\| this\.errorCode === 'INPUT_REJECTED'/);
  assert.match(methodBlock(plan, 'beginPlanAdjustment'), /this\.retryAction = 'none';[\s\S]*?this\.clearErrorEvidence\(\);/);
  const loadingScrolls = build.match(/Scroll\(\) \{/g) ?? [];
  assert.equal(loadingScrolls.length, 2, 'Plan loading and restore states must scroll independently');
});

test('Plan 任务文本和宽屏阅读层级不会依赖省略', () => {
  const build = methodBlock(plan, 'build');
  const taskName = methodBlock(plan, 'taskAccessibilityText');

  assert.doesNotMatch(build, /TextOverflow\.Ellipsis|\.maxLines\(/);
  assert.match(build, /Flex\(\{ wrap: FlexWrap\.Wrap \}\)/);
  assert.match(build, /\.accessibilityGroup\(true\)\s*\.accessibilityText\(this\.taskAccessibilityText\(t\)\)/);
  assert.match(build, /\.accessibilityText\(this\.taskAccessibilityText\(t\)\)[\s\S]*?Column\(\{ space: 6 \}\) \{[\s\S]*?Button\(this\.actionLabel\(t\)\)/);
  const flexibleTaskActions = build.match(/\.constraintSize\(\{ minWidth: 64, minHeight: 48 \}\)/g) ?? [];
  assert.equal(flexibleTaskActions.length, 2, 'Plan task actions must grow beyond their 64 x 48 vp minimum');
  assert.doesNotMatch(build, /\.width\(64\)|\.height\(48\)/);
  assert.match(taskName, /task\.title/);
  assert.match(taskName, /this\.taskReason\(task\)/);
  assert.match(taskName, /task\.estimatedMin\.toString\(\)/);
  const contentLimits = build.match(/\.constraintSize\(\{ maxWidth: 760 \}\)/g) ?? [];
  assert.ok(contentLimits.length >= 6, 'Plan must constrain form, status and task reading width');
});

test('正文辅助色和语义小字在实际浅色表面达到 WCAG AA', () => {
  const surfaces = ['COLOR_BG_CARD', 'COLOR_BG_PAGE', 'COLOR_BRAND_LIGHT'].map(constantColor);
  for (const token of ['COLOR_TEXT_SECONDARY', 'COLOR_TEXT_TERTIARY', 'COLOR_SUCCESS', 'COLOR_WARNING',
    'COLOR_ERROR']) {
    const foreground = constantColor(token);
    for (const background of surfaces) {
      assert.ok(contrast(foreground, background) >= 4.5,
        `${token} contrast ${contrast(foreground, background).toFixed(2)} on ${background}`);
    }
  }
  assert.ok(contrast(constantColor('COLOR_TEXT_PLACEHOLDER'), constantColor('COLOR_BG_CARD')) >= 4.5);
  assert.ok(contrast(constantColor('COLOR_NAV_INACTIVE'), constantColor('COLOR_BG_CARD')) >= 4.5);
});
