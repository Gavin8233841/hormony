import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Course, CoursesResponse, PlanTask, PlanTaskUpdate, StudyPlan } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct HomeContent {
  @Link selectedTab: number;
  @Link quickQuestion: string;

  @State currentCourse: Course = {
    id: 'cs101',
    title: '数据结构',
    progress: 0.65,
    docCount: 12,
    topics: ['数组', '链表', '树', '图'],
  };
  @State quickAsk: string = '';
  @State notificationOpen: boolean = false;
  @State pressedTask: number = -1;
  @StorageLink('currentPlanTasks') planTasks: PlanTask[] = [
    { id: 't1', title: '复习数组与链表基础', date: '2026-06-27', estimatedMin: 60, type: 'review', done: true },
    { id: 't2', title: '练习栈与队列题目', date: '2026-06-28', estimatedMin: 90, type: 'practice', done: true },
    { id: 't3', title: '学习二叉树遍历', date: '2026-06-29', estimatedMin: 75, type: 'reading', done: false },
  ];

  aboutToAppear(): void {
    this.loadCourses();
    this.loadPlan();
  }

  private async loadCourses(): Promise<void> {
    try {
      const response = await HttpClient.get<CoursesResponse>(
        Constants.API_COURSES + '?userId=' + Constants.DEMO_USER_ID
      );
      if (response.courses.length > 0) {
        this.currentCourse = response.courses[0];
      }
    } catch (e) {
      // 调试模式保留默认课程，避免首页因后端未启动而失去主任务。
    }
  }

  private async loadPlan(): Promise<void> {
    try {
      const plan = await HttpClient.get<StudyPlan>(
        Constants.API_PLAN + '?userId=' + Constants.DEMO_USER_ID
      );
      this.planTasks = plan.tasks;
    } catch (e) {
      // 调试模式保留默认任务，确保首页仍可展示主要行动。
    }
  }

  private taskStatus(task: PlanTask, index: number): string {
    if (task.done) return '已完成';
    for (let i = 0; i < index; i++) {
      if (!this.planTasks[i].done) return '待开始';
    }
    return '进行中';
  }

  private async toggleTask(task: PlanTask): Promise<void> {
    const request: PlanTaskUpdate = {
      userId: Constants.DEMO_USER_ID,
      taskId: task.id,
      done: !Boolean(task.done),
    };
    try {
      const plan = await HttpClient.patch<StudyPlan>(
        Constants.API_PLAN_SAVE,
        JSON.stringify(request)
      );
      this.planTasks = plan.tasks;
    } catch (e) {
      // 网络失败时保持服务端状态，不做虚假本地打卡。
    }
  }

  private currentTaskTitle(): string {
    for (const task of this.planTasks) {
      if (!task.done) return task.title;
    }
    return '今日任务已完成';
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
            this.notificationOpen = !this.notificationOpen;
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
          Text('学习计划已同步，完成任务会自动更新进度')
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
              Text('当前章节')
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
          .backgroundColor(this.taskStatus(task, index) === '已完成' ? Constants.COLOR_SUCCESS_LIGHT :
            this.taskStatus(task, index) === '进行中' ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
          .border({
            width: 1,
            color: this.taskStatus(task, index) === '已完成' ? Constants.COLOR_SUCCESS :
              this.taskStatus(task, index) === '进行中' ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER,
          })
          .borderRadius(17)
        if (this.taskStatus(task, index) === '已完成') {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(16)
            .fontColor([Constants.COLOR_SUCCESS])
        } else if (this.taskStatus(task, index) === '进行中') {
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

      Text(this.taskStatus(task, index))
        .fontSize(11)
        .fontColor(this.taskStatus(task, index) === '已完成' ? Constants.COLOR_SUCCESS :
          this.taskStatus(task, index) === '进行中' ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.taskStatus(task, index) === '已完成' ? Constants.COLOR_SUCCESS_LIGHT :
          this.taskStatus(task, index) === '进行中' ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
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
        ForEach(this.planTasks.slice(0, 3), (task: PlanTask, index: number) => {
          this.TaskRow(task, index)
          if (index < Math.min(this.planTasks.length, 3) - 1) {
            Divider()
              .color(Constants.COLOR_BORDER)
              .margin({ left: 46 })
          }
        })
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
