/**
 * 学习计划页
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { StudyPlan, PlanTask } from '../model/DataModels';

@Entry
@Component
struct PlanPage {
  @State goal: string = '';
  @State days: number = 14;
  @State tasks: PlanTask[] = [];
  @State loading: boolean = false;

  build() {
    Column() {
      Text('学习计划')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 4, left: 20 })
        .width('100%')

      Text('Planner Agent 根据目标拆解任务')
        .fontSize(13)
        .fontColor('#94a3b8')
        .margin({ bottom: 16, left: 20 })
        .width('100%')

      // 输入区
      Column({ space: 12 }) {
        TextInput({ text: this.goal, placeholder: '学习目标，如：两周复习数据结构' })
          .fontSize(14)
          .backgroundColor('#1e293b')
          .borderRadius(12)
          .onChange((v: string) => { this.goal = v; })

        Row({ space: 12 }) {
          Column() {
            Text('周期（天）').fontSize(12).fontColor('#94a3b8').margin({ bottom: 4 })
            TextInput({ text: this.days.toString() })
              .fontSize(14)
              .backgroundColor('#1e293b')
              .borderRadius(12)
              .width('100%')
              .onChange((v: string) => { this.days = parseInt(v) || 14; })
          }
          .layoutWeight(1)

          Button('生成计划')
            .fontSize(14)
            .backgroundColor('#2563eb')
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
          .fontColor('#94a3b8')
          .margin({ left: 16, bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.tasks, (t: PlanTask, i: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(`${i + 1}`)
                  .fontSize(14)
                  .fontColor('#64748b')
                  .width(24)

                Column() {
                  Text(t.title).fontSize(14).fontColor('#e2e8f0')
                  Row({ space: 12 }) {
                    Text(t.date).fontSize(11).fontColor('#64748b')
                    Text(`${t.estimatedMin} 分钟`).fontSize(11).fontColor('#64748b')
                    Text(t.type).fontSize(11).fontColor('#64748b')
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .backgroundColor('#334155')
                      .borderRadius(6)
                  }
                  .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#1e293b')
              .borderRadius(10)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      } else if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#3b82f6')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }

  async generate() {
    if (this.goal.trim().length === 0) return;
    this.loading = true;
    this.tasks = [];
    try {
      const plan = await HttpClient.post<StudyPlan>(Constants.API_PLAN, {
        userId: Constants.DEMO_USER_ID,
        goal: this.goal.trim(),
        durationDays: this.days,
        dailyMinutes: 90,
      });
      this.tasks = plan.tasks;
    } catch (e) {
      // 回退演示
      this.tasks = [
        { id: '1', title: '复习树与二叉树', date: '2026-06-25', estimatedMin: 45, type: 'review' },
        { id: '2', title: '练习 BST 习题', date: '2026-06-26', estimatedMin: 30, type: 'practice' },
      ];
    } finally {
      this.loading = false;
    }
  }
}
