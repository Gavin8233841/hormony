/**
 * 学习计划页
 * 浅色主题 · 用户友好文案 · 任务列表
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { StudyPlan, PlanTask, PlanRequest } from '../model/DataModels';

@Entry
@Component
struct PlanPage {
  @State goal: string = '';
  @State days: number = 14;
  @State tasks: PlanTask[] = [];
  @State loading: boolean = false;

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#1a1a1a')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Column() {
          Text('学习计划')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')
          Text('输入目标，自动拆解任务')
            .fontSize(12)
            .fontColor('#929292')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      // 输入区
      Column({ space: 12 }) {
        TextInput({ text: this.goal, placeholder: '学习目标，如：两周复习数据结构' })
          .fontSize(14)
          .backgroundColor('#ffffff')
          .borderRadius(12)
          .onChange((v: string) => { this.goal = v; })

        Row({ space: 12 }) {
          Column() {
            Text('周期（天）')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ bottom: 4 })
            TextInput({ text: this.days.toString() })
              .fontSize(14)
              .backgroundColor('#ffffff')
              .borderRadius(12)
              .width('100%')
              .onChange((v: string) => { this.days = parseInt(v) || 14; })
          }
          .layoutWeight(1)

          Button('生成计划')
            .fontSize(14)
            .backgroundColor('#0a59f7')
            .fontColor('#ffffff')
            .borderRadius(12)
            .height(40)
            .enabled(!this.loading && this.goal.length > 0)
            .onClick(() => { this.generate(); })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)

      // 任务列表
      if (this.tasks.length > 0) {
        Text(`计划任务（${this.tasks.length} 项）`)
          .fontSize(14)
          .fontColor('#929292')
          .margin({ left: 16, bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.tasks, (t: PlanTask, i: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(`${i + 1}`)
                  .fontSize(14)
                  .fontColor('#929292')
                  .width(24)

                Column() {
                  Text(t.title)
                    .fontSize(14)
                    .fontColor('#1a1a1a')
                  Row({ space: 12 }) {
                    Text(t.date)
                      .fontSize(11)
                      .fontColor('#929292')
                    Text(`${t.estimatedMin} 分钟`)
                      .fontSize(11)
                      .fontColor('#929292')
                    Text(t.type)
                      .fontSize(11)
                      .fontColor('#929292')
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .backgroundColor('#f0f1f3')
                      .borderRadius(6)
                  }
                  .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#ffffff')
              .borderRadius(12)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      } else if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#0a59f7')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 空状态
        Column() {
          Text('输入学习目标，生成每日计划')
            .fontSize(14)
            .fontColor('#cccccc')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f6f8')
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
      const plan = await HttpClient.post<StudyPlan>(Constants.API_PLAN, req);
      this.tasks = plan.tasks;
    } catch (e) {
      // 回退演示
      const task1: PlanTask = { id: '1', title: '复习树与二叉树', date: '2026-06-25', estimatedMin: 45, type: '复习' };
      const task2: PlanTask = { id: '2', title: '练习 BST 习题', date: '2026-06-26', estimatedMin: 30, type: '练习' };
      this.tasks = [task1, task2];
    } finally {
      this.loading = false;
    }
  }
}
