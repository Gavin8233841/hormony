/**
 * 学习计划页
 * 浅色主题 · 用户友好文案 · 任务列表
 */

import { HttpClient, HttpRequestCancellation, HttpStatusError } from '../common/HttpClient';
import { GradientHeader, StagedProgress, WorkStep } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { StudyPlan, PlanTask, PlanRequest, PlanTaskUpdateReceipt } from '../model/DataModels';
import { LearningStudyEvent as StudyEvent } from '../model/LearningMetadataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningFormUpdater } from '../common/LearningFormUpdater';

interface AgentPlanTask extends PlanTask {
  reason?: string;
}

interface AgentStudyPlan extends StudyPlan {
  agentTrace?: string[];
}

interface PlanValidationResult {
  valid: boolean;
  message: string;
  plan: AgentStudyPlan | null;
}

@Entry
@Component
struct PlanPage {
  private goalInputController: TextInputController = new TextInputController();
  @State goal: string = '';
  @State days: number = 14;
  @StorageLink('currentPlanTasks') tasks: PlanTask[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State hasError: boolean = false;
  @State planLoading: boolean = true;
  @State agentTrace: string[] = [];
  @State progressStep: number = 0;
  @State progressTick: number = 0;
  @State savedPlanGoal: string = '';
  @State evidenceExpanded: boolean = false;
  @State editorExpanded: boolean = false;
  @State errorHttpStatus: number = 0;
  @State errorCode: string = '';
  @State errorExpanded: boolean = false;
  @State retryAction: string = 'none';
  @State updatingTaskId: string = '';
  @State collapsedDays: string[] = [];
  @State expandedFutureDays: string[] = [];
  private activeRequest: HttpRequestCancellation | null = null;
  private generationRunId: number = 0;
  private planReadRunId: number = 0;
  private lifecycleRunId: number = 0;
  private pageActive: boolean = false;
  private hasLoadedPlanOnce: boolean = false;
  private pendingPlan: AgentStudyPlan | null = null;
  private durationOptions: number[] = [7, 14, 21];
  private goalSuggestions: string[] = ['两周复习数据结构', '一周掌握 TCP 基础', '三周准备操作系统考试'];
  private planSteps: WorkStep[] = [
    { title: '准备', description: '读取本机学习状态' },
    { title: '规划', description: '等待在线学伴安排节奏' },
    { title: '检查', description: '核对任务能否直接开始' },
    { title: '保存', description: '写入本机学习计划' },
    { title: '更新', description: '通知首页与服务卡片' }
  ];

  onPageShow(): void {
    this.lifecycleRunId += 1;
    this.pageActive = true;
    this.loadPlan();
  }

  onPageHide(): void {
    this.pageActive = false;
    this.lifecycleRunId += 1;
    this.planReadRunId += 1;
    this.planLoading = false;
    if (this.loading && this.progressStep >= 3) return;
    this.cancelPlanGeneration(false);
  }

  onBackPress(): boolean {
    if (this.updatingTaskId.length > 0) {
      this.message = '任务状态正在保存到本机，请稍候';
      this.hasError = false;
      return true;
    }
    if (this.loading && this.progressStep >= 3) {
      this.message = '计划正在保存到本机，请稍候';
      this.hasError = false;
      return true;
    }
    this.cancelPlanGeneration(false);
    return false;
  }

  get canGenerate(): boolean {
    return !this.loading && !this.planLoading && this.updatingTaskId.length === 0 &&
      this.goal.trim().length > 0;
  }

  private taskTypeLabel(type: string): string {
    if (type === 'review') return '复习';
    if (type === 'practice') return '练习';
    if (type === 'reading') return '阅读';
    if (type === 'quiz') return '测验';
    return type;
  }

  private courseTitle(courseId?: string): string {
    if (courseId === 'cs102') return '操作系统';
    if (courseId === 'cs103') return '计算机网络';
    return '数据结构';
  }

  private actionLabel(task: PlanTask): string {
    if (task.action === 'lesson') return '学习';
    if (task.action === 'practice') return '练习';
    if (task.action === 'quiz') return '测验';
    if (task.action === 'review') return '复盘';
    return this.taskTypeLabel(task.type);
  }

  private hasTaskTarget(task: PlanTask): boolean {
    return task.courseId !== undefined && task.courseId.length > 0 &&
      task.topic !== undefined && task.topic.length > 0;
  }

  private openTask(task: PlanTask): void {
    if (this.updatingTaskId.length > 0) {
      this.message = '任务状态正在保存到本机，请稍候';
      this.hasError = false;
      return;
    }
    if (!this.hasTaskTarget(task)) {
      this.message = '旧计划缺少课程主题，请重新生成可执行计划';
      this.hasError = true;
      this.retryAction = 'none';
      this.clearErrorEvidence();
      return;
    }
    const courseId = task.courseId ?? 'cs101';
    const topic = task.topic ?? '';
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(courseId));
    if (task.action === 'quiz' || task.type === 'quiz') {
      AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
      this.pushPage('pages/Quiz');
      return;
    }
    if (task.action === 'practice' || task.action === 'review' || task.type === 'practice' || task.type === 'review') {
      AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
      this.pushPage('pages/Practice');
      return;
    }
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.pushPage('pages/Lesson');
  }

  private pushPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((): void => {
      this.message = '无法打开学习环节，请稍后重试';
      this.hasError = true;
      this.retryAction = 'none';
      this.clearErrorEvidence();
    });
  }

  private async loadPlan(): Promise<void> {
    if (this.pendingPlan !== null && this.retryAction === 'save') {
      this.planLoading = false;
      return;
    }
    if (this.loading) {
      this.planLoading = false;
      return;
    }
    if (this.updatingTaskId.length > 0) {
      this.planLoading = false;
      return;
    }
    const readRunId = this.planReadRunId + 1;
    this.planReadRunId = readRunId;
    this.planLoading = true;
    this.message = '';
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
    try {
      const plan = await LocalLearningRepository.getPlan();
      if (this.planReadRunId !== readRunId || this.loading) return;
      if (plan !== null) {
        if (!this.hasLoadedPlanOnce) {
          this.goal = plan.goal;
        }
        this.savedPlanGoal = plan.goal;
        this.tasks = plan.tasks;
        this.agentTrace = (plan as AgentStudyPlan).agentTrace ?? [];
      }
      this.hasLoadedPlanOnce = true;
      this.message = '';
      this.hasError = false;
    } catch (e) {
      if (this.planReadRunId !== readRunId || this.loading) return;
      this.message = '本机计划读取失败，请重新读取';
      this.hasError = true;
      this.retryAction = 'load';
    } finally {
      if (this.planReadRunId === readRunId && !this.loading) {
        this.planLoading = false;
      }
    }
  }

  private async toggleTask(task: PlanTask): Promise<void> {
    if (this.updatingTaskId.length > 0 || this.loading || this.planLoading) return;
    const taskId = task.id;
    const desiredDone = !Boolean(task.done);
    const feedbackLifecycleRunId = this.lifecycleRunId;
    let receipt: PlanTaskUpdateReceipt | null = null;
    this.updatingTaskId = taskId;
    try {
      receipt = await LocalLearningRepository.updatePlanTask(taskId, desiredDone);
      this.tasks = receipt.plan.tasks;
      this.message = receipt.task.done === true ? '任务已完成，进度已保存到本机' : '任务已恢复为待完成';
      this.hasError = false;
      this.retryAction = 'none';
      this.clearErrorEvidence();
    } catch (e) {
      this.message = '任务状态保存失败，请稍后重试';
      this.hasError = true;
      this.retryAction = 'none';
      this.clearErrorEvidence();
    } finally {
      if (this.updatingTaskId === taskId) {
        this.updatingTaskId = '';
      }
    }
    if (receipt === null) return;
    try {
      await LearningFormUpdater.refreshAll();
    } catch (_) {
    }
    let studyEventSaved: boolean = true;
    if (receipt.changed && receipt.task.done === true) {
      const event: StudyEvent = {
        id: 'event_' + Date.now().toString(),
        type: 'task_completed',
        timestamp: new Date().toISOString(),
        taskId: taskId
      };
      try {
        await LocalLearningRepository.appendStudyEvent(event);
      } catch (_) {
        studyEventSaved = false;
      }
    }
    if (!this.pageActive || this.lifecycleRunId !== feedbackLifecycleRunId) return;
    if (!studyEventSaved) {
      this.message = '任务已完成并保存，学习记录暂未更新';
      this.hasError = true;
    }
  }

  @Builder
  PlanSkeleton() {
    Column({ space: 10 }) {
      ForEach([1, 2, 3], (_: number): void => {
        Row({ space: 12 }) {
          Column().width(34).height(34).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(17)
          Column({ space: 8 }) {
            Column().width('70%').height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width('45%').height(12).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(4)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
      })
    }
    .width('100%')
  }

  @Builder
  GoalSuggestions() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.goalSuggestions, (suggestion: string): void => {
        Button(suggestion)
          .constraintSize({ minHeight: 48 })
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .fontSize(12)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .margin({ right: 6, bottom: 6 })
          .enabled(!this.loading && !this.planLoading && this.retryAction !== 'save')
          .accessibilityText('使用建议目标：' + suggestion)
          .accessibilityDescription('填入学习目标输入框')
          .onClick((): void => { this.goal = suggestion; })
      })
    }
    .width('100%')
  }

  private taskReason(task: PlanTask): string {
    const reason = (task as AgentPlanTask).reason ?? '';
    return reason.trim().length > 0 ? reason.trim() : '学伴根据目标拆出的可执行下一步';
  }

  private durationAccessibilityText(option: number): string {
    return (this.days === option ? '已选择学习周期：' : '选择学习周期：') + option.toString() + ' 天';
  }

  private generateAccessibilityText(): string {
    if (this.loading) return '正在生成学习计划';
    if (this.planLoading) return '正在恢复本机计划';
    if (this.updatingTaskId.length > 0) return '任务状态保存中，暂不能生成学习计划';
    if (this.retryAction === 'save') return '请先保存刚生成的计划';
    if (this.goal.trim().length === 0) return '请先输入学习目标';
    return '生成学习计划';
  }

  private shouldAdjustPlanInput(): boolean {
    if (this.errorCode === 'SAFETY_BLOCKED' || this.errorCode === 'INPUT_REJECTED' ||
      this.errorCode === 'GOAL_TOO_LONG' || this.errorCode === 'INVALID_DURATION' ||
      this.errorCode === 'INVALID_DAILY_MINUTES') return true;
    return this.errorHttpStatus >= 400 && this.errorHttpStatus < 500 && this.errorHttpStatus !== 429;
  }

  private retryAccessibilityText(): string {
    if (this.retryAction === 'load') return '重新读取本机计划';
    if (this.retryAction === 'save') return '保存刚生成的学习计划';
    if (this.retryAction === 'generate' && this.shouldAdjustPlanInput()) return '调整学习目标后重新生成';
    if (this.retryAction === 'generate') return '重新生成学习计划';
    return '重试学习计划操作';
  }

  private beginPlanAdjustment(): void {
    this.editorExpanded = true;
    this.message = '';
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
  }

  private checkpointAccessibilityText(title: string, detail: string, index: number): string {
    const state = this.progressStep > index ? '已完成' : (this.progressStep === index ? '进行中' : '未开始');
    return title + '，' + state + '。' + detail;
  }

  private taskAccessibilityText(task: PlanTask): string {
    const state = task.done ? '已完成' : '待完成';
    const target = this.hasTaskTarget(task) ?
      this.courseTitle(task.courseId) + '，' + (task.topic ?? '') : '学习入口需要重新生成';
    return state + '计划任务：' + task.title + '。' + target + '。' + this.taskReason(task) + '。' +
      task.date + '，预计 ' + task.estimatedMin.toString() + ' 分钟，' + this.taskTypeLabel(task.type);
  }

  private savedPlanLabel(): string {
    if (this.savedPlanGoal.trim().length === 0) return '上一版计划';
    const label = this.savedPlanGoal.trim();
    return '上一版“' + (label.length > 24 ? label.slice(0, 24) + '…' : label) + '”计划';
  }

  private clearErrorEvidence(): void {
    this.errorHttpStatus = 0;
    this.errorCode = '';
    this.errorExpanded = false;
  }

  private readablePlanTrace(trace: string): string {
    if (trace.startsWith('Profile Agent')) return '已结合你的学习阶段、习惯和薄弱项';
    if (trace.startsWith('Planner Agent')) return '已从现有课程主题中安排可完成的任务';
    if (trace.startsWith('Action Router')) return '每项任务都能直接进入学习、练习、测验或复盘';
    if (trace.startsWith('Local-first Guard')) return '计划与完成状态只保存在本机';
    return trace;
  }

  private dismissGoalInput(): void {
    try {
      this.goalInputController.stopEditing();
    } catch (e) {
      // 输入框可能尚未完成挂载；不影响后续生成。
    }
  }

  private goBack(): void {
    this.dismissGoalInput();
    if (this.updatingTaskId.length > 0) {
      this.message = '任务状态正在保存到本机，请稍候';
      this.hasError = false;
      return;
    }
    if (this.loading && this.progressStep >= 3) {
      this.message = '计划正在保存到本机，请稍候';
      this.hasError = false;
      return;
    }
    this.cancelPlanGeneration(false);
    this.getUIContext().getRouter().back();
  }

  private isActiveGeneration(runId: number, lifecycleRunId: number,
    request: HttpRequestCancellation): boolean {
    return this.pageActive && this.lifecycleRunId === lifecycleRunId && this.loading &&
      this.generationRunId === runId && this.activeRequest === request && !request.isCancelled();
  }

  private cancelPlanGeneration(showMessage: boolean = true): void {
    if (!this.loading || this.progressStep >= 3) return;
    const hadSavedPlan = this.tasks.length > 0;
    this.generationRunId += 1;
    const request = this.activeRequest;
    this.activeRequest = null;
    if (request !== null) request.cancel();
    this.loading = false;
    this.progressStep = 0;
    this.progressTick = 0;
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
    if (showMessage) {
      this.message = hadSavedPlan ? '已取消生成，' + this.savedPlanLabel() + '仍可继续执行' :
        '已取消生成，学习目标和周期仍然保留';
    }
  }

  private planSavedMessage(): string {
    return '计划已保存到本机，首页已更新；已发起服务卡片更新';
  }

  private async persistGeneratedPlan(plan: AgentStudyPlan): Promise<boolean> {
    try {
      await LocalLearningRepository.savePlan(plan);
    } catch (_) {
      const retained = this.tasks.length > 0 ? '；' + this.savedPlanLabel() + '仍可继续执行' : '';
      this.message = '计划已生成，但未能保存到本机' + retained;
      this.hasError = true;
      this.retryAction = 'save';
      this.clearErrorEvidence();
      return false;
    }

    this.tasks = plan.tasks;
    this.savedPlanGoal = plan.goal;
    this.agentTrace = plan.agentTrace ?? [];
    this.evidenceExpanded = false;
    this.collapsedDays = [];
    this.expandedFutureDays = [];
    this.pendingPlan = null;
    this.progressStep = 4;
    try {
      await LearningFormUpdater.refreshAll();
    } catch (_) {
    }
    this.message = this.planSavedMessage();
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
    return true;
  }

  private async retryPendingPlanSave(): Promise<void> {
    if (this.loading || this.updatingTaskId.length > 0 || this.pendingPlan === null) return;
    this.generationRunId += 1;
    this.activeRequest = null;
    this.loading = true;
    this.progressStep = 3;
    this.progressTick = 0;
    this.message = '';
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
    try {
      await this.persistGeneratedPlan(this.pendingPlan);
    } finally {
      this.loading = false;
    }
  }

  private cleanText(value?: string): string {
    return typeof value === 'string' ? value.trim() : '';
  }

  private localDateKey(date: Date = new Date()): string {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private taskDays(): string[] {
    const days: string[] = [];
    for (const task of this.tasks) {
      if (!days.includes(task.date)) days.push(task.date);
    }
    const today = this.localDateKey();
    return days.sort((left: string, right: string): number => {
      if (left === today) return -1;
      if (right === today) return 1;
      if (left < today && right < today) return right.localeCompare(left);
      if (left < today) return -1;
      if (right < today) return 1;
      return left.localeCompare(right);
    });
  }

  private tasksForDay(day: string): PlanTask[] {
    return this.tasks.filter((task: PlanTask): boolean => task.date === day);
  }

  private isDayExpanded(day: string): boolean {
    if (this.collapsedDays.includes(day)) return false;
    if (this.expandedFutureDays.includes(day)) return true;
    return day === this.localDateKey();
  }

  private toggleDay(day: string): void {
    if (this.isDayExpanded(day)) {
      this.expandedFutureDays = this.expandedFutureDays.filter((value: string): boolean => value !== day);
      this.collapsedDays = [...this.collapsedDays, day];
    } else {
      this.collapsedDays = this.collapsedDays.filter((value: string): boolean => value !== day);
      this.expandedFutureDays = [...this.expandedFutureDays, day];
    }
  }

  private dayLabel(day: string): string {
    if (day === this.localDateKey()) return '今天 · ' + day.slice(5, 7) + '月' + day.slice(8) + '日';
    if (day < this.localDateKey()) return '此前 · ' + day.slice(5, 7) + '月' + day.slice(8) + '日';
    return day.slice(5, 7) + '月' + day.slice(8) + '日';
  }

  private daySummary(day: string): string {
    const tasks = this.tasksForDay(day);
    const pending = tasks.filter((task: PlanTask): boolean => task.done !== true).length;
    if (pending === 0) return tasks.length.toString() + ' 项已完成';
    return pending.toString() + ' 项待做 · 共 ' + tasks.length.toString() + ' 项';
  }

  private validCourseId(courseId: string): boolean {
    return courseId === 'cs101' || courseId === 'cs102' || courseId === 'cs103';
  }

  private validTaskType(type: string): boolean {
    return type === 'review' || type === 'practice' || type === 'reading' || type === 'quiz';
  }

  private validTaskAction(action: string): boolean {
    return action === 'lesson' || action === 'practice' || action === 'quiz' || action === 'review';
  }

  private validDateText(date: string): boolean {
    if (date.length !== 10) return false;
    return date.charAt(4) === '-' && date.charAt(7) === '-' &&
      !Number.isNaN(Number(date.slice(0, 4))) &&
      !Number.isNaN(Number(date.slice(5, 7))) &&
      !Number.isNaN(Number(date.slice(8, 10)));
  }

  private topicExists(courseId: string, topic: string): boolean {
    return LearningContentRepository.getTopics(courseId).includes(topic);
  }

  private planTrace(agentTrace?: string[]): string[] {
    const traces: string[] = [];
    const source = Array.isArray(agentTrace) ? agentTrace : [];
    for (const item of source) {
      const text = this.cleanText(item);
      if (text.length > 0 && !traces.includes(text)) {
        traces.push(text.slice(0, 140));
      }
    }
    return traces.slice(0, 6);
  }

  private validatePlanResponse(response: AgentStudyPlan | null): PlanValidationResult {
    const invalid: PlanValidationResult = {
      valid: false,
      message: '返回的计划无法直接执行，请重新生成',
      plan: null
    };
    if (response === null) return invalid;
    const planId = this.cleanText(response.planId);
    const userId = this.cleanText(response.userId);
    const goal = this.cleanText(response.goal);
    if (planId.length === 0 || userId.length === 0 || goal.length === 0 || !Array.isArray(response.tasks) ||
      response.tasks.length === 0) {
      return invalid;
    }

    const taskIds: string[] = [];
    const tasks: PlanTask[] = [];
    for (const source of response.tasks) {
      const id = this.cleanText(source.id);
      const title = this.cleanText(source.title);
      const date = this.cleanText(source.date);
      const type = this.cleanText(source.type);
      const courseId = this.cleanText(source.courseId);
      const topic = this.cleanText(source.topic);
      const action = this.cleanText(source.action);
      const reason = this.cleanText((source as AgentPlanTask).reason);
      const estimatedMin = Number(source.estimatedMin);
      if (id.length === 0 || taskIds.includes(id) || title.length === 0 || !this.validDateText(date) ||
        !this.validTaskType(type) || !this.validCourseId(courseId) || topic.length === 0 ||
        !this.topicExists(courseId, topic) || !this.validTaskAction(action) ||
        Number.isNaN(estimatedMin) || estimatedMin < 15 || estimatedMin > 180) {
        return invalid;
      }
      taskIds.push(id);
      const task: PlanTask = {
        id: id,
        title: title,
        date: date,
        estimatedMin: Math.round(estimatedMin),
        type: type,
        courseId: courseId,
        topic: topic,
        action: action,
        reason: reason.length > 0 ? reason : '学伴根据目标拆出的可执行下一步',
        done: source.done === true
      } as AgentPlanTask;
      tasks.push(task);
    }

    const plan: AgentStudyPlan = {
      planId: planId,
      userId: userId,
      goal: goal,
      tasks: tasks,
      agentTrace: this.planTrace(response.agentTrace)
    };
    return {
      valid: true,
      message: '',
      plan: plan
    };
  }

  private runWaitClock(runId: number): void {
    this.progressStep = 0;
    this.progressTick = 0;
    setTimeout((): void => {
      if (this.loading && this.generationRunId === runId) {
        this.progressTick = 1;
      }
    }, 10000);
    setTimeout((): void => {
      if (this.loading && this.generationRunId === runId) {
        this.progressTick = 2;
      }
    }, 30000);
    setTimeout((): void => {
      if (this.loading && this.generationRunId === runId) {
        this.progressTick = 3;
      }
    }, 60000);
  }

  private currentPlanStepIndex(): number {
    return Math.min(Math.max(this.progressStep, 0), this.planSteps.length - 1);
  }

  @Builder
  PlanProgress() {
    StagedProgress(
      this.planProgressTitle(),
      this.planProgressSubtitle(),
      this.currentPlanStepIndex(),
      this.planSteps
    )
  }

  private planProgressTitle(): string {
    if (this.progressStep >= 4) return '正在更新学习入口';
    if (this.progressStep === 3) return '正在保存到本机';
    if (this.progressStep === 2) return '正在检查每项任务';
    if (this.progressStep === 1) return '正在在线安排学习节奏';
    return '正在读取本机学习状态';
  }

  private planProgressSubtitle(): string {
    if (this.progressStep >= 4) return '本机计划已写入，正在通知首页与服务卡片刷新';
    if (this.progressStep === 3) return '任务已通过检查，正在写入本机学习计划';
    if (this.progressStep === 2) return '核对日期、课程主题、入口和预计时长';
    if (this.progressStep === 1) return '等待学伴从已有课程主题中安排每天的任务';
    return '读取本机薄弱项与学习习惯，私人学习状态不会在云端保存';
  }

  private planWaitHint(): string {
    if (this.progressStep >= 4) return '计划已保存，正在更新学习入口，请不要关闭页面。';
    if (this.progressStep === 3) return '计划正在写入本机，此时不会再中断保存。';
    if (this.progressStep === 2) return '计划已返回，正在确认每项任务都能直接开始。';
    if (this.progressTick >= 3) return '规划需要更多时间。你可以继续等待，也可以取消后调整目标。';
    if (this.progressTick >= 2) return '学伴仍在安排日期和任务入口，完成后会自动保存。';
    if (this.progressTick >= 1) return '计划仍在生成中，页面没有卡住。';
    if (this.days >= 21) return '周期较长，需要检查更多主题和日期，通常会多等一会儿。';
    return '保持在当前页，计划生成后会直接展示可点击任务。';
  }

  private planRequestSummary(): string {
    return this.goal.trim() + ' · ' + this.days.toString() + ' 天 · 每天 90 分钟';
  }

  private planErrorMessage(error: Error): string {
    const code = error instanceof HttpStatusError ? error.errorCode : '';
    const retained = this.tasks.length > 0 ? '，上一版计划仍可继续执行' : '';
    if (code === 'MODEL_UNAVAILABLE') return '在线规划暂不可用，不会用本地模板代替' + retained;
    if (code === 'MODEL_TIMEOUT') return '规划等待超时，目标和周期已保留' + retained;
    if (code === 'MODEL_INVALID_RESPONSE') return '返回的计划无法正常显示，请重新生成' + retained;
    if (code === 'SAFETY_BLOCKED') return '计划内容未通过安全检查，请换一种目标描述再试' + retained;
    if (code === 'INPUT_REJECTED') return '目标或学习状态未通过安全检查，请调整后重新生成' + retained;
    if (code === 'GOAL_TOO_LONG') return '学习目标太长，请压缩到 500 字以内' + retained;
    if (code === 'INVALID_DURATION' || code === 'INVALID_DAILY_MINUTES') {
      return '选择的周期不符合要求，请重新选择后再试' + retained;
    }
    if (error instanceof HttpStatusError && error.statusCode === 429) return '请求较多，请稍后重试' + retained;
    if (error instanceof HttpStatusError && error.statusCode >= 400 && error.statusCode < 500) {
      return '目标或学习状态不符合要求，请调整后重试' + retained;
    }
    if (error instanceof HttpStatusError) return '在线规划暂时失败，请稍后重试' + retained;
    return '在线规划暂不可用，请稍后重试' + retained;
  }

  @Builder
  PlanCheckpoint(title: string, detail: string, index: number) {
    Row({ space: 9 }) {
      Text(this.progressStep > index ? '✓' : (this.progressStep === index ? '…' : '·'))
        .width(22)
        .height(22)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.progressStep > index ? Constants.COLOR_TEXT_ON_GRADIENT :
          (this.progressStep === index ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER))
        .textAlign(TextAlign.Center)
        .backgroundColor(this.progressStep > index ? Constants.COLOR_BRAND :
          (this.progressStep === index ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_PROGRESS_TRACK))
        .borderRadius(11)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.progressStep >= index ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_PLACEHOLDER)
        Text(detail)
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText(this.checkpointAccessibilityText(title, detail, index))
  }

  @Builder
  PlanLoadingState() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.calendar_badge_plus'))
          .width(42)
          .height(42)
          .fontSize(22)
          .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(21)
        Column({ space: 4 }) {
          Text('正在生成学习计划')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.planRequestSummary())
            .fontSize(12)
            .lineHeight(18)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button('取消')
          .constraintSize({ minHeight: 48 })
          .padding({ left: 14, right: 14 })
          .fontSize(12)
          .fontColor(Constants.COLOR_ERROR)
          .backgroundColor(Constants.COLOR_ERROR_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.progressStep < 3)
          .accessibilityText('取消生成学习计划')
          .accessibilityDescription(this.tasks.length > 0 ? '保留上一版计划并停止本次生成' : '停止本次计划生成')
          .onClick((): void => { this.cancelPlanGeneration(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.PlanProgress()

      if (this.tasks.length > 0) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(17)
            .fontColor([Constants.COLOR_SUCCESS])
          Text(this.savedPlanLabel() + '已保留，取消或失败后仍可继续执行')
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(18)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
      }

      Column({ space: 9 }) {
        this.PlanCheckpoint('本机状态', '读取薄弱项、连续学习和练习表现', 0)
        this.PlanCheckpoint('在线规划', '从已有课程主题中安排每天的任务', 1)
        this.PlanCheckpoint('任务检查', '检查日期、课程入口和预计时长', 2)
        this.PlanCheckpoint('本机保存', '写入计划并保留已有学习数据', 3)
        this.PlanCheckpoint('入口更新', '通知首页与服务卡片刷新', 4)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)

      Row({ space: 8 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(Constants.COLOR_BRAND)
        Text(this.planWaitHint())
          .layoutWeight(1)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
      .borderRadius(Constants.RADIUS_MD)

      this.PlanSkeleton()
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  AgentTraceCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.calendar_fill'))
          .fontSize(19)
          .fontColor([Constants.COLOR_BRAND])
        Column({ space: 3 }) {
          Text('规划依据')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('已检查学习状态、课程主题和任务入口')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.evidenceExpanded ? '收起' : this.agentTrace.length.toString() + ' 条')
          .fontSize(11)
          .fontColor(Constants.COLOR_BRAND)
        SymbolGlyph($r(this.evidenceExpanded ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([Constants.COLOR_BRAND])
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .alignItems(VerticalAlign.Center)
      .focusable(true)
      .accessibilityText((this.evidenceExpanded ? '收起' : '展开') + '规划依据，共 ' +
        this.agentTrace.length.toString() + ' 条')
      .accessibilityDescription('查看学习状态、课程主题和任务入口的检查结果')
      .onClick((): void => { this.evidenceExpanded = !this.evidenceExpanded; })
      if (this.evidenceExpanded) {
        ForEach(this.agentTrace, (trace: string, index: number): void => {
          Row({ space: 9 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column().width(22).height(22).backgroundColor(Constants.COLOR_SUCCESS_LIGHT).borderRadius(11)
              Text((index + 1).toString())
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_SUCCESS)
            }
            Text(this.readablePlanTrace(trace))
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(Constants.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 16 })
    .constraintSize({ maxWidth: 760 })
  }

  build() {
    Column() {
      GradientHeader('学习计划', '输入目标，自动拆解为每日任务', () => this.goBack())

      if (!this.loading && !this.planLoading) {
        if (this.tasks.length === 0 || this.editorExpanded) {
          Column({ space: 14 }) {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Text('学习目标')
                .layoutWeight(1)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              if (this.tasks.length > 0) {
                Button('收起编辑')
                  .constraintSize({ minHeight: 48 })
                  .padding({ left: 14, right: 14 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_BRAND)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(Constants.RADIUS_MD)
                  .accessibilityText('收起计划目标与周期编辑')
                  .accessibilityDescription('返回当前任务列表')
                  .onClick((): void => { this.editorExpanded = false; })
              }
            }
            .width('100%')
            TextInput({
              text: $$this.goal,
              controller: this.goalInputController,
              placeholder: '例如：两周复习数据结构'
            })
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .fontSize(14)
              .backgroundColor(Constants.COLOR_SURFACE_TINT)
              .borderRadius(Constants.RADIUS_MD)
              .enabled(!this.loading && !this.planLoading && this.retryAction !== 'save')
              .accessibilityText('输入学习目标')
              .accessibilityDescription('最多 500 字，输入后可生成每日学习任务')
              .maxLength(500)
              .enterKeyType(EnterKeyType.Done)
              .onChange((v: string) => { this.goal = v; })
              .onSubmit((_enterKey: EnterKeyType, event: SubmitEvent): void => {
                this.goal = event.text;
                this.generate();
                this.editorExpanded = false;
              })
          this.GoalSuggestions()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('学习周期')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .width('100%')
            Row({ space: 8 }) {
              ForEach(this.durationOptions, (option: number) => {
                Button(option.toString() + ' 天')
                  .layoutWeight(1)
                  .constraintSize({ minHeight: 48 })
                  .fontSize(13)
                  .fontColor(this.days === option ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
                  .backgroundColor(this.days === option ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
                  .borderRadius(Constants.RADIUS_MD)
                  .enabled(!this.loading && !this.planLoading && this.updatingTaskId.length === 0 &&
                    this.retryAction !== 'save')
                  .accessibilityText(this.durationAccessibilityText(option))
                  .accessibilityDescription(this.days === option ? '当前已选择' : '选择该学习周期')
                  .onClick(() => {
                    this.days = option;
                  })
              })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Button() {
            Row({ space: 8 }) {
              if (this.loading) {
                LoadingProgress().width(18).height(18).color(Constants.COLOR_TEXT_SECONDARY)
              } else {
                SymbolGlyph($r('sys.symbol.rays'))
                  .fontSize(18)
                  .fontColor([this.canGenerate ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT])
              }
              Text(this.loading ? '正在生成计划' : '生成学习计划')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.canGenerate ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .backgroundColor(this.canGenerate ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.canGenerate && this.retryAction !== 'save')
          .accessibilityText(this.generateAccessibilityText())
          .accessibilityDescription('根据目标和学习周期生成可执行任务并保存到本机')
          .onClick(() => {
            this.editorExpanded = false;
            this.generate();
          })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_LG)
          .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
          .margin({ left: 16, right: 16, bottom: 16 })
          .constraintSize({ maxWidth: 760 })
        } else {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('当前目标')
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              Text(this.savedPlanGoal.trim().length > 0 ? this.savedPlanGoal : this.goal)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          Button('调整目标与周期')
            .constraintSize({ minHeight: 48 })
            .padding({ left: 12, right: 12 })
            .fontSize(13)
            .fontColor(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(!this.loading && !this.planLoading && this.updatingTaskId.length === 0 &&
              this.retryAction !== 'save')
            .accessibilityText('调整当前计划的目标与周期')
            .accessibilityDescription('展开计划编辑器，当前任务在保存新计划前保持不变')
            .onClick((): void => { this.editorExpanded = true; })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding(12)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_LG)
          .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
          .margin({ left: 16, right: 16, bottom: 8 })
          .constraintSize({ maxWidth: 760 })
        }
      }

      if (this.message.length > 0) {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r(this.hasError ? 'sys.symbol.xmark_circle_fill' : 'sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_SUCCESS])
            Text(this.message)
              .layoutWeight(1)
              .fontSize(12)
              .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            if (this.retryAction !== 'none') {
              Button(this.retryAction === 'load' ? '重新读取' :
                (this.retryAction === 'save' ? '保存刚生成的计划' :
                  (this.shouldAdjustPlanInput() ? '调整目标' : '重新生成')))
                .constraintSize({ minHeight: 48 })
                .padding({ left: 14, right: 14 })
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
                .enabled(!this.loading && !this.planLoading && this.updatingTaskId.length === 0)
                .accessibilityText(this.retryAccessibilityText())
                .accessibilityDescription(this.message)
                .onClick(() => {
                  if (this.retryAction === 'load') this.loadPlan();
                  else if (this.retryAction === 'save') this.retryPendingPlanSave();
                  else if (this.shouldAdjustPlanInput()) this.beginPlanAdjustment();
                  else this.generate();
                })
            }
          }
          .width('100%')

          if (this.hasError && (this.errorHttpStatus > 0 || this.errorCode.length > 0)) {
            Row({ space: 4 }) {
              Text(this.errorExpanded ? '收起错误详情' : '查看错误详情')
                .fontSize(11)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              SymbolGlyph($r(this.errorExpanded ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
                .fontSize(11)
                .fontColor([Constants.COLOR_TEXT_SECONDARY])
            }
            .constraintSize({ minHeight: 48 })
            .focusable(true)
            .accessibilityText(this.errorExpanded ? '收起计划错误详情' : '展开计划错误详情')
            .accessibilityDescription('查看 HTTP 状态和错误代码')
            .onClick((): void => { this.errorExpanded = !this.errorExpanded; })

            if (this.errorExpanded) {
              Column({ space: 3 }) {
                if (this.errorHttpStatus > 0) {
                  Text('HTTP 状态：' + this.errorHttpStatus.toString())
                    .width('100%')
                    .fontSize(10)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                if (this.errorCode.length > 0) {
                  Text('错误代码：' + this.errorCode)
                    .width('100%')
                    .fontSize(10)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_SM)
            }
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 10 })
        .constraintSize({ maxWidth: 760 })
      }

      if (this.hasError && (this.retryAction === 'generate' || this.retryAction === 'save') &&
        this.tasks.length > 0) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(16)
            .fontColor([Constants.COLOR_SUCCESS])
          Text(this.retryAction === 'save' ? this.savedPlanLabel() + '未被替换，可以继续执行或重试保存' :
            this.savedPlanLabel() + '未被替换，可以继续执行或重新生成')
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(18)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 12 })
        .constraintSize({ maxWidth: 760 })
      }

      if (this.loading) {
        Scroll() {
          Column() {
            this.PlanLoadingState()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 + SafeAreaInsets.bottomVp() })
          .constraintSize({ maxWidth: 760 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else if (this.planLoading) {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(Constants.COLOR_BRAND)
              Text('正在恢复本机计划')
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            this.PlanSkeleton()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 + SafeAreaInsets.bottomVp() })
          .constraintSize({ maxWidth: 760 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else if (this.tasks.length > 0) {
        List({ space: 8 }) {
          ForEach(this.taskDays(), (day: string): void => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(this.dayLabel(day))
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(day === this.localDateKey() ? Constants.COLOR_MAP_CORE : Constants.COLOR_TEXT_PRIMARY)
                    Text(this.daySummary(day))
                      .fontSize(12)
                      .fontColor(day === this.localDateKey() ? Constants.COLOR_MAP_TEXT_MUTED : Constants.COLOR_TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  SymbolGlyph($r(this.isDayExpanded(day) ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
                    .fontSize(16)
                    .fontColor([day === this.localDateKey() ? Constants.COLOR_MAP_CORE : Constants.COLOR_BRAND])
                }
                .width('100%')
                .constraintSize({ minHeight: 56 })
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(day === this.localDateKey() ? Constants.COLOR_MAP_SURFACE : Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_MD)
                .focusable(true)
                .accessibilityText(this.dayLabel(day) + '，' + this.daySummary(day) + '，' +
                  (this.isDayExpanded(day) ? '已展开' : '已折叠'))
                .accessibilityDescription('点击' + (this.isDayExpanded(day) ? '收起' : '展开') + '该日任务')
                .onClick((): void => { this.toggleDay(day); })
                if (this.isDayExpanded(day)) {
                  ForEach(this.tasksForDay(day), (t: PlanTask, i: number): void => {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(34)
                    .height(34)
                    .backgroundColor(t.done ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BRAND_LIGHT)
                    .borderRadius(17)
                  if (t.done) {
                    SymbolGlyph($r('sys.symbol.checkmark'))
                      .fontSize(16)
                      .fontColor([Constants.COLOR_SUCCESS])
                  } else {
                    Text((i + 1).toString())
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_BRAND)
                  }
                }

                Column() {
                  Text(t.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(t.done ? Constants.COLOR_TEXT_SECONDARY : Constants.COLOR_TEXT_PRIMARY)
                  Text((this.hasTaskTarget(t) ? this.courseTitle(t.courseId) + ' · ' + (t.topic ?? '') : '重新生成后可直达学习环节'))
                    .fontSize(11)
                    .fontColor(this.hasTaskTarget(t) ? Constants.COLOR_TEXT_SECONDARY : Constants.COLOR_WARNING)
                    .margin({ top: 5 })
                  Text(this.taskReason(t))
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                    .lineHeight(17)
                    .margin({ top: 5 })
                  Flex({ wrap: FlexWrap.Wrap }) {
                    Text(t.date)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .margin({ right: 8, bottom: 4 })
                    Text(t.estimatedMin.toString() + ' 分钟')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .margin({ right: 8, bottom: 4 })
                    Text(this.taskTypeLabel(t.type))
                      .fontSize(11)
                      .fontColor(Constants.COLOR_BRAND)
                      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                      .borderRadius(7)
                      .margin({ bottom: 4 })
                  }
                  .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .accessibilityGroup(true)
                .accessibilityText(this.taskAccessibilityText(t))

                Column({ space: 6 }) {
                  Button(this.actionLabel(t))
                    .constraintSize({ minWidth: 64, minHeight: 48 })
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .fontSize(12)
                    .fontColor(this.hasTaskTarget(t) ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
                    .backgroundColor(this.hasTaskTarget(t) ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
                    .borderRadius(Constants.RADIUS_SM)
                    .enabled(this.hasTaskTarget(t) && this.updatingTaskId.length === 0)
                    .accessibilityText(this.actionLabel(t) + '：' + t.title)
                    .accessibilityDescription('打开该计划任务对应的真实学习环节')
                    .onClick(() => { this.openTask(t); })
                  Button(this.updatingTaskId === t.id ? '保存中' : (t.done ? '恢复' : '完成'))
                    .constraintSize({ minWidth: 64, minHeight: 48 })
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .fontSize(12)
                    .fontColor(t.done ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                    .backgroundColor(t.done ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BG_TAG)
                    .borderRadius(Constants.RADIUS_SM)
                    .enabled(this.updatingTaskId.length === 0)
                    .accessibilityText((t.done ? '恢复待完成：' : '标记完成：') + t.title)
                    .accessibilityDescription('手动设置任务状态并保存到本机；这不代表通过测评')
                    .onClick(() => { this.toggleTask(t); })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
                  }, (task: PlanTask): string => task.id)
                }
              }
              .width('100%')
            }
          }, (day: string): string => day)
          if (this.agentTrace.length > 0) {
            ListItem() {
              this.AgentTraceCard()
            }
          }
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, bottom: 16 + SafeAreaInsets.bottomVp() })
        .constraintSize({ maxWidth: 760 })
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(46)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('从一个清晰目标开始')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('选择周期后，学伴会把目标拆成每天可完成的任务')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 28, right: 28, bottom: 24 + SafeAreaInsets.bottomVp() })
        .constraintSize({ maxWidth: 760 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async generate(): Promise<void> {
    const requestedGoal = this.goal.trim();
    const requestedDays = this.days;
    if (requestedGoal.length === 0 || this.loading || this.planLoading ||
      this.updatingTaskId.length > 0 || !this.pageActive) return;
    const lifecycleRunId = this.lifecycleRunId;
    const runId = this.generationRunId + 1;
    this.generationRunId = runId;
    const request = new HttpRequestCancellation();
    this.activeRequest = request;
    this.pendingPlan = null;
    this.dismissGoalInput();
    this.loading = true;
    this.message = '';
    this.hasError = false;
    this.retryAction = 'none';
    this.clearErrorEvidence();
    this.runWaitClock(runId);
    try {
      const profile = await LocalLearningRepository.getProfile();
      if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;
      this.progressStep = 1;
      const req: PlanRequest = {
        userId: Constants.DEMO_USER_ID,
        goal: requestedGoal,
        durationDays: requestedDays,
        dailyMinutes: 90,
        startDate: this.localDateKey(),
        profile: profile ?? undefined
      };
      const response = await HttpClient.post<AgentStudyPlan>(Constants.API_PLAN, JSON.stringify(req), request);
      if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;
      this.progressStep = 2;
      const validation = this.validatePlanResponse(response);
      if (!validation.valid || validation.plan === null) {
        this.message = validation.message;
        this.hasError = true;
        this.retryAction = 'generate';
        this.clearErrorEvidence();
        return;
      }
      const plan = validation.plan;
      this.pendingPlan = plan;
      this.progressStep = 3;
      await this.persistGeneratedPlan(plan);
    } catch (e) {
      if (!this.isActiveGeneration(runId, lifecycleRunId, request)) return;
      const error = e instanceof Error ? e : new Error('Network request failed');
      const retained = this.tasks.length > 0 ? '，上一版计划仍可继续执行' : '';
      this.message = this.progressStep === 0 ? '本机学习状态读取失败，请稍后重试' + retained :
        this.planErrorMessage(error);
      this.hasError = true;
      this.retryAction = 'generate';
      if (error instanceof HttpStatusError) {
        this.errorHttpStatus = error.statusCode;
        this.errorCode = error.errorCode;
        this.errorExpanded = false;
      } else {
        this.clearErrorEvidence();
      }
    } finally {
      if (this.generationRunId === runId) {
        this.loading = false;
        this.activeRequest = null;
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
