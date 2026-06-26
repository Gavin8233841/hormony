/**
 * 仪表盘首页
 * 统计卡片 + 快捷入口 + Agent 架构概览
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { UserProfile } from '../model/DataModels';

@Entry
@Component
struct Index {
  @State profile: UserProfile | null = null;
  @State message: string = '';

  aboutToAppear() {
    this.loadProfile();
  }

  async loadProfile() {
    try {
      this.profile = await HttpClient.get<UserProfile>(
        `${Constants.API_PROFILE}?userId=${Constants.DEMO_USER_ID}`
      );
    } catch (e) {
      this.message = `加载失败: ${e}`;
    }
  }

  build() {
    Column() {
      // 标题
      Text('学习仪表盘')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 4, left: 20 })
        .width('100%')

      Text('多智能体协作的校园学习助理')
        .fontSize(13)
        .fontColor('#94a3b8')
        .margin({ bottom: 20, left: 20 })
        .width('100%')

      // 统计卡片
      Row({ space: 12 }) {
        this.StatCard('累计提问', this.profile?.stats?.totalQuestions?.toString() ?? '--', '#3b82f6')
        this.StatCard('正确率', this.profile ? `${Math.round(this.profile.stats.accuracy * 100)}%` : '--', '#10b981')
        this.StatCard('学习天数', this.profile?.stats?.studyDays?.toString() ?? '--', '#f59e0b')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 快捷入口
      Column({ space: 12 }) {
        this.EntryItem('AI 对话辅导', '向 Tutor Agent 提问，获取带引用的讲解', '/pages/Chat')
        this.EntryItem('生成学习计划', 'Planner Agent 拆解目标为任务', '/pages/Plan')
        this.EntryItem('知识库检索', 'RAG 检索课程资料', '/pages/Knowledge')
        this.EntryItem('我的课程', '查看课程资料纳入 RAG 知识库', '/pages/Course')
        this.EntryItem('个人画像', 'Profile Agent 维护的学习画像', '/pages/Profile')
      }
      .width('100%')
      .padding(16)

      // Agent 架构
      Column() {
        Text('多 Agent 协作架构')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 12 })

        Flex({ wrap: FlexWrap.Wrap }) {
          this.AgentTag('Profile', '#3b82f6')
          this.AgentTag('Retrieval', '#10b981')
          this.AgentTag('Planner', '#f59e0b')
          this.AgentTag('Tutor', '#a855f7')
          this.AgentTag('Quiz', '#ec4899')
          this.AgentTag('Evaluator', '#06b6d4')
          this.AgentTag('Safety', '#ef4444')
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1e293b')
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 20 })

      if (this.message.length > 0) {
        Text(this.message).fontSize(12).fontColor('#ef4444').padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }

  @Builder
  StatCard(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor('#94a3b8')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor('#1e293b')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EntryItem(title: string, desc: string, target: string) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#e2e8f0')
        Text(desc).fontSize(12).fontColor('#94a3b8').margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›').fontSize(20).fontColor('#475569')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#1e293b')
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({ url: target }).catch((err: Error) => {
        console.error(`router.pushUrl failed: ${err.message}`);
      });
    })
  }

  @Builder
  AgentTag(name: string, color: string) {
    Text(name)
      .fontSize(11)
      .fontColor(color)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(`${color}20`)
      .borderRadius(12)
      .margin(4)
  }
}
