/**
 * 学习画像页
 * 浅色主题 · 加载状态 · 内联统计卡片
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { UserProfile } from '../model/DataModels';

@Entry
@Component
struct ProfilePage {
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;

  aboutToAppear() {
    this.loadProfile();
  }

  async loadProfile() {
    this.loading = true;
    try {
      this.profile = await HttpClient.get<UserProfile>(
        `${Constants.API_PROFILE}?userId=${Constants.DEMO_USER_ID}`
      );
    } catch (e) {
      // 回退演示数据
      this.profile = {
        userId: 'demo',
        name: '演示同学',
        stage: '本科二年级',
        weakTopics: ['树与图', '动态规划', '操作系统调度'],
        strongTopics: ['数组', '链表', '基础语法'],
        learningStyle: '视觉型',
        stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 },
      };
    } finally {
      this.loading = false;
    }
  }

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
          Text('学习画像')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#0a59f7')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.profile) {
        // 基本信息卡片
        Row({ space: 16 }) {
          Text(this.profile.name.charAt(0))
            .fontSize(28)
            .fontColor('#0a59f7')
            .width(56)
            .height(56)
            .backgroundColor('#0a59f720')
            .borderRadius(28)
            .textAlign(TextAlign.Center)

          Column() {
            Text(this.profile.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a1a')
            Text(`${this.profile.stage} · ${this.profile.learningStyle}`)
              .fontSize(13)
              .fontColor('#929292')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 16 })

        // 统计卡片（内联，不用 @Builder）
        Row({ space: 10 }) {
          // 正确率
          Column() {
            Text(`${Math.round(this.profile.stats.accuracy * 100)}%`)
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

          // 累计答题
          Column() {
            Text(this.profile.stats.totalQuestions.toString())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#ff9800')
            Text('累计答题')
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
            Text(this.profile.stats.studyDays.toString())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0a59f7')
            Text('学习天数')
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
        .padding({ left: 16, right: 16, bottom: 16 })

        // 薄弱知识点
        Column() {
          Text('薄弱知识点')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1a1a1a')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.weakTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor('#e53935')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#e5393520')
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 12 })
        .alignItems(HorizontalAlign.Start)

        // 已掌握知识点
        Column() {
          Text('已掌握知识点')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1a1a1a')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.strongTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor('#4caf50')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#4caf5020')
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')
        .borderRadius(12)
        .margin({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f6f8')
  }
}
