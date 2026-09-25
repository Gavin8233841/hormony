import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LearningFormUpdater } from '../common/LearningFormUpdater';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CuratedKnowledgeChunk, LearningActivity, LessonExperience, LessonProgress } from '../model/DataModels';
import { LearningStudyEvent } from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const EMPTY_CHUNK: CuratedKnowledgeChunk = {
  id: '',
  text: '',
  source: '',
  courseId: '',
  topic: ''
};

interface LessonGraphNode {
  id: number;
  x: number;
  y: number;
}

interface LessonGraphEdge {
  from: number;
  to: number;
}

interface LessonChatContext {
  courseId: string;
  topic: string;
  question: string;
  userAnswer: string;
  submitted: boolean;
  correctAnswer?: string;
}

// 坐标只负责绘制。边分别与 lesson-experiences.json 中两张题图对应。
const GRAPH_NODES: LessonGraphNode[] = [
  { id: 0, x: 95, y: 12 }, { id: 1, x: 15, y: 82 }, { id: 2, x: 175, y: 82 },
  { id: 3, x: 15, y: 152 }, { id: 4, x: 175, y: 152 }
];
const BFS_EDGES: LessonGraphEdge[] = [
  { from: 0, to: 1 }, { from: 0, to: 2 }, { from: 1, to: 3 }, { from: 2, to: 4 }
];
const DFS_EDGES: LessonGraphEdge[] = [
  { from: 0, to: 1 }, { from: 0, to: 3 }, { from: 1, to: 2 },
  { from: 1, to: 4 }, { from: 2, to: 3 }, { from: 3, to: 4 }
];
const BFS_QUEUES: string[] = ['0', '1 → 2', '2 → 3', '3 → 4', '4', '空'];
const BFS_VISITS: string[] = ['0', '0 → 1 → 2', '0 → 1 → 2 → 3',
  '0 → 1 → 2 → 3 → 4', '0 → 1 → 2 → 3 → 4', '0 → 1 → 2 → 3 → 4'];
const BFS_NEXT: number[] = [0, 1, 2, 3, 4];
const BFS_VISITED_COUNT: number[] = [1, 3, 4, 5, 5, 5];

@Entry
@Component
struct LessonPage {
  private contentScroller: Scroller = new Scroller();
  private activityOffset: number = 0;
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State chunks: CuratedKnowledgeChunk[] = [];
  @State activeChunk: CuratedKnowledgeChunk = EMPTY_CHUNK;
  @State completedChunkIds: string[] = [];
  @State currentIndex: number = 0;
  @State saving: boolean = false;
  @State message: string = '';
  @State experience: LessonExperience | null = null;
  @State activeActivityIndex: number = 0;
  @State selectedIndexes: number[] = [];
  @State responseText: string = '';
  @State submittedResponseText: string = '';
  @State feedbackVisible: boolean = false;
  @State attemptedActivityIds: string[] = [];
  @State pendingActivityIds: string[] = [];
  private pendingActivityEvents: LearningStudyEvent[] = [];
  @State conceptStepIndex: number = 0;
  @State bfsGraphStepIndex: number = 0;
  @State bfsPredictionMessage: string = '';
  @State bfsStepExpanded: boolean = false;
  @State dfsGraphStepIndex: number = 0;
  @State graphPromptExpanded: boolean = false;
  @State codeRunStepIndex: number = -1;
  @State workedExampleRevealCount: number = 0;
  @State activityEvidenceMessage: string = '';
  @State loading: boolean = true;
  @StorageProp('safeAreaBottomVp') safeAreaBottomVpValue: number = 0;
  private loadRunId: number = 0;

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topic = AppStorage.get<string>('selectedContentTopic') ?? '';
    this.pendingActivityEvents = this.pendingActivityEvents.filter((event: LearningStudyEvent): boolean =>
      event.courseId === this.courseId && event.topic === this.topic);
    this.completedChunkIds = [];
    this.currentIndex = 0;
    this.message = '';
    this.activeActivityIndex = 0;
    this.attemptedActivityIds = [];
    this.pendingActivityIds = [];
    this.activityOffset = 0;
    this.resetActivityInput();
    const content = LearningContentRepository.getKnowledge(this.courseId, this.topic);
    this.experience = LearningContentRepository.getLessonExperience(this.courseId, this.topic);
    this.conceptStepIndex = 0;
    this.bfsGraphStepIndex = 0;
    this.bfsPredictionMessage = '';
    this.bfsStepExpanded = false;
    this.dfsGraphStepIndex = 0;
    this.graphPromptExpanded = false;
    this.chunks = content;
    this.activeChunk = content.length > 0 ? content[0] : EMPTY_CHUNK;
    this.loadProgress();
  }

  private async loadProgress(): Promise<void> {
    const runId = this.loadRunId + 1;
    this.loadRunId = runId;
    this.loading = true;
    this.message = '';
    try {
      const progress = await LocalLearningRepository.getLessonProgress(this.courseId);
      if (this.loadRunId !== runId) return;
      const item = progress.find((value: LessonProgress): boolean => value.topic === this.topic);
      this.completedChunkIds = item?.completedChunkIds ?? [];
      if (this.chunks.length > 0) {
        const nextIndex = this.chunks.findIndex((chunk: CuratedKnowledgeChunk): boolean =>
          !this.completedChunkIds.includes(chunk.id));
        this.currentIndex = nextIndex >= 0 ? nextIndex : 0;
        this.activeChunk = this.chunks[this.currentIndex];
      }
    } catch (error) {
      if (this.loadRunId !== runId) return;
      this.message = '学习进度读取失败，但课程内容仍可查看';
    }
    await this.restoreActivityProgress(runId);
    if (this.loadRunId === runId) this.loading = false;
  }

  private async restoreActivityProgress(runId: number = this.loadRunId): Promise<void> {
    if (this.experience === null || this.experience.activities.length === 0) return;
    try {
      const activityIds = this.experience.activities.map((activity: LearningActivity): string => activity.id);
      const events = await LocalLearningRepository.getStudyEvents();
      if (this.loadRunId !== runId) return;
      const attemptedIds: string[] = [];
      for (const event of events) {
        if (event.type !== 'lesson_activity' || event.courseId !== this.courseId || event.topic !== this.topic ||
          event.taskId === undefined || !activityIds.includes(event.taskId) || attemptedIds.includes(event.taskId)) {
          continue;
        }
        attemptedIds.push(event.taskId);
      }
      this.attemptedActivityIds = attemptedIds;
      const nextIndex = this.experience.activities.findIndex((activity: LearningActivity): boolean =>
        !attemptedIds.includes(activity.id));
      this.activeActivityIndex = nextIndex >= 0 ? nextIndex : this.experience.activities.length - 1;
      this.resetActivityInput();
    } catch (error) {
      if (this.loadRunId !== runId) return;
      if (this.message.length === 0) this.message = '互动断点读取失败，可继续当前练习';
    }
  }

  private moveTo(index: number): void {
    if (index < 0 || index >= this.chunks.length) return;
    this.currentIndex = index;
    this.activeChunk = this.chunks[index];
    this.message = '';
    this.contentScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private activeActivity(): LearningActivity | null {
    if (this.experience === null || this.experience.activities.length === 0) return null;
    return this.experience.activities[this.activeActivityIndex] ?? null;
  }

  private resetActivityInput(): void {
    this.selectedIndexes = [];
    this.responseText = '';
    this.submittedResponseText = '';
    this.feedbackVisible = false;
    this.codeRunStepIndex = -1;
    this.workedExampleRevealCount = 0;
    this.activityEvidenceMessage = '';
    this.dfsGraphStepIndex = 0;
    this.graphPromptExpanded = false;
  }

  private visibleWorkedExampleStepCount(): number {
    if (this.experience === null) return 0;
    return Math.min(this.workedExampleRevealCount, this.experience.workedExampleSteps.length);
  }

  private workedExampleActionLabel(): string {
    if (this.experience === null || this.experience.workedExampleSteps.length === 0) return '暂无分步提示';
    if (this.visibleWorkedExampleStepCount() === 0) return '查看第 1 步';
    if (this.visibleWorkedExampleStepCount() >= this.experience.workedExampleSteps.length) return '收起分步提示';
    return '再看一步';
  }

  private advanceWorkedExample(): void {
    if (this.experience === null) return;
    const total = this.experience.workedExampleSteps.length;
    if (total === 0) return;
    this.workedExampleRevealCount = this.workedExampleRevealCount >= total ? 0 : this.workedExampleRevealCount + 1;
  }

  private conceptStepCount(): number {
    return this.experience === null ? 0 : this.experience.visualSteps.length;
  }

  private conceptStepButtonLabel(): string {
    const total = this.conceptStepCount();
    if (total === 0) return '暂无推演步骤';
    if (this.conceptStepIndex >= total - 1) return '重新推演';
    return '对照第 ' + (this.conceptStepIndex + 2).toString() + ' 步';
  }

  private advanceConceptStep(): void {
    const total = this.conceptStepCount();
    if (total === 0) return;
    this.conceptStepIndex = this.conceptStepIndex >= total - 1 ? 0 : this.conceptStepIndex + 1;
  }

  private chooseSingle(index: number): void {
    const activity = this.activeActivity();
    if (activity === null || this.feedbackVisible) return;
    this.selectedIndexes = [index];
  }

  private submitSingle(): void {
    const activity = this.activeActivity();
    if (activity === null || this.selectedIndexes.length !== 1 || this.feedbackVisible) return;
    this.feedbackVisible = true;
    this.markActivityAttempted(activity, this.activityIsCorrect());
  }

  private chooseOrderStep(index: number): void {
    if (this.feedbackVisible || this.selectedIndexes.includes(index)) return;
    this.selectedIndexes = this.selectedIndexes.concat([index]);
  }

  private submitOrder(): void {
    const activity = this.activeActivity();
    if (activity === null || this.selectedIndexes.length !== activity.options.length) return;
    this.feedbackVisible = true;
    this.markActivityAttempted(activity, this.activityIsCorrect());
  }

  private revealFreeResponse(): void {
    const activity = this.activeActivity();
    const answer: string = this.responseText.trim();
    if (answer.length === 0) {
      this.message = '请先写下你的推演或填空答案';
      return;
    }
    this.message = '';
    this.responseText = answer;
    this.submittedResponseText = answer;
    this.feedbackVisible = true;
    if (activity !== null && this.hasDfsGraphSource(activity)) {
      setTimeout((): void => {
        this.contentScroller.scrollTo({
          xOffset: 0,
          yOffset: Math.max(this.activityOffset - 12, 0),
          animation: true
        });
      }, 50);
    }
  }

  private activityOptionAccessibilityDescription(index: number, ordered: boolean): string {
    const selected: boolean = this.selectedIndexes.includes(index);
    if (this.feedbackVisible) return selected ? '已选择，答案已提交' : '未选择，答案已提交';
    if (!selected) return ordered ? '未选择，点击加入排序' : '未选择，点击选择';
    if (ordered) {
      return '已选择，排序第 ' + (this.selectedIndexes.indexOf(index) + 1).toString() + ' 位';
    }
    return '已选择，可更改选择';
  }

  private selfAssess(activity: LearningActivity, covered: boolean): void {
    this.markActivityAttempted(activity, covered, true);
  }

  private markActivityAttempted(activity: LearningActivity, correct: boolean, selfAssessed: boolean = false): void {
    if (this.attemptedActivityIds.includes(activity.id) || this.pendingActivityIds.includes(activity.id)) return;
    const courseId = this.courseId;
    const topic = this.topic;
    this.pendingActivityIds = this.pendingActivityIds.concat([activity.id]);
    this.activityEvidenceMessage = '正在保存互动记录...';
    this.persistActivityEvidence(activity, correct, selfAssessed).then((): void => {
      if (this.courseId !== courseId || this.topic !== topic) return;
      this.pendingActivityIds = this.pendingActivityIds.filter((id: string): boolean => id !== activity.id);
      if (!this.attemptedActivityIds.includes(activity.id)) {
        this.attemptedActivityIds = this.attemptedActivityIds.concat([activity.id]);
      }
      if (selfAssessed) {
        this.activityEvidenceMessage = correct ?
          '已记录。来做几道相关题。' :
          '已记录。看看遗漏的关键点。';
      } else {
        this.activityEvidenceMessage = correct ?
          '已记录本次客观题结果：回答正确。' :
          '已记录本次客观题结果：回答有误，建议查看对照重点。';
      }
    }).catch((): void => {
      if (this.courseId !== courseId || this.topic !== topic) return;
      this.pendingActivityIds = this.pendingActivityIds.filter((id: string): boolean => id !== activity.id);
      this.activityEvidenceMessage = '互动记录保存失败，请重试保存后再继续。';
    });
  }

  private async persistActivityEvidence(activity: LearningActivity, correct: boolean, selfAssessed: boolean): Promise<void> {
    let event: LearningStudyEvent;
    const cachedEvent = this.pendingActivityEvents.find((item: LearningStudyEvent): boolean =>
      item.courseId === this.courseId && item.topic === this.topic && item.taskId === activity.id);
    if (cachedEvent !== undefined) {
      event = cachedEvent;
    } else {
      const now = new Date().toISOString();
      if (selfAssessed) {
        event = {
          id: 'lesson_activity_' + now + '_' + activity.id,
          type: 'lesson_activity',
          timestamp: now,
          courseId: this.courseId,
          topic: this.topic,
          taskId: activity.id,
          source: 'lesson_self_assessment',
          difficulty: this.activityDifficulty(activity),
          tags: this.activityTags(activity)
        };
      } else {
        event = {
          id: 'lesson_activity_' + now + '_' + activity.id,
          type: 'lesson_activity',
          timestamp: now,
          courseId: this.courseId,
          topic: this.topic,
          taskId: activity.id,
          source: 'lesson_interactive',
          difficulty: this.activityDifficulty(activity),
          accuracy: correct ? 1 : 0,
          tags: this.activityTags(activity),
          totalQuestions: 1,
          correctCount: correct ? 1 : 0
        };
      }
      this.pendingActivityEvents = this.pendingActivityEvents.concat([event]);
    }
    await LocalLearningRepository.appendStudyEvent(event);
    this.pendingActivityEvents = this.pendingActivityEvents.filter((item: LearningStudyEvent): boolean =>
      item.id !== event.id);
    LearningFormUpdater.refreshAll().catch((): void => {});
  }

  private appendUniqueTag(tags: string[], value: string): void {
    const normalized = value.trim();
    if (normalized.length > 0 && !tags.includes(normalized)) tags.push(normalized);
  }

  private activityTags(activity: LearningActivity): string[] {
    const tags: string[] = [];
    this.appendUniqueTag(tags, this.topic);
    this.appendUniqueTag(tags, activity.focusTag);
    this.appendUniqueTag(tags, activity.title);
    this.appendUniqueTag(tags, this.activityModeLabel(activity));
    if (activity.language.length > 0) this.appendUniqueTag(tags, activity.language);
    return tags.slice(0, 5);
  }

  private activityModeLabel(activity: LearningActivity): string {
    if (activity.content.length > 0) return '代码推演';
    if (activity.interactionMode === 'ordered_choice') return '步骤排序';
    if (activity.interactionMode === 'free_response') return '主动表达';
    return '概念判断';
  }

  private activityDifficulty(activity: LearningActivity): string {
    if (activity.interactionMode === 'free_response' || activity.interactionMode === 'ordered_choice') return 'medium';
    if (activity.content.length > 0) return 'medium';
    return 'easy';
  }

  private primaryActivityTag(activity: LearningActivity): string {
    return activity.focusTag;
  }

  private activityIsCorrect(): boolean {
    const activity = this.activeActivity();
    if (activity === null || activity.answerIndexes.length !== this.selectedIndexes.length) return false;
    return activity.answerIndexes.every((answer: number, index: number): boolean =>
      answer === this.selectedIndexes[index]);
  }

  private allActivitiesAttempted(): boolean {
    if (this.experience === null) return true;
    return this.experience.activities.every((activity: LearningActivity): boolean =>
      this.attemptedActivityIds.includes(activity.id));
  }

  private nextPendingActivityIndex(): number {
    if (this.experience === null) return -1;
    return this.experience.activities.findIndex((activity: LearningActivity): boolean =>
      !this.attemptedActivityIds.includes(activity.id));
  }

  private showIntroExperience(): boolean {
    return this.experience !== null && this.currentIndex === 0;
  }

  private showPracticeExperience(): boolean {
    return this.experience !== null && this.currentIndex === this.chunks.length - 1;
  }

  private goToActivity(index: number): void {
    if (this.experience === null || index < 0 || index >= this.experience.activities.length) return;
    this.activeActivityIndex = index;
    this.resetActivityInput();
    this.message = '';
    this.contentScroller.scrollPage({ next: false });
  }

  private finalActionLabel(): string {
    if (this.saving) return '保存中...';
    if (this.currentIndex < this.chunks.length - 1) return '学完本节，继续';
    if (this.needsActivityResume() && this.experience !== null) {
      const nextIndex = this.nextPendingActivityIndex();
      return '继续互动 ' + (nextIndex + 1).toString() + '/' +
        this.experience.activities.length.toString();
    }
    return '完成主题并练习';
  }

  private needsActivityResume(): boolean {
    return this.experience !== null && this.experience.activities.length > 0 &&
      this.currentIndex === this.chunks.length - 1 && !this.allActivitiesAttempted();
  }

  private focusActiveActivity(): void {
    if (!this.needsActivityResume()) return;
    const nextIndex = this.nextPendingActivityIndex();
    if (nextIndex >= 0 && nextIndex !== this.activeActivityIndex) {
      this.goToActivity(nextIndex);
    }
    this.message = '';
    setTimeout((): void => {
      if (this.activityOffset > 0) {
        this.contentScroller.scrollTo({
          xOffset: 0,
          yOffset: Math.max(this.activityOffset - 12, 0),
          animation: true
        });
      } else {
        this.contentScroller.scrollPage({ next: true });
      }
    }, 50);
  }

  private handlePrimaryAction(): void {
    if (this.needsActivityResume()) {
      this.focusActiveActivity();
      return;
    }
    this.completeCurrent();
  }

  private safeAreaBottomVp(): number {
    return Math.max(0, this.safeAreaBottomVpValue);
  }

  private contentBeats(): string[] {
    return this.activeChunk.text
      .replace(/；/g, '。')
      .split('。')
      .map((sentence: string): string => sentence.trim())
      .filter((sentence: string): boolean => sentence.length > 0)
      .map((sentence: string): string => sentence + '。');
  }

  private masteryGoal(): string {
    if (this.hasBfsGraphSource()) {
      return '能说清 BFS 怎样用队列逐层扩展，并用 DFS 递归预测另一张图的访问顺序。';
    }
    if (this.experience !== null && this.experience.visualSteps.length > 0) {
      const first = this.experience.visualSteps[0];
      const last = this.experience.visualSteps[this.experience.visualSteps.length - 1];
      return '学完后能把「' + first + ' → ' + last + '」讲清楚，并完成一次主动练习。';
    }
    return '学完后能用自己的话解释本节核心点，并进入练习验证。';
  }

  private currentLearningFocus(): string {
    if (this.hasBfsGraphSource() && this.showIntroExperience()) return '试着找出下一个出队的顶点。';
    if (this.hasBfsGraphSource() && this.showPracticeExperience()) {
      return this.activeActivityIndex === 0 ? '写出 DFS 的访问顺序。' : '排列 BFS 的通用步骤。';
    }
    if (this.showIntroExperience()) return '看一个例子，弄清这个概念。';
    if (this.showPracticeExperience()) return '试着完成这道题。';
    return '把正文拆成判断点，逐条确认自己是否能复述。';
  }

  private activityProgressText(): string {
    if (this.experience === null || this.experience.activities.length === 0) return '无互动练习';
    return this.attemptedActivityIds.length.toString() + '/' + this.experience.activities.length.toString() + ' 已练';
  }

  private codeRunSteps(activity: LearningActivity): string[] {
    const contentLines = activity.content
      .split('\n')
      .map((line: string): string => line.trim())
      .filter((line: string): boolean => line.length > 0 && line !== '代码：');
    const firstLine = contentLines.length > 0 ? contentLines[0] : '题干';
    const lastLine = contentLines.length > 1 ? contentLines[contentLines.length - 1] : firstLine;
    const answer = activity.answer.length > 36 ? activity.answer.substring(0, 36) + '…' : activity.answer;
    return [
      '入口：从「' + firstLine + '」开始，圈出输入、状态变量和输出位置。',
      '状态：逐行更新变量或指针，遇到空缺先写下自己的预测，不急着看答案。',
      '出口：走到「' + lastLine + '」，代入答案「' + answer + '」并检查是否满足题意。'
    ];
  }

  private codeRunProgressValue(activity: LearningActivity): number {
    if (this.codeRunStepIndex < 0) return 0;
    return Math.min(this.codeRunStepIndex + 1, this.codeRunSteps(activity).length);
  }

  private codeRunButtonLabel(activity: LearningActivity): string {
    if (this.codeRunStepIndex < 0) return '开始逐步推演';
    if (this.codeRunStepIndex < this.codeRunSteps(activity).length - 1) return '对照下一步';
    return '推演完成';
  }

  private advanceCodeRun(activity: LearningActivity): void {
    const total = this.codeRunSteps(activity).length;
    if (this.codeRunStepIndex < total - 1) {
      this.codeRunStepIndex += 1;
    }
  }

  private activityAnswerText(activity: LearningActivity): string {
    if (activity.interactionMode === 'free_response') {
      const answer: string = this.feedbackVisible ? this.submittedResponseText : this.responseText.trim();
      return answer.length > 0 ? answer : '未作答';
    }
    const answers: string[] = [];
    for (const index of this.selectedIndexes) {
      const option = activity.options[index] ?? '';
      if (option.length > 0) answers.push(option);
    }
    return answers.length > 0 ? answers.join(' → ') : '未作答';
  }

  private tutorExcerpt(value: string, maxLength: number): string {
    const normalized = value.trim();
    if (normalized.length <= maxLength) return normalized;
    return normalized.substring(0, maxLength) + '...';
  }

  private buildTutorQuestion(activity: LearningActivity): string {
    if (!this.feedbackVisible) {
      const answer = this.activityAnswerText(activity);
      return '我正在学习“' + this.tutorExcerpt(this.topic, 80) + '”。题目是“' +
        this.tutorExcerpt(activity.prompt, 500) + '”，当前作答是“' +
        this.tutorExcerpt(answer === '未作答' ? '' : answer, 300) +
        '”。我还没有提交，请只给一条思考提示，不透露答案或完整访问顺序。';
    }
    const question = '请结合课程资料讲解这道互动练习：' + this.tutorExcerpt(activity.prompt, 620) +
      '。主题是“' + this.tutorExcerpt(this.topic, 80) + '”，专项标签是“' +
      this.tutorExcerpt(activity.focusTag, 24) + '”，我的答案是“' +
      this.tutorExcerpt(this.activityAnswerText(activity), 360) + '”，参考答案是“' +
      this.tutorExcerpt(activity.answer, 400) + '”。资料依据是“' +
      this.tutorExcerpt(activity.source, 160) +
      '”。请以这条资料依据为边界，先指出关键概念与错因，再给一个同标签的下一步练习建议。';
    return question.length <= 1800 ? question : question.substring(0, 1797) + '...';
  }

  private askTutorForActivity(activity: LearningActivity): void {
    const question = this.buildTutorQuestion(activity);
    const answer = this.activityAnswerText(activity);
    const baseContext: LessonChatContext = {
      courseId: this.courseId,
      topic: this.topic,
      question: activity.prompt.substring(0, 500),
      userAnswer: (answer === '未作答' ? '' : answer).substring(0, 300),
      submitted: this.feedbackVisible
    };
    const context: LessonChatContext = this.feedbackVisible ? {
      courseId: baseContext.courseId,
      topic: baseContext.topic,
      question: baseContext.question,
      userAnswer: baseContext.userAnswer,
      submitted: true,
      correctAnswer: activity.answer.substring(0, 300)
    } : baseContext;
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    AppStorage.setOrCreate<string>('pendingChatContextJson', JSON.stringify(context));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '无法打开学伴，请重试';
    });
  }

  private openFocusedQuizForActivity(activity: LearningActivity): void {
    if (!LearningContentRepository.getTopics(this.courseId).includes(this.topic)) {
      this.message = '当前主题无效，无法生成专项测验';
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', this.topic);
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', this.primaryActivityTag(activity));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LessonPage focused quiz navigation failed: %{public}s', error.message);
      this.message = '同标签测验打开失败，请重试';
    });
  }

  private async completeCurrent(): Promise<void> {
    if (this.saving || this.activeChunk.id.length === 0) return;
    if (this.currentIndex === this.chunks.length - 1 && !this.allActivitiesAttempted() &&
      !this.completedChunkIds.includes(this.activeChunk.id)) {
      this.message = '请先完成本主题的全部互动练习';
      return;
    }
    this.saving = true;
    this.message = '';
    try {
      await LocalLearningRepository.completeLessonChunk(
        this.courseId,
        this.topic,
        this.activeChunk.id,
        this.chunks.length
      );
      LearningFormUpdater.refreshAll().catch((): void => {});
      if (!this.completedChunkIds.includes(this.activeChunk.id)) {
        this.completedChunkIds = this.completedChunkIds.concat([this.activeChunk.id]);
      }
      if (this.currentIndex < this.chunks.length - 1) {
        this.moveTo(this.currentIndex + 1);
      } else {
        this.openPractice();
      }
    } catch (error) {
      this.message = '学习进度保存失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private openPractice(): void {
    AppStorage.setOrCreate<string>('selectedPracticeTopic', this.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LessonPage Practice navigation failed: %{public}s', error.message);
      this.message = '本节进度已保存，但主题练习打开失败，请重试';
    });
  }

  private hasBfsGraphSource(): boolean {
    return this.courseId === 'cs101' &&
      this.topic === '图的表示与遍历' && this.experience !== null &&
      this.experience.visualTitle.includes('边:   0-1, 0-2, 1-3, 2-4') &&
      this.experience.workedExampleSteps.length === BFS_QUEUES.length &&
      this.experience.workedExampleSteps[0].includes('队列: [0]') &&
      this.experience.workedExampleSteps[5].includes('队列为空');
  }

  private hasDfsGraphSource(activity: LearningActivity): boolean {
    return this.courseId === 'cs101' &&
      this.topic === '图的表示与遍历' &&
      activity.id === 'cs101-图的表示与遍历-1' &&
      activity.prompt.includes('0: [1, 3]') && activity.prompt.includes('1: [0, 2, 4]') &&
      activity.prompt.includes('2: [1, 3]') && activity.prompt.includes('3: [0, 2, 4]') &&
      activity.prompt.includes('4: [1, 3]') && activity.answer.includes('0 1 2 3 4');
  }

  private graphNode(id: number): LessonGraphNode {
    return GRAPH_NODES[id];
  }

  private graphNodeVisited(id: number, dfs: boolean): boolean {
    return dfs ? this.feedbackVisible && id <= this.dfsGraphStepIndex :
      id < BFS_VISITED_COUNT[this.bfsGraphStepIndex];
  }

  private predictBfsNext(id: number): void {
    if (this.bfsGraphStepIndex >= BFS_NEXT.length) return;
    if (id !== BFS_NEXT[this.bfsGraphStepIndex]) {
      this.bfsPredictionMessage = '看看队首，再试一次。';
      return;
    }
    this.bfsGraphStepIndex += 1;
    this.bfsPredictionMessage = this.bfsGraphStepIndex >= BFS_NEXT.length ?
      '完成！队列已经清空。' : '答对了！';
  }

  @Builder
  private GraphBoard(dfs: boolean) {
    Column({ space: dfs ? 10 : 6 }) {
      Row() {
        Text(dfs ? 'DFS 练习图 · 无向' : 'BFS 示例图 · 无向')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_MAP_CORE)
        Text('起点 0')
          .fontSize(11)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(dfs ? DFS_EDGES : BFS_EDGES, (edge: LessonGraphEdge): void => {
          Line()
            .width(220)
            .height(190)
            .startPoint([this.graphNode(edge.from).x + 15, this.graphNode(edge.from).y + 15])
            .endPoint([this.graphNode(edge.to).x + 15, this.graphNode(edge.to).y + 15])
            .stroke(Constants.COLOR_MAP_LINE_ACTIVE)
            .strokeWidth(2)
        })
        ForEach(GRAPH_NODES, (node: LessonGraphNode): void => {
          Text(node.id.toString())
            .width(30)
            .height(30)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.graphNodeVisited(node.id, dfs) ?
              Constants.COLOR_BRAND : Constants.COLOR_MAP_NODE_IDLE)
            .borderRadius(15)
            .position({ x: node.x, y: node.y })
            .accessibilityText('顶点 ' + node.id.toString() +
              (this.graphNodeVisited(node.id, dfs) ? '，已访问' : '，尚未访问'))
        })
      }
      .width(220)
      .height(190)
      .alignSelf(ItemAlign.Center)
      .accessibilityGroup(true)
      .accessibilityDescription(dfs ? '深度优先搜索活动图，按邻接表升序遍历' :
        '广度优先搜索概念示例图，边为 0-1、0-2、1-3、2-4')
    }
    .width('100%')
    .padding(dfs ? 16 : 12)
    .backgroundColor(Constants.COLOR_MAP_SURFACE)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  private BfsGraphExperience() {
    Column({ space: 6 }) {
      Row() {
        Text('广度优先搜索')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text((this.bfsGraphStepIndex + 1).toString() + ' / ' + BFS_QUEUES.length.toString())
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      this.GraphBoard(false)
      Text('队列（左侧为队首）：' + BFS_QUEUES[this.bfsGraphStepIndex])
        .width('100%')
        .fontSize(14)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Text('已访问：' + BFS_VISITS[this.bfsGraphStepIndex])
        .width('100%')
        .fontSize(13)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
      if (this.bfsGraphStepIndex < BFS_NEXT.length) {
        Row({ space: 6 }) {
          Text('下一个出队的是谁？')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          if (this.bfsPredictionMessage.length > 0) {
            Text(this.bfsPredictionMessage)
              .layoutWeight(1)
              .fontSize(11)
              .maxLines(1)
              .textAlign(TextAlign.End)
              .fontColor(Constants.COLOR_BRAND_TEXT)
          }
        }
        .width('100%')
        Row({ space: 8 }) {
          ForEach(GRAPH_NODES, (node: LessonGraphNode): void => {
            Button(node.id.toString())
              .layoutWeight(1)
              .constraintSize({ minHeight: 48 })
              .fontSize(13)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
              .accessibilityText('预测顶点 ' + node.id.toString() + ' 下一个出队')
              .onClick((): void => { this.predictBfsNext(node.id); })
          })
        }
        .width('100%')
      } else {
        Button('重新推演')
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .fontColor(Constants.COLOR_BRAND_TEXT)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => {
            this.bfsGraphStepIndex = 0;
            this.bfsPredictionMessage = '';
          })
      }
      if (this.bfsGraphStepIndex >= BFS_NEXT.length && this.bfsPredictionMessage.length > 0) {
        Text(this.bfsPredictionMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(Constants.COLOR_BRAND_TEXT)
      }
      Button(this.bfsStepExpanded ? '收起解释' : '查看这一步')
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .fontSize(12)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .backgroundColor(Constants.COLOR_BG_TAG)
        .borderRadius(Constants.RADIUS_MD)
        .onClick((): void => { this.bfsStepExpanded = !this.bfsStepExpanded; })
      if (this.bfsStepExpanded) {
        Text(this.experience!.workedExampleSteps[this.bfsGraphStepIndex])
          .width('100%')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  private DfsGraphExperience(activity: LearningActivity) {
    Column({ space: 12 }) {
      this.GraphBoard(true)
      Text('从 0 开始，按邻接表升序访问。写出输出序列。')
        .width('100%')
        .fontSize(14)
        .lineHeight(23)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Button(this.graphPromptExpanded ? '收起原题和代码' : '查看原题和代码')
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .fontSize(12)
        .fontColor(Constants.COLOR_BRAND_TEXT)
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
        .onClick((): void => { this.graphPromptExpanded = !this.graphPromptExpanded; })
      if (this.graphPromptExpanded) {
        Text(activity.prompt)
          .width('100%')
          .fontSize(12)
          .lineHeight(20)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      if (this.feedbackVisible) {
        Text('单步对照 · 已访问 ' + (this.dfsGraphStepIndex + 1).toString() + '/5')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('访问序列：' + GRAPH_NODES.slice(0, this.dfsGraphStepIndex + 1)
          .map((node: LessonGraphNode): string => node.id.toString()).join(' → '))
          .width('100%')
          .fontSize(13)
          .fontColor(Constants.COLOR_BRAND_TEXT)
        Button(this.dfsGraphStepIndex >= GRAPH_NODES.length - 1 ? '重新对照' : '查看下一步')
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => {
            this.dfsGraphStepIndex = this.dfsGraphStepIndex >= GRAPH_NODES.length - 1 ?
              0 : this.dfsGraphStepIndex + 1;
          })
      }
    }
    .width('100%')
  }

  @Builder
  private MasteryBrief() {
    Column({ space: 12 }) {
      Row() {
        Text('本节掌握标准')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_BRAND_TEXT)
        Text(this.activityProgressText())
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.masteryGoal())
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Regular)
        .lineHeight(24)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)

      Column({ space: 8 }) {
        this.MasterySignal('目标', this.topic.length > 0 ? this.topic : this.courseTitle)
        this.MasterySignal('方法', this.currentLearningFocus())
        this.MasterySignal('反馈', this.showPracticeExperience() ? '做完练习后进题组' : '完成本节后继续')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  private MasterySignal(label: string, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .width(38)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
      Text(value)
        .layoutWeight(1)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(18)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private CodeBlock(activity: LearningActivity) {
    Column({ space: 8 }) {
      Row() {
        Text(activity.language.length > 0 ? activity.language : 'code')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
        Text('课程固定示例 · 不执行输入')
          .fontSize(11)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Scroll() {
        Text(activity.content)
          .width('100%')
          .fontSize(12)
          .fontFamily('monospace')
          .lineHeight(20)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
      }
      .width('100%')
      .constraintSize({ maxHeight: 220 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Constants.COLOR_MAP_SURFACE)
    .borderRadius(Constants.RADIUS_SM)
  }

  @Builder
  private CodeRunPanel(activity: LearningActivity) {
    Column({ space: 10 }) {
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(17)
            .fontColor([Constants.COLOR_BRAND])
          Text('固定示例推演')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        Text('看代码怎么运行')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text('观察变量和指针如何变化。')
        .width('100%')
        .fontSize(12)
        .lineHeight(19)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)

      Progress({
        value: this.codeRunProgressValue(activity),
        total: this.codeRunSteps(activity).length,
        type: ProgressType.Linear
      })
        .width('100%')
        .color(Constants.COLOR_SUCCESS)
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)

      ForEach(this.codeRunSteps(activity), (step: string, index: number): void => {
        Row({ space: 10 }) {
          Text((index + 1).toString())
            .width(24)
            .height(24)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(index <= this.codeRunStepIndex ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND_TEXT)
            .textAlign(TextAlign.Center)
            .backgroundColor(index <= this.codeRunStepIndex ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND_LIGHT)
            .borderRadius(12)
          Text(step)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(20)
            .fontColor(index <= this.codeRunStepIndex ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      })

      Row({ space: 10 }) {
        Button('重来')
          .layoutWeight(1)
          .constraintSize({ minHeight: 48 })
          .fontSize(12)
          .enabled(this.codeRunStepIndex >= 0)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .onClick((): void => { this.codeRunStepIndex = -1; })
        Button(this.codeRunButtonLabel(activity))
          .layoutWeight(1)
          .constraintSize({ minHeight: 48 })
          .fontSize(12)
          .enabled(this.codeRunStepIndex < this.codeRunSteps(activity).length - 1)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_SM)
          .onClick((): void => { this.advanceCodeRun(activity); })
      }
      .width('100%')

      if (this.codeRunStepIndex >= this.codeRunSteps(activity).length - 1) {
        Text(this.feedbackVisible ? '固定示例、作答和对照均已完成。' : '固定示例推演完成：现在作答，再用解析检查状态链。')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_SUCCESS)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
    .borderRadius(Constants.RADIUS_MD)
  }

  @Builder
  private ActivityOption(option: string, index: number, ordered: boolean) {
    Button({ type: ButtonType.Normal }) {
      Text((ordered && this.selectedIndexes.includes(index) ?
        (this.selectedIndexes.indexOf(index) + 1).toString() + '. ' : '') + option)
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.selectedIndexes.includes(index) ?
          Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.selectedIndexes.includes(index) ?
      (ordered || !this.feedbackVisible ? Constants.COLOR_BRAND :
        (this.activityIsCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR)) :
      Constants.COLOR_BG_TAG)
    .borderRadius(Constants.RADIUS_MD)
    .enabled(!this.feedbackVisible)
    .accessibilityText(option)
    .accessibilityDescription(this.activityOptionAccessibilityDescription(index, ordered))
    .onClick((): void => {
      if (ordered) {
        this.chooseOrderStep(index);
      } else {
        this.chooseSingle(index);
      }
    })
  }

  @Builder
  private FeedbackSection(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .width('100%')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
      Text(value)
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private IntroExperience() {
    if (this.experience !== null) {
      Column({ space: 14 }) {
        if (!this.hasBfsGraphSource()) {
          Row() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(18)
                .fontColor([Constants.COLOR_BRAND])
              Text('概念推演')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
            }
            Text((this.conceptStepIndex + 1).toString() + ' / ' + this.conceptStepCount().toString())
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        if (this.hasBfsGraphSource()) {
          this.BfsGraphExperience()
        } else {
          Text(this.experience.visualTitle)
            .width('100%')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)

          Column({ space: 8 }) {
            ForEach(this.experience.visualSteps, (step: string, index: number): void => {
            Row({ space: 10 }) {
              Text((index + 1).toString())
                .width(24)
                .height(24)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(index <= this.conceptStepIndex ?
                  Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .backgroundColor(index <= this.conceptStepIndex ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
                .borderRadius(12)
              Text(index <= this.conceptStepIndex ? step : '待推演')
                .layoutWeight(1)
                .constraintSize({ minHeight: 46 })
                .fontSize(13)
                .fontWeight(index === this.conceptStepIndex ? FontWeight.Bold : FontWeight.Regular)
                .lineHeight(21)
                .fontColor(index <= this.conceptStepIndex ?
                  Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_PLACEHOLDER)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor(index === this.conceptStepIndex ?
                  Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
                .borderRadius(Constants.RADIUS_SM)
            }
            .width('100%')
            })
          }
          .width('100%')

          Button(this.conceptStepButtonLabel())
            .width('100%')
            .constraintSize({ minHeight: 48 })
            .enabled(this.conceptStepCount() > 0)
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.advanceConceptStep(); })
        }
      }
      .width('100%')

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.lightbulb_max_fill'))
            .fontSize(17)
            .fontColor([Constants.COLOR_WARNING])
          Text(this.experience.caseTitle)
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        .width('100%')
        Text(this.experience.caseBody)
          .width('100%')
          .fontSize(14)
          .lineHeight(24)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
      .borderRadius(Constants.RADIUS_MD)
    }
  }

  @Builder
  private PracticeExperience() {
    if (this.experience !== null) {
      if (!this.hasBfsGraphSource()) {
        Column({ space: 10 }) {
        Row() {
          Text('分步示例')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_BRAND_TEXT)
          Text(this.visibleWorkedExampleStepCount().toString() + ' / ' +
            this.experience.workedExampleSteps.length.toString() + ' 步')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        Text(this.experience.workedExampleTitle)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        ForEach(this.experience.workedExampleSteps.slice(0, this.visibleWorkedExampleStepCount()),
          (step: string, index: number): void => {
          Row({ space: 10 }) {
            Text((index + 1).toString())
              .width(24)
              .height(24)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .textAlign(TextAlign.Center)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(12)
            Text(step)
              .layoutWeight(1)
              .fontSize(13)
              .lineHeight(21)
              .fontColor(Constants.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        })
        Button(this.workedExampleActionLabel())
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .enabled(this.experience.workedExampleSteps.length > 0)
          .fontSize(13)
          .fontColor(Constants.COLOR_BRAND_TEXT)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .accessibilityText(this.workedExampleActionLabel())
          .onClick((): void => { this.advanceWorkedExample(); })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .border({ width: 1, color: Constants.COLOR_BORDER })
        .borderRadius(Constants.RADIUS_MD)
      }

      if (this.activeActivity() !== null) {
        Column({ space: 12 }) {
          Row() {
            Text('主动练习 · ' + this.activeActivity()!.title)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_BRAND_TEXT)
            Text((this.activeActivityIndex + 1).toString() + ' / ' +
              this.experience.activities.length.toString())
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Row({ space: 8 }) {
            Text('本练聚焦')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Text(this.activeActivity()!.focusTag)
              .layoutWeight(1)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          if (this.hasDfsGraphSource(this.activeActivity()!)) {
            this.DfsGraphExperience(this.activeActivity()!)
          } else {
            Text(this.activeActivity()!.prompt)
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Regular)
              .lineHeight(25)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          }

          if (this.activeActivity()!.id === 'cs101-图的表示与遍历-2') {
            Text('提示：上方概念示例是无向图；这道题考查有向图 BFS 的通用步骤。')
              .width('100%')
              .fontSize(12)
              .lineHeight(20)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }

          if (this.activeActivity()!.content.length > 0) {
            this.CodeBlock(this.activeActivity()!)
            this.CodeRunPanel(this.activeActivity()!)
          }

          if (!this.feedbackVisible) {
            Button('问学伴给一条提示')
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.askTutorForActivity(this.activeActivity()!); })
          }

          if (this.activeActivity()!.interactionMode === 'single_choice') {
            ForEach(this.activeActivity()!.options, (option: string, index: number): void => {
              this.ActivityOption(option, index, false)
            })
            Button(this.feedbackVisible ? '答案已提交' : '提交答案')
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .enabled(this.selectedIndexes.length === 1 && !this.feedbackVisible)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.submitSingle(); })
          } else if (this.activeActivity()!.interactionMode === 'ordered_choice') {
            ForEach(this.activeActivity()!.options, (option: string, index: number): void => {
              this.ActivityOption(option, index, true)
            })
            Row({ space: 10 }) {
              Button('重置顺序')
                .layoutWeight(1)
                .constraintSize({ minHeight: 48 })
                .enabled(!this.feedbackVisible)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
                .backgroundColor(Constants.COLOR_BG_TAG)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.resetActivityInput(); })
              Button('提交顺序')
                .layoutWeight(1)
                .constraintSize({ minHeight: 48 })
                .enabled(this.selectedIndexes.length === this.activeActivity()!.options.length &&
                  !this.feedbackVisible)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.submitOrder(); })
            }
            .width('100%')
          } else {
            TextArea({ placeholder: '写下你的答案', text: this.responseText })
              .width('100%')
              .height(132)
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .backgroundColor(Constants.COLOR_SURFACE_TINT)
              .border({ width: 1, color: Constants.COLOR_BORDER })
              .borderRadius(Constants.RADIUS_MD)
              .enabled(!this.feedbackVisible)
              .accessibilityText(this.feedbackVisible ? '已提交的自由回答' : '自由回答输入框')
              .accessibilityDescription(this.feedbackVisible ? '答案已冻结，可向下对照关键点' :
                '输入你的答案或推演过程')
              .onChange((value: string): void => {
                if (!this.feedbackVisible) this.responseText = value;
              })
            Button(this.feedbackVisible ? '已提交' : '提交答案')
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .enabled(!this.feedbackVisible)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.revealFreeResponse(); })
          }

          if (this.feedbackVisible) {
            Column({ space: 12 }) {
              Text(this.activeActivity()!.interactionMode === 'free_response' ?
                '对照关键点' : (this.activityIsCorrect() ? '答对了' : '再看看这题'))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.activeActivity()!.interactionMode === 'free_response' || this.activityIsCorrect() ?
                  Constants.COLOR_SUCCESS : Constants.COLOR_ERROR)
              this.FeedbackSection('你的回答', this.activityAnswerText(this.activeActivity()!))
              if (!this.hasDfsGraphSource(this.activeActivity()!) ||
                this.dfsGraphStepIndex >= GRAPH_NODES.length - 1) {
                this.FeedbackSection('参考答案', this.activeActivity()!.answer)
                this.FeedbackSection('对照重点', this.activeActivity()!.feedback)
              } else {
                Text('完成图中步骤后可看参考答案。')
                  .width('100%')
                  .fontSize(12)
                  .lineHeight(20)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              Text('来源：' + this.activeActivity()!.source)
                .width('100%')
                .fontSize(11)
                .lineHeight(18)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              if (this.activityEvidenceMessage.length > 0) {
                Text(this.activityEvidenceMessage)
                  .width('100%')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .lineHeight(18)
                  .fontColor(this.activityEvidenceMessage.includes('失败') ?
                    Constants.COLOR_ERROR : Constants.COLOR_BRAND_TEXT)
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.activeActivity()!.interactionMode === 'free_response' || this.activityIsCorrect() ?
              Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_ERROR_LIGHT)
            .borderRadius(Constants.RADIUS_SM)

            if (this.activeActivity()!.interactionMode === 'free_response' &&
              !this.attemptedActivityIds.includes(this.activeActivity()!.id) &&
              (!this.hasDfsGraphSource(this.activeActivity()!) ||
                this.dfsGraphStepIndex >= GRAPH_NODES.length - 1)) {
              Row({ space: 10 }) {
                Button('关键点有遗漏')
                  .layoutWeight(1)
                  .constraintSize({ minHeight: 48 })
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  .backgroundColor(Constants.COLOR_BG_TAG)
                  .borderRadius(Constants.RADIUS_MD)
                  .enabled(!this.pendingActivityIds.includes(this.activeActivity()!.id))
                  .onClick((): void => { this.selfAssess(this.activeActivity()!, false); })
                Button('关键点已覆盖')
                  .layoutWeight(1)
                  .constraintSize({ minHeight: 48 })
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_SUCCESS)
                  .borderRadius(Constants.RADIUS_MD)
                  .enabled(!this.pendingActivityIds.includes(this.activeActivity()!.id))
                  .onClick((): void => { this.selfAssess(this.activeActivity()!, true); })
              }
              .width('100%')
            }

            if (this.activeActivity()!.interactionMode !== 'free_response' &&
              !this.attemptedActivityIds.includes(this.activeActivity()!.id) &&
              !this.pendingActivityIds.includes(this.activeActivity()!.id) &&
              this.activityEvidenceMessage.includes('保存失败')) {
              Button('重试保存记录')
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .fontSize(12)
                .fontColor(Constants.COLOR_ERROR)
                .backgroundColor(Constants.COLOR_BG_TAG)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => {
                  this.markActivityAttempted(this.activeActivity()!, this.activityIsCorrect());
                })
            }

            Row({ space: 10 }) {
              Button('问学伴讲解')
                .layoutWeight(1)
                .constraintSize({ minHeight: 48 })
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND_TEXT)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.askTutorForActivity(this.activeActivity()!); })
              Button('同标签测验')
                .layoutWeight(1)
                .constraintSize({ minHeight: 48 })
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.openFocusedQuizForActivity(this.activeActivity()!); })
            }
            .width('100%')
          }

          if (this.attemptedActivityIds.includes(this.activeActivity()!.id)) {
            Row() {
              Text('本练习已完成')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_SUCCESS)
              if (this.activeActivityIndex < this.experience.activities.length - 1) {
                Button('下一练习')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_BRAND)
                  .borderRadius(Constants.RADIUS_SM)
                  .onClick((): void => { this.goToActivity(this.activeActivityIndex + 1); })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .border({ width: 1, color: Constants.COLOR_BORDER })
        .borderRadius(Constants.RADIUS_LG)
        .onAreaChange((_: Area, newValue: Area): void => {
          const nextOffset = Number(newValue.position.y);
          if (nextOffset >= 0) this.activityOffset = nextOffset;
        })
      }
    }
  }

  @Builder
  private LessonSkeleton() {
    Column({ space: 18 }) {
      Row() {
        Column().width(96).height(20).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
        Column().width(42).height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Column().width('100%').height(8).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(4)
      Column().width('100%').height(132).backgroundColor(Constants.COLOR_BG_SKELETON)
        .borderRadius(Constants.RADIUS_LG)
      Column({ space: 12 }) {
        Column().width('86%').height(22).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
        Column().width('100%').height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        Column().width('94%').height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        Column().width('78%').height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
    }
    .width('100%')
  }

  @Builder
  private LessonOpening() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.lightbulb_max_fill'))
          .fontSize(18)
          .fontColor([Constants.COLOR_BRAND])
        Text('这节讲什么')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND_TEXT)
      }
      .width('100%')

      Text(this.contentBeats()[0] ?? this.activeChunk.text)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Regular)
        .lineHeight(26)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(Constants.COLOR_SURFACE_TINT)
    .borderRadius(Constants.RADIUS_LG)
  }

  build() {
    Column() {
      TitleBar(this.topic.length > 0 ? this.topic : '课程内容', this.courseTitle,
        () => this.getUIContext().getRouter().back())

      if (this.loading) {
        Column() {
          this.LessonSkeleton()
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .layoutWeight(1)
        .padding({ left: 18, right: 18, top: 4, bottom: 24 + this.safeAreaBottomVp() })
      } else if (this.chunks.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(38)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('该主题暂无课程内容')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          Row() {
            Text('精选课程内容')
              .fontSize(11)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
            Text((this.currentIndex + 1).toString() + ' / ' + this.chunks.length.toString())
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Progress({ value: this.currentIndex + 1, total: this.chunks.length, type: ProgressType.Linear })
            .width('100%')
            .color(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 12 })

        Scroll(this.contentScroller) {
          Column({ space: 24 }) {
            if (this.hasBfsGraphSource() && this.showIntroExperience()) {
              this.IntroExperience()
            }

            this.LessonOpening()

            if (this.showIntroExperience() && !this.hasBfsGraphSource()) {
              this.IntroExperience()
            }

            if (this.showPracticeExperience()) {
              this.PracticeExperience()
            }

            this.MasteryBrief()

            if (this.contentBeats().length > 1) {
              Column({ space: 16 }) {
                Text('拆开理解')
                  .width('100%')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)

                ForEach(this.contentBeats().slice(1), (sentence: string, index: number): void => {
                  Row({ space: 12 }) {
                    Column()
                      .width(8)
                      .height(8)
                      .backgroundColor(index === this.contentBeats().length - 2 ?
                        Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                      .borderRadius(4)
                      .margin({ top: 9 })
                    Text(sentence)
                      .layoutWeight(1)
                      .fontSize(15)
                      .lineHeight(26)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                })
              }
              .width('100%')
            }

            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(17)
                .fontColor([Constants.COLOR_TEXT_SECONDARY])
              Column({ space: 2 }) {
                Text('内容来源')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                Text(this.activeChunk.source)
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (this.completedChunkIds.includes(this.activeChunk.id)) {
                Text('已学')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_SUCCESS)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
                  .borderRadius(Constants.RADIUS_SM)
              }
            }
            .width('100%')
            .padding({ top: 16 })
            .border({ width: { top: 1 }, color: Constants.COLOR_BORDER })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%', maxWidth: 720 })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18, top: 4, bottom: 24 + this.safeAreaBottomVp() })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })

        if (this.message.length > 0) {
          Row({ space: 10 }) {
            Text(this.message)
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.message.includes('失败') ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            if (this.message.includes('进度读取失败') || this.message.includes('断点读取失败')) {
              Button('重试')
                .constraintSize({ minHeight: 48 })
                .padding({ left: 14, right: 14 })
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND_TEXT)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
                .accessibilityText('重新读取当前主题学习进度')
                .onClick((): void => { this.loadProgress(); })
            }
          }
            .width('100%')
            .padding({ left: 18, right: 18, top: 8 })
        }

        Row({ space: 10 }) {
          Button('上一篇')
            .width(92)
            .height(48)
            .enabled(this.currentIndex > 0)
            .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.moveTo(this.currentIndex - 1); })

          Button(this.finalActionLabel())
            .layoutWeight(1)
            .height(48)
            .enabled(!this.saving)
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.handlePrimaryAction(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 20 + this.safeAreaBottomVp() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
