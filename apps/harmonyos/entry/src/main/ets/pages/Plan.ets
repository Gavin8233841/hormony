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

  get canGenerate(): boolean {
    return !this.loading && this.goal.trim().length > 0;
  }

  build() {
    Column() {
      GradientHeader('学习计划', '输入目标，自动拆解为每日任务', () => this.getUIContext().getRouter().back())

      // 输入区
      Column({ space: 12 }) {
        TextInput({ text: this.goal, placeholder: '学习目标，如：两周复习数据结构' })
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(12)
          .onChange((v: string) => { this.goal = v; })

        Row({ space: 12 }) {
          Column() {
            Text('周期（天）')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .margin({ bottom: 4 })
            TextInput({ text: this.days.toString() })
              .fontSize(14)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(12)
              .width('100%')
              .onChange((v: string) => { this.days = parseInt(v) || 14; })
          }
          .layoutWeight(1)

          Button('生成计划')
            .fontSize(14)
            .backgroundColor(this.canGenerate ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .fontColor(this.canGenerate ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .borderRadius(12)
            .height(40)
            .enabled(this.canGenerate)
            .onClick(() => { this.generate(); })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)

      // 任务列表
      if (this.tasks.length > 0) {
        Text('计划任务（' + this.tasks.length + ' 项）')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ left: 16, bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.tasks, (t: PlanTask, i: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text('' + (i + 1))
                  .fontSize(14)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .width(24)

                Column() {
                  Text(t.title)
                    .fontSize(14)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Row({ space: 12 }) {
                    Text(t.date)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(t.estimatedMin.toString() + ' 分钟')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(t.type)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .backgroundColor(Constants.COLOR_BG_TASK_TAG)
                      .borderRadius(6)
                  }
                  .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
              .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
            }
          })
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      } else if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Constants.COLOR_BRAND)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 空状态
        Column() {
          Text('输入学习目标，生成每日计划')
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async generate() {
    if (this.goal.trim().length === 0) return;
    this.loading = true;
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
        // 调试模式：回退演示任务
        const task1: PlanTask = { id: '1', title: '复习树与二叉树', date: '2026-06-25', estimatedMin: 45, type: '复习' };
        const task2: PlanTask = { id: '2', title: '练习 BST 习题', date: '2026-06-26', estimatedMin: 30, type: '练习' };
        this.tasks = [task1, task2];
      }
    } finally {
      this.loading = false;
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
