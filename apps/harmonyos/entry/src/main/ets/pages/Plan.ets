/**
 * 学习计划页
 * 浅色主题 · 用户友好文案 · 任务列表
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { StudyPlan, PlanTask, PlanRequest } from '../model/DataModels';

@Entry
@Component
struct PlanPage {
  @State goal: string = '';
  @State days: number = 14;
  @State tasks: PlanTask[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State hasError: boolean = false;
  private durationOptions: number[] = [7, 14, 21];
  private goalSuggestions: string[] = ['两周复习数据结构', '一周掌握 TCP 基础', '三周准备操作系统考试'];

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
          TextInput({ text: this.goal, placeholder: '例如：两周复习数据结构' })
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
            Text(this.loading ? '正在生成' : '生成学习计划')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canGenerate || this.loading ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
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
            .fontSize(12)
            .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 10 })
      }

      if (this.loading) {
        this.PlanSkeleton()
      } else if (this.tasks.length > 0) {
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
                Text((i + 1).toString())
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_BRAND)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(17)

                Column() {
                  Text(t.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
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
        .padding({ left: 28, right: 28, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async generate(): Promise<void> {
    if (this.goal.trim().length === 0) return;
    this.loading = true;
    this.message = '';
    this.hasError = false;
    this.tasks = [];
    try {
      const req: PlanRequest = {
        userId: Constants.DEMO_USER_ID,
        goal: this.goal.trim(),
        durationDays: this.days,
        dailyMinutes: 90,
      };
      const plan = await HttpClient.post<StudyPlan>(Constants.API_PLAN, JSON.stringify(req));
      this.tasks = plan.tasks;
    } catch (e) {
      if (Constants.__DEBUG__) {
        const task1: PlanTask = { id: '1', title: '梳理核心概念', date: '第 1 天', estimatedMin: 45, type: '复习' };
        const task2: PlanTask = { id: '2', title: '完成章节练习', date: '第 2 天', estimatedMin: 30, type: '练习' };
        const task3: PlanTask = { id: '3', title: '复盘错题与薄弱点', date: '第 3 天', estimatedMin: 40, type: '复盘' };
        this.tasks = [task1, task2, task3];
        this.message = '网络不可用，已生成演示计划';
      } else {
        this.message = '计划生成失败，请稍后重试';
        this.hasError = true;
      }
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
