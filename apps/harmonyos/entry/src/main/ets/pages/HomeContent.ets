import { Constants } from '../common/Constants';
import { PlanTask, PlanTaskUpdateReceipt } from '../model/DataModels';
import { LearningStudyEvent as StudyEvent } from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningReminder } from '../common/LearningReminder';
import { LearningFormRefreshResult, LearningFormUpdater } from '../common/LearningFormUpdater';
import { ProactiveLearningAction, ProactiveLearningService } from '../common/ProactiveLearningService';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { common } from '@kit.AbilityKit';

@Component
export struct HomeContent {
  @StorageProp('darkMode') darkMode: boolean = false;
  @Link selectedTab: number;
  @Link quickQuestion: string;
  @Prop @Watch('refreshLearningView') learningViewVersion: number = 0;
  @Prop bottomInset: number = 0;

  @State quickAsk: string = '';
  @State notificationOpen: boolean = false;
  @State notificationState: string = 'idle';
  @State pressedTask: number = -1;
  @State pressedPrimary: boolean = false;
  @State pressedCourseId: string = '';
  @State todayExpanded: boolean = false;
  @State artworkRevealed: boolean = false;
  @State updatingTaskId: string = '';
  @State taskUpdateMessage: string = '';
  @State taskUpdateFailed: boolean = false;
  @State planLoading: boolean = true;
  @State planError: boolean = false;
  @State notificationMessage: string = '学习计划已同步，完成任务会自动更新进度';
  @State nextActionKind: string = 'course';
  @State nextActionBadge: string = '继续';
  @State nextActionTitle: string = '继续当前课程';
  @State nextActionSubtitle: string = '挑一个主题开始学';
  @State nextActionCta: string = '进入课程';
  @State nextActionCourseId: string = 'cs101';
  @State nextActionCourseTitle: string = '数据结构';
  @State nextActionTopic: string = '';
  @State nextActionFocusTag: string = '';
  @State nextActionTaskAction: string = '';
  @State nextActionTargetPage: string = 'pages/Index';
  @State nextActionEvidence: string = '';
  @State nextActionProgressText: string = '等待同步';
  @State nextActionLoading: boolean = true;
  @State nextActionReady: boolean = false;
  @State nextActionError: boolean = false;
  @State nextActionNavigationMessage: string = '';
  @State courseNavigationMessage: string = '';
  @State checkInDates: string[] = [];
  @State checkInBusy: boolean = false;
  @State checkInError: string = '';
  @State checkInHistoryOpen: boolean = false;
  @State checkInCelebrating: boolean = false;
  @StorageLink('currentPlanTasks') planTasks: PlanTask[] = [];
  private reminderAction: ProactiveLearningAction | null = null;
  private reminderActionRunId: number = -1;
  private nextActionRunId: number = 0;

  aboutToAppear(): void {
    this.loadPlan();
    this.loadNextAction();
    this.loadCheckIn();
    setTimeout((): void => {
      this.artworkRevealed = true;
    }, 80);
  }

  private refreshLearningView(): void {
    this.loadPlan();
    this.loadNextAction();
    this.loadCheckIn();
  }

  private async loadCheckIn(): Promise<void> {
    try {
      this.checkInDates = await LocalLearningRepository.getCheckInDates();
      this.checkInError = '';
    } catch (_) {
      this.checkInError = '签到记录暂时无法读取';
    }
  }

  private recentCheckInDates(count: number): string[] {
    const now = new Date();
    const dates: string[] = [];
    for (let index = count - 1; index >= 0; index--) {
      const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - index);
      const month = (day.getMonth() + 1).toString().padStart(2, '0');
      const date = day.getDate().toString().padStart(2, '0');
      dates.push(day.getFullYear().toString() + '-' + month + '-' + date);
    }
    return dates;
  }

  private checkInStreak(): number {
    const dates = this.checkInDates;
    const recent = this.recentCheckInDates(dates.length + 1);
    let index = recent.length - 1;
    if (index >= 0 && !dates.includes(recent[index])) index -= 1;
    let count = 0;
    while (index >= 0 && dates.includes(recent[index])) {
      count += 1;
      index -= 1;
    }
    return count;
  }

  private async checkIn(): Promise<void> {
    if (this.checkInBusy || this.checkInDates.includes(this.todayDate())) return;
    this.checkInBusy = true;
    this.checkInError = '';
    try {
      const changed = await LocalLearningRepository.checkInToday();
      this.checkInDates = await LocalLearningRepository.getCheckInDates();
      if (changed) {
        this.checkInCelebrating = true;
        setTimeout((): void => { this.checkInCelebrating = false; }, 640);
      }
    } catch (_) {
      this.checkInError = '签到没保存，点此重试';
    } finally {
      this.checkInBusy = false;
    }
  }

  private async loadPlan(): Promise<void> {
    this.planLoading = true;
    this.planError = false;
    try {
      const plan = await LocalLearningRepository.getPlan();
      this.planTasks = plan?.tasks ?? [];
    } catch (e) {
      this.planError = true;
    } finally {
      this.planLoading = false;
    }
  }

  private todayDate(): string {
    const now = new Date();
    const month = (now.getMonth() + 1).toString();
    const day = now.getDate().toString();
    return now.getFullYear().toString() + '-' + (month.length === 1 ? '0' + month : month) + '-' +
      (day.length === 1 ? '0' + day : day);
  }

  private todayTasks(): PlanTask[] {
    const today = this.todayDate();
    return this.planTasks.filter((task: PlanTask): boolean => task.date === today);
  }

  private otherTodayTasks(): PlanTask[] {
    const tasks = this.todayTasks();
    if (!this.nextActionReady || this.nextActionKind !== 'task') return tasks;
    const featuredIndex = tasks.findIndex((task: PlanTask): boolean =>
      ProactiveLearningService.planTaskTitle(task) === this.nextActionTitle &&
        task.courseId === this.nextActionCourseId && task.topic === this.nextActionTopic &&
        task.action === this.nextActionTaskAction);
    return featuredIndex < 0 ? tasks : tasks.filter((_: PlanTask, index: number): boolean => index !== featuredIndex);
  }

  private taskStatus(task: PlanTask): string {
    if (task.done) return '已完成';
    const firstPending = this.todayTasks().find((item: PlanTask): boolean => item.done !== true);
    return firstPending?.id === task.id ? '进行中' : '待开始';
  }

  private async toggleTask(task: PlanTask): Promise<void> {
    if (this.updatingTaskId.length > 0 || this.notificationState === 'loading') return;
    const taskId = task.id;
    const desiredDone = !Boolean(task.done);
    let receipt: PlanTaskUpdateReceipt | null = null;
    this.updatingTaskId = taskId;
    this.taskUpdateMessage = '正在保存任务状态';
    this.taskUpdateFailed = false;
    try {
      try {
        receipt = await LocalLearningRepository.updatePlanTask(taskId, desiredDone);
        const nextTasks = receipt.plan.tasks;
        this.planTasks = nextTasks;
        this.reminderAction = null;
        this.reminderActionRunId = -1;
        this.taskUpdateMessage = receipt.task.done === true ? '任务已完成' : '已改为待完成';
      } catch (e) {
        this.taskUpdateMessage = '任务状态保存失败，请重试';
        this.taskUpdateFailed = true;
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'HomeContent local task update failed');
        return;
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
      if (!studyEventSaved) {
        this.taskUpdateMessage = '任务已完成并保存，学习记录暂未更新';
        this.taskUpdateFailed = true;
      }
      await this.loadNextAction();
    } finally {
      if (this.updatingTaskId === taskId) this.updatingTaskId = '';
    }
  }

  private async publishReminder(): Promise<void> {
    if (this.notificationState === 'loading' || this.updatingTaskId.length > 0) return;
    const actionRunId: number = this.nextActionRunId;
    this.notificationOpen = true;
    this.notificationState = 'loading';
    this.notificationMessage = '正在创建系统学习提醒';
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const action = await LearningReminder.publishNextTask(hostContext);
      if (this.nextActionRunId !== actionRunId) {
        this.reminderAction = null;
        this.reminderActionRunId = -1;
        this.notificationState = 'warning';
        this.notificationMessage = '待办已更新，请重新创建提醒';
        return;
      }
      this.reminderAction = action;
      this.reminderActionRunId = actionRunId;
      this.applyNextAction(action);
      this.nextActionReady = true;
      this.nextActionError = false;
      this.nextActionLoading = false;
      if (!(await this.syncReminderCards(action))) return;
      this.notificationState = 'success';
      this.notificationMessage = '系统提醒已创建：' + action.title;
    } catch (e) {
      this.notificationState = 'error';
      this.notificationMessage = e instanceof Error ? e.message : '未能创建系统提醒，请稍后重试';
    }
  }

  private async syncReminderCards(action: ProactiveLearningAction): Promise<boolean> {
    const result: LearningFormRefreshResult = await LearningFormUpdater.refreshAllWithAction(action);
    if (!result.lookupFailed && result.failed === 0) return true;
    this.notificationState = 'warning';
    this.notificationMessage = result.lookupFailed ?
      '提醒已创建，桌面卡片暂未同步' :
      '提醒已创建，桌面卡片已同步 ' + result.updated.toString() + '/' + result.registered.toString();
    return false;
  }

  private async retryReminderCards(): Promise<void> {
    if (this.notificationState === 'loading' || this.updatingTaskId.length > 0) return;
    const action: ProactiveLearningAction | null = this.reminderAction;
    if (action === null || this.reminderActionRunId !== this.nextActionRunId) {
      this.reminderAction = null;
      this.reminderActionRunId = -1;
      this.notificationState = 'warning';
      this.notificationMessage = '待办已更新，请重新创建提醒';
      return;
    }
    this.notificationState = 'loading';
    this.notificationMessage = '正在同步桌面卡片';
    if (!(await this.syncReminderCards(action))) return;
    this.notificationState = 'success';
    this.notificationMessage = '提醒已同步：' + action.title;
  }

  private hasCurrentReminderAction(): boolean {
    return this.reminderAction !== null && this.reminderActionRunId === this.nextActionRunId;
  }

  private submitQuickAsk(): void {
    const question = this.quickAsk.trim();
    if (question.length === 0) {
      this.selectedTab = 2;
      return;
    }
    this.quickQuestion = question;
    this.selectedTab = 2;
    this.quickAsk = '';
  }

  private openPlan(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Plan' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent router.pushUrl failed: %{public}s', err.message);
    });
  }

  private courseTitle(courseId: string): string {
    if (courseId === 'cs102') return '操作系统';
    if (courseId === 'cs103') return '计算机网络';
    return '数据结构';
  }

  private courseArtwork(courseId: string): Resource {
    if (courseId === 'cs102') return $r('app.media.course_os');
    if (courseId === 'cs103') return $r('app.media.course_network');
    return $r('app.media.course_data');
  }

  private alternativeCourseIds(): string[] {
    return ['cs101', 'cs102', 'cs103'].filter((courseId: string): boolean =>
      courseId !== this.nextActionCourseId).slice(0, 2);
  }

  private openCourse(courseId: string): void {
    this.courseNavigationMessage = '';
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(courseId));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetail' }).catch((): void => {
      this.courseNavigationMessage = '暂时无法打开课程，请重试';
    });
  }

  private async loadNextAction(): Promise<void> {
    const runId = this.nextActionRunId + 1;
    this.nextActionRunId = runId;
    this.nextActionLoading = true;
    this.nextActionError = false;
    this.nextActionNavigationMessage = '';
    try {
      const action = await ProactiveLearningService.resolve();
      if (this.nextActionRunId !== runId) return;
      this.applyNextAction(action);
      this.nextActionReady = true;
    } catch (e) {
      if (this.nextActionRunId !== runId) return;
      this.nextActionReady = false;
      this.nextActionError = true;
    } finally {
      if (this.nextActionRunId === runId) this.nextActionLoading = false;
    }
  }

  private applyNextAction(action: ProactiveLearningAction): void {
    this.nextActionKind = action.kind;
    this.nextActionBadge = action.badge;
    this.nextActionTitle = action.title;
    this.nextActionSubtitle = action.subtitle;
    this.nextActionCta = action.cta;
    this.nextActionCourseId = action.courseId;
    this.nextActionCourseTitle = action.courseTitle;
    this.nextActionTopic = action.topic;
    this.nextActionFocusTag = action.focusTag;
    this.nextActionTaskAction = action.taskAction;
    this.nextActionTargetPage = action.targetPage;
    this.nextActionEvidence = action.evidence;
    this.nextActionProgressText = action.progressText;
  }

  private openNextAction(): void {
    const action: ProactiveLearningAction = {
      kind: this.nextActionKind,
      badge: this.nextActionBadge,
      title: this.nextActionTitle,
      subtitle: this.nextActionSubtitle,
      cta: this.nextActionCta,
      courseId: this.nextActionCourseId,
      courseTitle: this.nextActionCourseTitle,
      topic: this.nextActionTopic,
      focusTag: this.nextActionFocusTag,
      taskAction: this.nextActionTaskAction,
      targetPage: this.nextActionTargetPage,
      evidence: this.nextActionEvidence,
      progressText: this.nextActionProgressText
    };
    ProactiveLearningService.applySelection(action);
    if (this.nextActionTargetPage === 'pages/Index') {
      this.selectedTab = 1;
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: this.nextActionTargetPage }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent proactive action navigation failed: %{public}s', err.message);
      this.nextActionNavigationMessage = '暂时无法打开学习内容，请重试';
    });
  }

  @Builder
  Header() {
    Column() {
      Row() {
        Column() {
          Text('鸿学伴')
            .fontSize(Constants.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('今天学什么')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.bell_fill'))
            .fontSize(23)
            .fontColor([Constants.COLOR_TEXT_PRIMARY])
        }
        .width(48)
        .height(48)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(24)
        .enabled(this.notificationState !== 'loading' && this.updatingTaskId.length === 0)
        .opacity(this.notificationState === 'loading' || this.updatingTaskId.length > 0 ? 0.56 : 1)
        .accessibilityText(this.notificationState === 'loading' ? '正在创建当前学习提醒' :
          this.updatingTaskId.length > 0 ? '正在保存学习任务，稍后可创建提醒' : '创建当前学习任务提醒')
        .onClick(() => {
          this.publishReminder();
        })
      }
      .width('100%')

      if (this.notificationOpen) {
        Row({ space: 8 }) {
          if (this.notificationState === 'loading') {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(Constants.COLOR_BRAND)
          } else {
            SymbolGlyph(this.notificationState === 'error' ? $r('sys.symbol.xmark_circle_fill') :
              this.notificationState === 'warning' ? $r('sys.symbol.exclamationmark_triangle_fill') :
                $r('sys.symbol.checkmark_circle_fill'))
              .fontSize(18)
              .fontColor([this.notificationState === 'error' ? Constants.COLOR_ERROR :
                this.notificationState === 'warning' ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS])
          }
          Text(this.notificationMessage)
            .fontSize(12)
            .fontColor(this.notificationState === 'error' ? Constants.COLOR_ERROR :
              this.notificationState === 'warning' ? Constants.COLOR_WARNING : Constants.COLOR_TEXT_SECONDARY)
            .maxLines(2)
            .layoutWeight(1)
          if (this.notificationState === 'error') {
            Button('重试')
              .width(64)
              .height(48)
              .padding({ left: 12, right: 12 })
              .fontSize(12)
              .fontColor(Constants.COLOR_ERROR)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .border({ width: 1, color: Constants.COLOR_ERROR })
              .borderRadius(24)
              .enabled(this.updatingTaskId.length === 0)
              .accessibilityText(this.updatingTaskId.length > 0 ? '正在保存学习任务，稍后可重试创建提醒' :
                '重试创建当前学习提醒')
              .onClick(() => {
                this.publishReminder();
              })
          }
          if (this.notificationState === 'warning') {
            Button(this.hasCurrentReminderAction() ? '重试同步' : '重新创建')
              .width(this.hasCurrentReminderAction() ? 80 : 88)
              .height(48)
              .padding({ left: 10, right: 10 })
              .fontSize(12)
              .fontColor(Constants.COLOR_WARNING)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .border({ width: 1, color: Constants.COLOR_WARNING })
              .borderRadius(24)
              .enabled(this.updatingTaskId.length === 0)
              .accessibilityText(this.updatingTaskId.length > 0 ? '正在保存学习任务，稍后可处理系统提醒' :
                this.hasCurrentReminderAction() ? '重试同步桌面卡片' :
                  '为当前待办重新创建提醒')
              .onClick(() => {
                if (this.hasCurrentReminderAction()) {
                  this.retryReminderCards();
                } else {
                  this.publishReminder();
                }
              })
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .margin({ top: 12 })
        .backgroundColor(this.notificationState === 'error' ? Constants.COLOR_ERROR_LIGHT : Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
        .accessibilityGroup(this.notificationState !== 'error' && this.notificationState !== 'warning')
        .accessibilityText(this.notificationState === 'error' || this.notificationState === 'warning' ? '' :
          this.notificationMessage)
      }
    }
    .width('100%')
  }

  @Builder
  CheckInDay(date: string) {
    Column({ space: 3 }) {
      Text(this.checkInDates.includes(date) ? '✓' : date === this.todayDate() ? '今' : '·')
        .width(23)
        .height(23)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.checkInDates.includes(date) ? Constants.COLOR_TEXT_ON_GRADIENT :
          Constants.COLOR_BRAND_TEXT)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.checkInDates.includes(date) ? Constants.COLOR_BRAND :
          this.darkMode ? '#7053687f' : '#99ffffff')
        .borderRadius(14)
      Text(date.slice(5))
        .fontSize(10)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(date + (this.checkInDates.includes(date) ? '已签到' : '未签到'))
  }

  @Builder
  CheckInCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 3 }) {
        Text('签到')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(this.checkInStreak().toString() + ' 天')
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_BRAND_TEXT)
        Text(this.checkInError.length > 0 ? this.checkInError : '连续学习')
          .fontSize(11)
          .fontColor(this.checkInError.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          .maxLines(1)
        Blank()
        Row({ space: 5 }) {
          if (this.checkInDates.includes(this.todayDate())) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(13)
              .fontColor([Constants.COLOR_SUCCESS])
            Text('已签到')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          } else {
            Button(this.checkInBusy ? '签到中' : '签到')
              .height(40)
              .padding({ left: 12, right: 12 })
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(13)
              .enabled(!this.checkInBusy)
              .onClick((): void => { this.checkIn(); })
          }
          Blank()
          Text('记录 ›')
            .fontSize(10)
            .fontColor(Constants.COLOR_BRAND_TEXT)
            .height(40)
            .onClick((): void => {
              this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, (): void => {
                this.checkInHistoryOpen = !this.checkInHistoryOpen;
              });
            })
        }
        .width('100%')
      }
      .width('100%')
      .height(134)
      .padding({ left: 14, right: 10, top: 13, bottom: 7 })
      .alignItems(HorizontalAlign.Start)
      Image($r('app.media.mascot_xiaohong_welcome'))
        .width(60).height(65).objectFit(ImageFit.Contain)
        .margin({ right: 2, top: 9 })
        .scale({ x: this.checkInCelebrating ? 1.1 : 1, y: this.checkInCelebrating ? 1.1 : 1 })
        .rotate({ angle: this.checkInCelebrating ? -7 : 0 })
        .animation({ duration: 420, curve: Curve.EaseOut })
      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(17)
        .fontColor(['#eac77d'])
        .margin({ right: 58, top: 9 })
        .opacity(this.checkInCelebrating ? 1 : 0)
        .translate({ x: this.checkInCelebrating ? -8 : 0, y: this.checkInCelebrating ? -10 : 6 })
        .animation({ duration: 420, curve: Curve.EaseOut })
      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(12)
        .fontColor([Constants.COLOR_HERO_ACCENT])
        .margin({ right: 5, top: 60 })
        .opacity(this.checkInCelebrating ? 1 : 0)
        .translate({ y: this.checkInCelebrating ? -10 : 5 })
        .animation({ duration: 520, curve: Curve.EaseOut })
    }
    .width('100%')
    .backgroundColor(this.darkMode ? '#253556' : '#e8edff')
    .linearGradient({ angle: 105, colors: [[this.darkMode ? '#253556' : '#e8edff', 0],
      [this.darkMode ? '#1c3f43' : '#e4f5f1', 1]] })
    .borderRadius(22)
  }

  @Builder
  TodaySummaryCard() {
    Column({ space: 5 }) {
      Row() {
        Text('今日计划')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Blank()
        SymbolGlyph($r('sys.symbol.arrow_up_right'))
          .fontSize(13)
          .fontColor([Constants.COLOR_BRAND_TEXT])
      }
      .width('100%')
      if (this.planLoading) {
        Text('正在读取计划')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      } else if (this.planError) {
        Text('暂时无法读取')
          .fontSize(14)
          .fontColor(Constants.COLOR_ERROR)
      } else if (this.planTasks.length === 0) {
        Text('安排今天的学习')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      } else if (this.todayTasks().length === 0) {
        Text('今天没有安排')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      } else {
        Text(this.otherTodayTasks().length > 0 ?
          ProactiveLearningService.planTaskTitle(this.otherTodayTasks()[0]) :
          this.todayTasks().filter((task: PlanTask): boolean => !task.done).length.toString() + ' 项待办')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .maxLines(2)
        if (this.otherTodayTasks().length > 0) {
          Text('约 ' + this.otherTodayTasks()[0].estimatedMin.toString() + ' 分钟')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
      }
      Blank()
      Text(this.planError ? '轻触重试' : this.planTasks.length === 0 ? '制定计划  ›' : '查看安排  ›')
        .fontSize(11)
        .fontColor(Constants.COLOR_BRAND_TEXT)
        .height(26)
    }
    .width('100%')
    .height(134)
    .padding({ left: 14, right: 14, top: 13, bottom: 7 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.darkMode ? '#273349' : '#fffaf1')
    .border({ width: 1, color: this.darkMode ? '#344158' : '#f1e9da' })
    .borderRadius(22)
    .accessibilityText('今日计划，' + (this.planError ? '读取失败，轻触重试' : '查看学习安排'))
    .onClick((): void => {
      if (this.planError) this.loadPlan();
      else this.openPlan();
    })
  }

  @Builder
  CheckInHistory() {
    Column({ space: 8 }) {
      Row() {
        Text('近 28 天')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Blank()
        Text(this.checkInError.length > 0 ? '重试' : '收起')
          .fontSize(12)
          .fontColor(this.checkInError.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_BRAND_TEXT)
          .height(40)
          .onClick((): void => {
            if (this.checkInError.length > 0) this.loadCheckIn();
            else this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, (): void => {
              this.checkInHistoryOpen = false;
            });
          })
      }
      .width('100%')
      ForEach([0, 1, 2, 3], (rowIndex: number): void => {
        Row() {
          ForEach(this.recentCheckInDates(28).slice(rowIndex * 7, rowIndex * 7 + 7),
            (date: string): void => { this.CheckInDay(date) }, (date: string): string => date)
        }
        .width('100%')
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 4 })
    .backgroundColor(this.darkMode ? '#1b2839' : '#eef2f8')
    .borderRadius(20)
  }

  @Builder
  ContinueCard() {
    Column({ space: 8 }) {
      if (this.nextActionLoading) {
        Row({ space: 10 }) {
          Column()
            .width(32)
            .height(32)
            .backgroundColor(Constants.COLOR_BG_SKELETON)
            .borderRadius(Constants.RADIUS_SM)
          Column()
            .width(92)
            .height(16)
            .backgroundColor(Constants.COLOR_BG_SKELETON)
            .borderRadius(5)
        }
        .width('100%')
        Column()
          .width('78%')
          .height(26)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(7)
        Column()
          .width('100%')
          .height(62)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(Constants.RADIUS_MD)
        Column()
          .width('100%')
          .height(48)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(Constants.RADIUS_MD)
      } else if (this.nextActionError || !this.nextActionReady) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
            .fontSize(20)
            .fontColor([Constants.COLOR_ERROR])
          Column({ space: 4 }) {
            Text('暂时无法加载今日任务')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('请重试')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        Button('重试')
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.loadNextAction(); })
      } else {
        Row({ space: 8 }) {
          Text(this.nextActionBadge)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_MAP_CORE)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor(Constants.COLOR_HERO_BADGE)
            .borderRadius(9)
        }
        .width('100%')

        Row({ space: 10 }) {
          Column({ space: 6 }) {
            Text(this.nextActionTitle)
              .width('100%')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_MAP_CORE)
              .maxLines(2)
            Text(this.nextActionSubtitle)
              .width('100%')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
              .maxLines(2)
            Button() {
              Row({ space: 4 }) {
                Text(this.nextActionCta)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_HERO_SURFACE)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(12)
                  .fontColor([Constants.COLOR_HERO_SURFACE])
              }
            }
            .height(40)
            .padding({ left: 13, right: 11 })
            .backgroundColor(Constants.COLOR_HERO_ACCENT)
            .borderRadius(12)
            .scale({ x: this.pressedPrimary ? 0.98 : 1, y: this.pressedPrimary ? 0.98 : 1 })
            .animation({ duration: this.pressedPrimary ? 120 : 180, curve: Curve.EaseOut })
            .accessibilityText(this.nextActionCta + '，' + this.nextActionTitle)
            .onTouch((event?: TouchEvent): void => {
              if (event) this.pressedPrimary = event.type === TouchType.Down;
            })
            .onClick((): void => {
              this.nextActionNavigationMessage = '';
              this.openNextAction();
            })
            .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Image($r('app.media.hero_learning_steps'))
            .width(78)
            .height(82)
            .objectFit(ImageFit.Contain)
            .opacity(this.artworkRevealed ? 1 : 0)
            .translate({ y: this.artworkRevealed ? 0 : 8 })
            .scale({ x: this.artworkRevealed ? 1 : 0.94, y: this.artworkRevealed ? 1 : 0.94 })
            .animation({ duration: 260, curve: Curve.EaseOut })
            .accessibilityText('')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.nextActionNavigationMessage.length > 0) {
          Text(this.nextActionNavigationMessage)
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_ERROR)
            .accessibilityText(this.nextActionNavigationMessage)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.nextActionReady && !this.nextActionLoading && !this.nextActionError ?
      Constants.COLOR_HERO_SURFACE : Constants.COLOR_BG_CARD)
    .linearGradient({ angle: 115, colors: [[this.nextActionReady && !this.nextActionLoading && !this.nextActionError ?
      Constants.COLOR_HERO_SURFACE : Constants.COLOR_BG_CARD, 0],
      [this.nextActionReady && !this.nextActionLoading && !this.nextActionError ?
        '#263f6d' : Constants.COLOR_BG_CARD, 1]] })
    .borderRadius(24)
  }

  @Builder
  TaskRow(task: PlanTask, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(34)
          .height(34)
          .backgroundColor(this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS_LIGHT :
            this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
          .border({
            width: 1,
            color: this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS :
              this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER,
          })
          .borderRadius(17)
        if (this.taskStatus(task) === '已完成') {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(16)
            .fontColor([Constants.COLOR_SUCCESS])
        } else if (this.taskStatus(task) === '进行中') {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(16)
            .fontColor([Constants.COLOR_BRAND])
        }
      }

      Column() {
        Text(ProactiveLearningService.planTaskTitle(task))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text((task.courseId === 'cs102' ? '操作系统' : task.courseId === 'cs103' ?
          '计算机网络' : '数据结构') + ' · ' + task.estimatedMin.toString() + ' 分钟')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.taskStatus(task))
        .fontSize(11)
        .fontColor(this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS :
          this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND_TEXT : Constants.COLOR_TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS_LIGHT :
          this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
        .borderRadius(12)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .scale({ x: this.pressedTask === index ? 0.98 : 1, y: this.pressedTask === index ? 0.98 : 1 })
    .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
    .enabled(this.updatingTaskId.length === 0 && this.notificationState !== 'loading')
    .accessibilityText(ProactiveLearningService.planTaskTitle(task) + '，' + this.taskStatus(task) +
      (this.updatingTaskId.length > 0 ? '，正在保存学习任务' :
        this.notificationState === 'loading' ? '，系统提醒创建期间暂不可切换' : '，点击切换任务状态'))
    .onTouch((event?: TouchEvent) => {
      if (event) {
        if (event.type === TouchType.Down) {
          this.pressedTask = index;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedTask = -1;
        }
      }
    })
    .onClick(() => {
      this.toggleTask(task);
    })
  }

  @Builder
  TodayPlan() {
    Column() {
      Row() {
        Text('今日计划')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Row({ space: 4 }) {
          Text('查看全部')
            .fontSize(13)
            .fontColor(Constants.COLOR_BRAND_TEXT)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(13)
            .fontColor([Constants.COLOR_BRAND])
        }
        .height(48)
        .padding({ left: 12 })
        .accessibilityText('查看完整学习计划')
        .onClick(() => this.openPlan())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 10 })

      Column() {
        if (this.planLoading) {
          Column({ space: 12 }) {
            Column().width('72%').height(16).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width('94%').height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width('58%').height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
        } else if (this.planError) {
          Column({ space: 8 }) {
            Text('暂时无法读取今日计划')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('任务还在，点此重试')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Button('重新读取计划')
              .constraintSize({ minHeight: 48 })
              .padding({ left: 16, right: 16 })
              .fontSize(13)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.loadPlan(); })
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
        } else if (this.planTasks.length === 0) {
          Column({ space: 8 }) {
            Text('还没有学习计划')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('设好目标，安排每天的学习')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Button('制定计划')
              .height(48)
              .fontSize(13)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(18)
              .onClick(() => this.openPlan())
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
        } else if (this.todayTasks().length === 0) {
          Column({ space: 8 }) {
            Text('今天没有安排')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('可以休息，或从完整计划中选择一项继续')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Button('查看完整计划')
              .height(48)
              .fontSize(13)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .borderRadius(18)
              .onClick(() => this.openPlan())
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
        } else {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              Text(ProactiveLearningService.planTaskTitle(this.otherTodayTasks()[0]))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
                .maxLines(1)
              Blank()
              Text(this.todayExpanded ? '收起' : '展开')
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(12)
                .fontColor([Constants.COLOR_TEXT_SECONDARY])
                .rotate({ angle: this.todayExpanded ? 90 : 0 })
                .animation({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
            }
            .width('100%')
          }
          .width('100%')
          .height(52)
          .backgroundColor(Color.Transparent)
          .accessibilityText(this.todayExpanded ? '收起今日其他学习任务' : '展开今日其他学习任务')
          .onClick((): void => {
            this.getUIContext().animateTo({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut }, (): void => {
              this.todayExpanded = !this.todayExpanded;
            });
          })
          if (this.todayExpanded) {
            ForEach(this.otherTodayTasks().slice(0, 3), (task: PlanTask, index: number) => {
              this.TaskRow(task, index)
              if (index < Math.min(this.otherTodayTasks().length, 3) - 1) {
                Divider()
                  .color(Constants.COLOR_BORDER)
                  .margin({ left: 46 })
              }
            })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
      .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 3 })

      if (this.taskUpdateMessage.length > 0) {
        Text(this.taskUpdateMessage)
          .fontSize(12)
          .fontColor(this.taskUpdateFailed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 8 })
          .accessibilityText(this.taskUpdateMessage)
      }
    }
    .width('100%')
  }

  @Builder
  CourseJump(courseId: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 2 }) {
        Text(this.courseTitle(courseId))
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .maxLines(1)
        Row({ space: 2 }) {
          Column() {
            Text(LearningContentRepository.getTopics(courseId).length.toString() + ' 个主题')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.arrow_up_right'))
                .fontSize(15)
                .fontColor([Constants.courseInk(courseId)])
            }
            .width(28)
            .height(28)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(14)
          }
          .layoutWeight(1)
          .height('100%')
          .alignItems(HorizontalAlign.Start)
          Image(this.courseArtwork(courseId))
            .width(68)
            .height(70)
            .objectFit(ImageFit.Contain)
            .accessibilityText('')
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height(116)
    .padding(14)
    .backgroundColor(Constants.courseTint(courseId))
    .borderRadius(Constants.RADIUS_XL)
    .scale({ x: this.pressedCourseId === courseId ? 0.98 : 1,
      y: this.pressedCourseId === courseId ? 0.98 : 1 })
    .animation({ duration: this.pressedCourseId === courseId ? 120 : 180, curve: Curve.EaseOut })
    .accessibilityText('进入' + this.courseTitle(courseId) + '课程')
    .onTouch((event?: TouchEvent): void => {
      if (event) {
        this.pressedCourseId = event.type === TouchType.Down ? courseId : '';
      }
    })
    .onClick((): void => { this.openCourse(courseId); })
  }

  @Builder
  CourseShortcuts() {
    Column({ space: 10 }) {
      Row() {
        Text('课程')
          .fontSize(Constants.PAGE_SECTION_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Blank()
        Text('全部课程 ›')
          .fontSize(13)
          .fontColor(Constants.COLOR_BRAND_TEXT)
          .constraintSize({ minHeight: 48 })
          .onClick((): void => { this.selectedTab = 1; })
      }
      .width('100%')
      Row({ space: 10 }) {
        ForEach(this.alternativeCourseIds(), (courseId: string): void => {
          this.CourseJump(courseId)
        }, (courseId: string): string => courseId)
      }
      .width('100%')
      if (this.courseNavigationMessage.length > 0) {
        Text(this.courseNavigationMessage)
          .fontSize(12)
          .fontColor(Constants.COLOR_ERROR)
      }
    }
    .width('100%')
  }

  @Builder
  QuickAsk() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(38)
          .height(38)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(13)
        SymbolGlyph($r('sys.symbol.rays'))
          .fontSize(20)
          .fontColor([Constants.COLOR_BRAND])
      }

      Column() {
        Text('问问学伴')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('随时解答')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      TextInput({ text: this.quickAsk, placeholder: '输入问题...' })
        .layoutWeight(1)
        .height(48)
        .fontSize(13)
        .backgroundColor(Constants.COLOR_BG_TAG)
        .borderRadius(20)
        .onChange((value: string) => {
          this.quickAsk = value;
        })
        .onSubmit(() => this.submitQuickAsk())

      Button() {
        SymbolGlyph($r('sys.symbol.arrow_right'))
          .fontSize(18)
          .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
      }
      .width(48)
      .height(48)
      .backgroundColor(Constants.COLOR_BRAND)
      .borderRadius(24)
      .accessibilityText(this.quickAsk.trim().length > 0 ? '向学伴发送问题' : '打开学伴')
      .onClick(() => this.submitQuickAsk())
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 3 })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header()
        this.ContinueCard()
        Row({ space: 10 }) {
          Column() {
            this.TodaySummaryCard()
          }
          .layoutWeight(11)
          Column() {
            this.CheckInCard()
          }
          .layoutWeight(9)
        }
        .width('100%')
        if (this.checkInHistoryOpen) this.CheckInHistory()
        this.CourseShortcuts()
        this.QuickAsk()
      }
      .width('100%')
      .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER,
        top: 16, bottom: 16 + this.bottomInset })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
