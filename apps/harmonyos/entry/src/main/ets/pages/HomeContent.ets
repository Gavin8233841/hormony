import { Constants } from '../common/Constants';
import { Course, PlanTask, StudyPlan } from '../model/DataModels';
import { LearningStudyEvent as StudyEvent } from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningReminder } from '../common/LearningReminder';
import { LearningFormRefreshResult, LearningFormUpdater } from '../common/LearningFormUpdater';
import { ProactiveLearningAction, ProactiveLearningService } from '../common/ProactiveLearningService';
import { common } from '@kit.AbilityKit';

interface AgentPlanTask extends PlanTask {
  reason?: string;
}

@Component
export struct HomeContent {
  @Link selectedTab: number;
  @Link quickQuestion: string;

  @State currentCourse: Course = {
    id: 'cs101',
    title: '数据结构',
    progress: 0,
    docCount: 52,
    topics: ['数组', '链表', '树', '图'],
  };
  @State quickAsk: string = '';
  @State notificationOpen: boolean = false;
  @State notificationState: string = 'idle';
  @State pressedTask: number = -1;
  @State notificationMessage: string = '学习计划已同步，完成任务会自动更新进度';
  @State nextActionKind: string = 'course';
  @State nextActionBadge: string = '继续';
  @State nextActionTitle: string = '继续当前课程';
  @State nextActionSubtitle: string = '从课程页进入主题学习、练习和 AI 测验';
  @State nextActionCta: string = '进入课程';
  @State nextActionCourseId: string = 'cs101';
  @State nextActionCourseTitle: string = '数据结构';
  @State nextActionTopic: string = '';
  @State nextActionFocusTag: string = '';
  @State nextActionTaskAction: string = '';
  @State nextActionTargetPage: string = 'pages/Index';
  @State nextActionEvidence: string = '正在读取本机学习状态';
  @State nextActionProgressText: string = '等待同步';
  @StorageLink('currentPlanTasks') planTasks: PlanTask[] = [];
  private reminderAction: ProactiveLearningAction | null = null;

  aboutToAppear(): void {
    this.loadCourses();
    this.loadPlan();
    this.loadNextAction();
  }

  private async loadCourses(): Promise<void> {
    try {
      const courses = await LocalLearningRepository.getCourses();
      if (courses !== null && courses.length > 0) {
        this.currentCourse = courses[0];
      }
      await this.loadNextAction();
    } catch (e) {
      // 保留首屏默认课程，等待下次本地读取。
    }
  }

  private async loadPlan(): Promise<void> {
    try {
      const plan = await LocalLearningRepository.getPlan();
      if (plan !== null) this.planTasks = plan.tasks;
      await this.loadNextAction();
    } catch (e) {
      // 保留首屏默认任务，等待下次本地读取。
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

  private taskStatus(task: PlanTask): string {
    if (task.done) return '已完成';
    const firstPending = this.todayTasks().find((item: PlanTask): boolean => item.done !== true);
    return firstPending?.id === task.id ? '进行中' : '待开始';
  }

  private async toggleTask(task: PlanTask): Promise<void> {
    try {
      const nextTasks: PlanTask[] = this.planTasks.map((item: PlanTask): PlanTask => {
        if (item.id !== task.id) return item;
        return {
          id: item.id,
          title: item.title,
          date: item.date,
          estimatedMin: item.estimatedMin,
          type: item.type,
          courseId: item.courseId,
          topic: item.topic,
          action: item.action,
          reason: (item as AgentPlanTask).reason,
          done: !Boolean(item.done)
        } as AgentPlanTask;
      });
      const currentPlan = await LocalLearningRepository.getPlan();
      const plan: StudyPlan = currentPlan ?? {
        planId: 'local-plan',
        userId: Constants.DEMO_USER_ID,
        goal: '完成今日学习任务',
        tasks: nextTasks
      };
      plan.tasks = nextTasks;
      await LocalLearningRepository.savePlan(plan);
      await LearningFormUpdater.refreshAll();
      const changedTask = nextTasks.find((item: PlanTask): boolean => item.id === task.id);
      if (changedTask?.done === true) {
        const event: StudyEvent = {
          id: 'event_' + Date.now().toString(),
          type: 'task_completed',
          timestamp: new Date().toISOString(),
          taskId: task.id
        };
        await LocalLearningRepository.appendStudyEvent(event);
      }
      this.planTasks = nextTasks;
      await this.loadNextAction();
    } catch (e) {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent local task update failed');
    }
  }

  private async publishReminder(): Promise<void> {
    if (this.notificationState === 'loading') return;
    this.notificationOpen = true;
    this.notificationState = 'loading';
    this.notificationMessage = '正在创建系统学习提醒';
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const action = await LearningReminder.publishNextTask(hostContext);
      this.reminderAction = action;
      this.applyNextAction(action);
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
      '系统提醒已创建；暂时无法读取服务卡片，请重试同步' :
      '系统提醒已创建；服务卡片已同步 ' + result.updated.toString() + '/' + result.registered.toString();
    return false;
  }

  private async retryReminderCards(): Promise<void> {
    if (this.notificationState === 'loading' || this.reminderAction === null) return;
    this.notificationState = 'loading';
    this.notificationMessage = '正在重新同步服务卡片';
    if (!(await this.syncReminderCards(this.reminderAction))) return;
    this.notificationState = 'success';
    this.notificationMessage = '系统提醒和服务卡片已同步：' + this.reminderAction.title;
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

  private async loadNextAction(): Promise<void> {
    try {
      this.applyNextAction(await ProactiveLearningService.resolve());
    } catch (e) {
      this.applyNextAction(ProactiveLearningService.fallback(this.currentCourse));
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
    });
  }

  private nextActionIcon(): Resource {
    if (this.nextActionKind === 'review') return $r('sys.symbol.clock');
    if (this.nextActionKind === 'tag') return $r('sys.symbol.rays');
    if (this.nextActionKind === 'task') return $r('sys.symbol.calendar_fill');
    if (this.nextActionKind === 'plan') return $r('sys.symbol.calendar_badge_plus');
    return $r('sys.symbol.book_open_fill');
  }

  @Builder
  Header() {
    Column() {
      Row() {
        Column() {
          Text('鸿学伴')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('今天先完成最重要的一件事')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
            .fontSize(26)
            .fontColor([Constants.COLOR_BRAND])
        }
        .width(48)
        .height(48)
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(24)
        .accessibilityText('打开个人学习档案')
        .onClick(() => {
          this.selectedTab = 3;
        })

        Stack({ alignContent: Alignment.TopEnd }) {
          Button() {
            SymbolGlyph($r('sys.symbol.bell_fill'))
              .fontSize(23)
              .fontColor([Constants.COLOR_TEXT_PRIMARY])
          }
          .width(48)
          .height(48)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(24)
          .enabled(this.notificationState !== 'loading')
          .opacity(this.notificationState === 'loading' ? 0.56 : 1)
          .accessibilityText(this.notificationState === 'loading' ? '正在创建当前学习提醒' :
            '创建当前学习任务提醒')
          .onClick(() => {
            this.publishReminder();
          })

          Column()
            .width(7)
            .height(7)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(4)
            .margin({ top: 4, right: 4 })
        }
        .margin({ left: 8 })
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
              .accessibilityText('重试创建当前学习提醒')
              .onClick(() => {
                this.publishReminder();
              })
          }
          if (this.notificationState === 'warning') {
            Button('重试同步')
              .width(80)
              .height(48)
              .padding({ left: 10, right: 10 })
              .fontSize(12)
              .fontColor(Constants.COLOR_WARNING)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .border({ width: 1, color: Constants.COLOR_WARNING })
              .borderRadius(24)
              .accessibilityText('重试同步当前学习任务到服务卡片')
              .onClick(() => {
                this.retryReminderCards();
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
  ContinueCard() {
    Column() {
      Row() {
        Column() {
          Row({ space: 8 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(30)
                .height(30)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(9)
              SymbolGlyph(this.nextActionIcon())
                .fontSize(16)
                .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
            }
            Text(this.nextActionBadge)
              .fontSize(14)
              .fontColor(Constants.COLOR_BRAND)
          }

          Text(this.nextActionTitle)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .margin({ top: 14 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(34)
                .height(34)
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(10)
              SymbolGlyph(this.nextActionIcon())
                .fontSize(17)
                .fontColor([Constants.COLOR_BRAND])
            }
            Column() {
              Text('推荐依据')
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              Text(this.nextActionEvidence)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)
                .lineHeight(19)
                .margin({ top: 3 })
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .padding({ left: 10, right: 12, top: 9, bottom: 9 })
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .margin({ top: 12 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(92)
            .height(92)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(46)
          Column()
            .width(68)
            .height(68)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(34)
          SymbolGlyph(this.nextActionIcon())
            .fontSize(42)
            .fontColor([Constants.COLOR_BRAND])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .width(98)
        .height(112)
      }
      .width('100%')

      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text(this.nextActionSubtitle)
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.nextActionProgressText)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_BRAND)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button() {
          Row({ space: 6 }) {
            Text(this.nextActionCta)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(15)
              .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
          }
        }
        .height(48)
        .padding({ left: 18, right: 16 })
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(24)
        .shadow({ radius: 6, color: Constants.SHADOW_BRAND, offsetX: 0, offsetY: 3 })
        .accessibilityText(this.nextActionCta + '，' + this.nextActionTitle)
        .onClick(() => {
          this.openNextAction();
        })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 4 })
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
        Text(task.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(task.date + ' · ' + task.estimatedMin.toString() + ' 分钟')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.taskStatus(task))
        .fontSize(11)
        .fontColor(this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS :
          this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.taskStatus(task) === '已完成' ? Constants.COLOR_SUCCESS_LIGHT :
          this.taskStatus(task) === '进行中' ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
        .borderRadius(12)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .scale({ x: this.pressedTask === index ? 0.98 : 1, y: this.pressedTask === index ? 0.98 : 1 })
    .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
    .accessibilityText(task.title + '，' + this.taskStatus(task) + '，点击切换任务状态')
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
            .fontColor(Constants.COLOR_BRAND)
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
        if (this.planTasks.length === 0) {
          Column({ space: 8 }) {
            Text('还没有学习计划')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('设定目标后，学伴会生成可打卡的任务')
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
              .fontColor(Constants.COLOR_BRAND)
              .borderRadius(18)
              .onClick(() => this.openPlan())
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
        } else {
          ForEach(this.todayTasks().slice(0, 3), (task: PlanTask, index: number) => {
            this.TaskRow(task, index)
            if (index < Math.min(this.todayTasks().length, 3) - 1) {
              Divider()
                .color(Constants.COLOR_BORDER)
                .margin({ left: 46 })
            }
          })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
      .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 3 })
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
        SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
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
      Column({ space: 18 }) {
        this.Header()
        this.ContinueCard()
        this.TodayPlan()
        this.QuickAsk()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 104 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
