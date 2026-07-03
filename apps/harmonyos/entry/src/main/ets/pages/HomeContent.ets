import { Constants } from '../common/Constants';
import { Course, PlanTask, StudyEvent, StudyPlan } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningReminder } from '../common/LearningReminder';
import { LearningFormUpdater } from '../common/LearningFormUpdater';
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
  @State pressedTask: number = -1;
  @State notificationMessage: string = '学习计划已同步，完成任务会自动更新进度';
  @StorageLink('currentPlanTasks') planTasks: PlanTask[] = [];

  aboutToAppear(): void {
    this.loadCourses();
    this.loadPlan();
  }

  private async loadCourses(): Promise<void> {
    try {
      const courses = await LocalLearningRepository.getCourses();
      if (courses !== null && courses.length > 0) {
        this.currentCourse = courses[0];
      }
    } catch (e) {
      // 保留首屏默认课程，等待下次本地读取。
    }
  }

  private async loadPlan(): Promise<void> {
    try {
      const plan = await LocalLearningRepository.getPlan();
      if (plan !== null) this.planTasks = plan.tasks;
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
      this.planTasks = nextTasks;
      const changedTask = nextTasks.find((item: PlanTask): boolean => item.id === task.id);
      this.syncTaskSideEffects(task, changedTask?.done === true);
    } catch (e) {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent local task update failed');
    }
  }

  private syncTaskSideEffects(task: PlanTask, nextDone: boolean): void {
    LearningFormUpdater.refreshAll().catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent form refresh failed after task update: %{public}s', error.message);
    });
    if (!nextDone) return;
    const event: StudyEvent = {
      id: 'event_' + Date.now().toString(),
      type: 'task_completed',
      timestamp: new Date().toISOString(),
      taskId: task.id
    };
    LocalLearningRepository.appendStudyEvent(event).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'HomeContent study event append failed after task update: %{public}s', error.message);
    });
  }

  private async publishReminder(): Promise<void> {
    this.notificationOpen = true;
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const taskTitle = await LearningReminder.publishNextTask(hostContext);
      this.notificationMessage = '系统提醒已创建：' + taskTitle;
    } catch (e) {
      this.notificationMessage = '未能创建系统提醒，请检查通知权限';
    }
  }

  private currentTaskTitle(): string {
    for (const task of this.todayTasks()) {
      if (!task.done) return task.title;
    }
    if (this.planTasks.length === 0) return '制定今日学习计划';
    return this.todayTasks().length === 0 ? '今天没有安排' : '今日任务已完成';
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
        .width(44)
        .height(44)
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(22)
        .onClick(() => {
          this.selectedTab = 3;
        })

        Stack({ alignContent: Alignment.TopEnd }) {
          Button() {
            SymbolGlyph($r('sys.symbol.bell_fill'))
              .fontSize(23)
              .fontColor([Constants.COLOR_TEXT_PRIMARY])
          }
          .width(44)
          .height(44)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(22)
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
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(18)
            .fontColor([Constants.COLOR_SUCCESS])
          Text(this.notificationMessage)
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .margin({ top: 12 })
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
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
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(16)
                .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
            }
            Text('继续学习')
              .fontSize(14)
              .fontColor(Constants.COLOR_BRAND)
          }

          Text(this.currentCourse.title)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .margin({ top: 14 })

          Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(34)
                .height(34)
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(10)
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(17)
                .fontColor([Constants.COLOR_BRAND])
            }
            Column() {
              Text('当前任务')
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
              Text(this.currentTaskTitle())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
                .margin({ top: 3 })
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
          SymbolGlyph($r('sys.symbol.book_pages_fill_1'))
            .fontSize(46)
            .fontColor([Constants.COLOR_BRAND])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .width(98)
        .height(112)
      }
      .width('100%')

      Row({ space: 14 }) {
        Column() {
          Row() {
            Text('学习进度')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Text(Math.round(this.currentCourse.progress * 100).toString() + '%')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_BRAND)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Progress({ value: this.currentCourse.progress * 100, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(5)
            .color(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
            .borderRadius(3)
            .margin({ top: 8 })
        }
        .layoutWeight(1)

        Button() {
          Row({ space: 6 }) {
            Text('继续学习')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(15)
              .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
          }
        }
        .height(44)
        .padding({ left: 18, right: 16 })
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(22)
        .shadow({ radius: 6, color: Constants.SHADOW_BRAND, offsetX: 0, offsetY: 3 })
        .onClick(() => {
          this.selectedTab = 1;
        })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_XL)
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
              .height(36)
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
              .height(36)
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
        .height(40)
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
      .width(38)
      .height(38)
      .backgroundColor(Constants.COLOR_BRAND)
      .borderRadius(19)
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
