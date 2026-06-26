/**
 * 鸿学伴 - 首页
 * 今日学习概览 + 快捷入口
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
      this.message = `加载失败: ${(e as Error).message ?? String(e)}`;
    }
  }

  build() {
    Column() {
      // 顶部问候
      Column() {
        Text('鸿学伴')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .width('100%')

        Text('今天学什么？')
          .fontSize(14)
          .fontColor('#929292')
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 36, bottom: 20 })

      // 学习概览卡片
      Row({ space: 10 }) {
        // 提问数
        Column() {
          Text(this.profile?.stats?.totalQuestions?.toString() ?? '0')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0a59f7')
          Text('提问')
            .fontSize(12)
            .fontColor('#929292')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)

        // 正确率
        Column() {
          Text(this.profile ? `${Math.round(this.profile.stats.accuracy * 100)}%` : '0%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4caf50')
          Text('正确率')
            .fontSize(12)
            .fontColor('#929292')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)

        // 学习天数
        Column() {
          Text(this.profile?.stats?.studyDays?.toString() ?? '0')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ff9800')
          Text('学习天')
            .fontSize(12)
            .fontColor('#929292')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 快捷功能区标题
      Text('学习功能')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1a1a1a')
        .width('100%')
        .padding({ left: 24, top: 28, bottom: 8 })

      // 功能入口 - 直接内联，不使用 @Builder
      Column({ space: 10 }) {
        // 问问鸿学伴
        Row() {
          Column() {
            Text('问问鸿学伴')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1a1a1a')
            Text('向 AI 助教提问，获取带引用的讲解')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ top: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor('#cccccc')
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .border({ width: { left: 4 }, color: { left: '#0a59f7' } })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Chat' }).catch((err: Error) => {
            console.error(`router.pushUrl failed: ${err.message}`);
          });
        })

        // 学习计划
        Row() {
          Column() {
            Text('学习计划')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1a1a1a')
            Text('输入目标，自动拆解为每日任务')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ top: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor('#cccccc')
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .border({ width: { left: 4 }, color: { left: '#4caf50' } })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Plan' }).catch((err: Error) => {
            console.error(`router.pushUrl failed: ${err.message}`);
          });
        })

        // 搜课程资料
        Row() {
          Column() {
            Text('搜课程资料')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1a1a1a')
            Text('搜索课程知识点和相关资料')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ top: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor('#cccccc')
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .border({ width: { left: 4 }, color: { left: '#ff9800' } })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Knowledge' }).catch((err: Error) => {
            console.error(`router.pushUrl failed: ${err.message}`);
          });
        })

        // 我的课程
        Row() {
          Column() {
            Text('我的课程')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1a1a1a')
            Text('查看课程进度和学习资料')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ top: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor('#cccccc')
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .border({ width: { left: 4 }, color: { left: '#9c27b0' } })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Course' }).catch((err: Error) => {
            console.error(`router.pushUrl failed: ${err.message}`);
          });
        })

        // 学习画像
        Row() {
          Column() {
            Text('学习画像')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1a1a1a')
            Text('查看薄弱点和优势，针对性提升')
              .fontSize(12)
              .fontColor('#929292')
              .margin({ top: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor('#cccccc')
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .border({ width: { left: 4 }, color: { left: '#00bcd4' } })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Profile' }).catch((err: Error) => {
            console.error(`router.pushUrl failed: ${err.message}`);
          });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 底部留白
      Blank().height(40)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor('#e53935')
          .padding({ left: 24, right: 24, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f6f8')
  }
}
