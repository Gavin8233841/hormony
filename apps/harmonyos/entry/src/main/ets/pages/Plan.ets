/**
 * 学习计划页
 * 浅色主题 · 用户友好文案 · 任务列表
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader, StagedProgress, WorkStep } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { StudyPlan, PlanTask, PlanRequest } from '../model/DataModels';
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
  @State agentTrace: string[] = [];
  @State progressStep: number = 0;
  @State progressTick: number = 0;
  private durationOptions: number[] = [7, 14, 21];
  private goalSuggestions: string[] = ['两周复习数据结构', '一周掌握 TCP 基础', '三周准备操作系统考试'];
  private planSteps: WorkStep[] = [
    { title: '画像', description: '读取本地学习状态' },
    { title: '目录', description: '锁定真实 Topic' },
    { title: '编排', description: '生成可执行动作' },
    { title: '校验', description: '检查计划结构' },
    { title: '同步', description: '写入端侧计划' }
  ];

  aboutToAppear(): void {
    this.loadPlan();
  }

  get canGenerate(): boolean {
    return !this.loading && this.goal.trim().length > 0;
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
    if (!this.hasTaskTarget(task)) {
      this.message = '旧计划缺少课程主题，请重新生成可执行计划';
      this.hasError = true;
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
    });
  }

  private async loadPlan(): Promise<void> {
    try {
      const plan = await LocalLearningRepository.getPlan();
      if (plan !== null) {
        this.goal = plan.goal;
        this.tasks = plan.tasks;
        this.agentTrace = (plan as AgentStudyPlan).agentTrace ?? [];
      }
    } catch (e) {
      // 没有已保存计划时保留创建状态。
    }
  }

  private async toggleTask(task: PlanTask): Promise<void> {
    const nextDone = !Boolean(task.done);
    try {
      const nextTasks: PlanTask[] = [];
      for (const item of this.tasks) {
        if (item.id === task.id) {
          const updated: PlanTask = {
            id: item.id,
            title: item.title,
            date: item.date,
            estimatedMin: item.estimatedMin,
            type: item.type,
            courseId: item.courseId,
            topic: item.topic,
            action: item.action,
            reason: (item as AgentPlanTask).reason,
            done: nextDone
          } as AgentPlanTask;
          nextTasks.push(updated);
        } else {
          nextTasks.push(item);
        }
      }
      const current = await LocalLearningRepository.getPlan();
      if (current === null) throw new Error('本地计划不存在');
      current.tasks = nextTasks;
      await LocalLearningRepository.savePlan(current);
      await LearningFormUpdater.refreshAll();
      if (nextDone) {
        const event: StudyEvent = {
          id: 'event_' + Date.now().toString(),
          type: 'task_completed',
          timestamp: new Date().toISOString(),
          taskId: task.id
        };
        await LocalLearningRepository.appendStudyEvent(event);
      }
      this.tasks = nextTasks;
      this.message = nextDone ? '任务已完成，进度已保存到本机' : '任务已恢复为待完成';
      this.hasError = false;
    } catch (e) {
      this.message = '任务状态保存失败，请稍后重试';
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
    .padding({ left: 16, right: 16 })
  }

  private taskReason(task: PlanTask): string {
    const reason = (task as AgentPlanTask).reason ?? '';
    return reason.trim().length > 0 ? reason.trim() : '学伴根据目标拆出的可执行下一步';
  }

  private dismissGoalInput(): void {
    try {
      this.goalInputController.stopEditing();
    } catch (e) {
      // 输入框可能尚未完成挂载；不影响后续生成。
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
      message: '云端返回的计划未通过端侧可执行校验，请重新生成',
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

  private runLocalProgress(): void {
    this.progressStep = 0;
    this.progressTick = 0;
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 1;
        this.progressTick = 1;
      }
    }, 700);
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 2;
        this.progressTick = 2;
      }
    }, 2200);
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 3;
        this.progressTick = 3;
      }
    }, 5200);
    setTimeout((): void => {
      if (this.loading) {
        this.progressTick = 4;
      }
    }, 10000);
  }

  private currentPlanStepIndex(): number {
    return Math.min(Math.max(this.progressStep, 0), this.planSteps.length - 1);
  }

  private currentPlanStepDescription(): string {
    return this.planSteps[this.currentPlanStepIndex()].description;
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
    if (this.progressStep >= 4) return '正在同步到本机';
    if (this.progressStep === 3) return '正在校验可执行计划';
    if (this.progressStep === 2) return '正在编排学习节奏';
    if (this.progressStep === 1) return '正在匹配课程 Topic';
    return 'AI 正在读取学习画像';
  }

  private planProgressSubtitle(): string {
    if (this.progressStep >= 4) return '保存计划、刷新首页和服务卡片的今日任务';
    if (this.progressStep === 3) return '检查日期、课程、主题、动作和预计时长是否可直达';
    if (this.progressStep === 2) return '把目标拆成学习、练习、测验、复盘四类动作';
    if (this.progressStep === 1) return '只在当前 33 个真实 Topic 内选择，不让计划凭空造主题';
    return '读取本地画像、薄弱标签和学习风格，云端只生成计划不保存私有状态';
  }

  private planWaitHint(): string {
    if (this.progressTick >= 4) return '规划仍在云端生成中：页面没有卡住，完成后会自动写入本机计划。';
    if (this.days >= 21) return '周期越长，Planner Agent 会检查更多主题和日期，等待时间会更久。';
    return '保持在当前页，计划生成后会直接展示可点击任务。';
  }

  private planRequestSummary(): string {
    return this.goal.trim() + ' · ' + this.days.toString() + ' 天 · 每天 90 分钟';
  }

  private planErrorMessage(error: Error): string {
    const text = error.message;
    if (text.includes('MODEL_UNAVAILABLE')) return '云端模型未配置，计划不会用本地模板伪造。请稍后再试。';
    if (text.includes('MODEL_TIMEOUT')) return 'AI 规划超时了，目标和周期已保留，请稍后重试。';
    if (text.includes('MODEL_INVALID_RESPONSE')) return 'AI 返回的计划格式未通过校验，请重新生成一版。';
    if (text.includes('SAFETY_BLOCKED')) return '计划内容未通过安全审核，请换一种目标描述再试。';
    if (text.includes('INPUT_REJECTED')) return '目标或画像内容未通过安全检查，请调整后重新生成。';
    if (text.includes('GOAL_TOO_LONG')) return '学习目标太长，请压缩到 500 字以内。';
    if (text.includes('INVALID_DURATION') || text.includes('INVALID_DAILY_MINUTES')) {
      return '计划参数不符合云端边界，请重新选择周期后再试。';
    }
    if (text.startsWith('HTTP ')) return '云端规划暂时失败，未保存任何计划。请检查网络后重试。';
    return '云端学伴暂不可用，未生成任何计划';
  }

  @Builder
  PlanCheckpoint(title: string, detail: string, active: boolean) {
    Row({ space: 9 }) {
      Text(active ? '✓' : '·')
        .width(22)
        .height(22)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PLACEHOLDER)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? Constants.COLOR_BRAND : Constants.COLOR_BG_PROGRESS_TRACK)
        .borderRadius(11)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(active ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_PLACEHOLDER)
        Text(detail)
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
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
          Text('AI 正在生成学习计划')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.planRequestSummary())
            .fontSize(12)
            .lineHeight(18)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.PlanProgress()

      Column({ space: 9 }) {
        this.PlanCheckpoint('本地画像', '读取薄弱标签、连续学习和练习表现', this.progressStep >= 0)
        this.PlanCheckpoint('真实目录', '只从课程已有 Topic 中选择任务目标', this.progressStep >= 1)
        this.PlanCheckpoint('行动编排', '生成学习、练习、测验和复盘动作', this.progressStep >= 2)
        this.PlanCheckpoint('结构校验', '检查日期、课程、主题和时长边界', this.progressStep >= 3)
        this.PlanCheckpoint('端侧同步', '保存到本机并刷新首页今日任务', this.progressStep >= 4)
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
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  AgentTraceCard() {
    Column({ space: 12 }) {
      Row() {
        Text('Agent 工作链')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('可解释规划')
          .fontSize(11)
          .fontColor(Constants.COLOR_BRAND)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      ForEach(this.agentTrace, (trace: string, index: number): void => {
        Row({ space: 9 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column().width(22).height(22).backgroundColor(Constants.COLOR_SUCCESS_LIGHT).borderRadius(11)
            Text((index + 1).toString())
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_SUCCESS)
          }
          Text(trace)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(19)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 16 })
  }

  build() {
    Column() {
      GradientHeader('学习计划', '输入目标，自动拆解为每日任务', () => this.getUIContext().getRouter().back())

      Column({ space: 14 }) {
        Column({ space: 8 }) {
          Text('学习目标')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .width('100%')
          TextInput({ text: this.goal, placeholder: '例如：两周复习数据结构', controller: this.goalInputController })
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor(Constants.COLOR_SURFACE_TINT)
            .borderRadius(Constants.RADIUS_MD)
            .onChange((v: string) => { this.goal = v; })
            .onSubmit(() => { this.generate(); })
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
                .height(38)
                .fontSize(13)
                .fontColor(this.days === option ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
                .backgroundColor(this.days === option ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
                .borderRadius(Constants.RADIUS_MD)
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
              LoadingProgress().width(18).height(18).color(Constants.COLOR_TEXT_ON_GRADIENT)
            } else {
              SymbolGlyph($r('sys.symbol.rays'))
                .fontSize(18)
                .fontColor([this.canGenerate ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT])
            }
            Text(this.loading ? '正在' + this.currentPlanStepDescription() : '生成学习计划')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canGenerate || this.loading ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .height(44)
        .backgroundColor(this.canGenerate || this.loading ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
        .borderRadius(22)
        .enabled(this.canGenerate)
        .onClick(() => { this.generate(); })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
      .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
      .margin({ left: 16, right: 16, bottom: 16 })

      if (this.message.length > 0) {
        Row({ space: 8 }) {
          if (this.hasError) {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_ERROR])
          } else {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_SUCCESS])
          }
          Text(this.message)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.hasError) {
            Button('重试')
              .height(32)
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
              .onClick(() => { this.generate(); })
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 10 })
      }

      if (this.loading) {
        Column() {
          this.PlanLoadingState()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      } else if (this.tasks.length > 0) {
        if (this.agentTrace.length > 0) {
          this.AgentTraceCard()
        }
        Row() {
          Column() {
            Text('今日起步')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text(this.tasks.length.toString() + ' 项任务 · 每天约 90 分钟')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.calendar_fill'))
            .fontSize(26)
            .fontColor([Constants.COLOR_BRAND])
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 10 })

        List({ space: 8 }) {
          ForEach(this.tasks, (t: PlanTask, i: number) => {
            ListItem() {
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
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text((this.hasTaskTarget(t) ? this.courseTitle(t.courseId) + ' · ' + (t.topic ?? '') : '重新生成后可直达学习环节'))
                    .fontSize(11)
                    .fontColor(this.hasTaskTarget(t) ? Constants.COLOR_TEXT_SECONDARY : Constants.COLOR_WARNING)
                    .margin({ top: 5 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.taskReason(t))
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                    .lineHeight(17)
                    .margin({ top: 5 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 8 }) {
                    Text(t.date)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(t.estimatedMin.toString() + ' 分钟')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(this.taskTypeLabel(t.type))
                      .fontSize(11)
                      .fontColor(Constants.COLOR_BRAND)
                      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                      .borderRadius(7)
                  }
                  .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 6 }) {
                  Button(this.actionLabel(t))
                    .width(58)
                    .height(30)
                    .fontSize(11)
                    .fontColor(this.hasTaskTarget(t) ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
                    .backgroundColor(this.hasTaskTarget(t) ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
                    .borderRadius(Constants.RADIUS_SM)
                    .enabled(this.hasTaskTarget(t))
                    .onClick(() => { this.openTask(t); })
                  Button(t.done ? '恢复' : '完成')
                    .width(58)
                    .height(30)
                    .fontSize(11)
                    .fontColor(t.done ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                    .backgroundColor(t.done ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BG_TAG)
                    .borderRadius(Constants.RADIUS_SM)
                    .onClick(() => { this.toggleTask(t); })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
            }
          })
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
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
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(this.goalSuggestions, (suggestion: string) => {
              Button(suggestion)
                .height(40)
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(20)
                .margin({ right: 6, bottom: 6 })
                .onClick(() => {
                  this.goal = suggestion;
                })
            })
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 28, right: 28, bottom: 24 + SafeAreaInsets.bottomVp() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async generate(): Promise<void> {
    if (this.goal.trim().length === 0) return;
    this.dismissGoalInput();
    this.loading = true;
    this.message = '';
    this.hasError = false;
    this.tasks = [];
    this.agentTrace = [];
    this.runLocalProgress();
    try {
      const req: PlanRequest = {
        userId: Constants.DEMO_USER_ID,
        goal: this.goal.trim(),
        durationDays: this.days,
        dailyMinutes: 90,
        startDate: this.localDateKey(),
        profile: (await LocalLearningRepository.getProfile()) ?? undefined
      };
      const response = await HttpClient.post<AgentStudyPlan>(Constants.API_PLAN, JSON.stringify(req));
      this.progressStep = 3;
      const validation = this.validatePlanResponse(response);
      if (!validation.valid || validation.plan === null) {
        this.message = validation.message;
        this.hasError = true;
        return;
      }
      const plan = validation.plan;
      this.progressStep = 4;
      await LocalLearningRepository.savePlan(plan);
      await LearningFormUpdater.refreshAll();
      this.tasks = plan.tasks;
      this.agentTrace = plan.agentTrace ?? [];
      this.message = '计划已生成并同步到首页';
    } catch (e) {
      const error = e instanceof Error ? e : new Error('Network request failed');
      this.message = this.planErrorMessage(error);
      this.hasError = true;
    } finally {
      this.loading = false;
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
