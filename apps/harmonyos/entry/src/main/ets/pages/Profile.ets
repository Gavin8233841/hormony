/**
 * 个人画像页
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { UserProfile } from '../model/DataModels';

@Entry
@Component
struct ProfilePage {
  @State profile: UserProfile | null = null;

  aboutToAppear() {
    this.loadProfile();
  }

  async loadProfile() {
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
    }
  }

  build() {
    Column() {
      Text('个人画像')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 4, left: 20 })
        .width('100%')

      Text('Profile Agent 维护的学习画像')
        .fontSize(13)
        .fontColor('#94a3b8')
        .margin({ bottom: 20, left: 20 })
        .width('100%')

      if (this.profile) {
        // 基本信息卡片
        Row({ space: 16 }) {
          Text(this.profile.name.charAt(0))
            .fontSize(28)
            .fontColor('#3b82f6')
            .width(56)
            .height(56)
            .backgroundColor('#3b82f620')
            .borderRadius(28)
            .textAlign(TextAlign.Center)

          Column() {
            Text(this.profile.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e2e8f0')
            Text(`${this.profile.stage} · ${this.profile.learningStyle}`)
              .fontSize(13)
              .fontColor('#94a3b8')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1e293b')
        .borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 16 })

        // 统计
        Row({ space: 12 }) {
          this.StatBox(`${Math.round(this.profile.stats.accuracy * 100)}%`, '正确率', '#10b981')
          this.StatBox(this.profile.stats.totalQuestions.toString(), '累计答题', '#f59e0b')
          this.StatBox(this.profile.stats.studyDays.toString(), '学习天数', '#3b82f6')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })

        // 薄弱知识点
        Column() {
          Text('薄弱知识点').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#e2e8f0')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.weakTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor('#fca5a5')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#ef444420')
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1e293b')
        .borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 12 })
        .alignItems(HorizontalAlign.Start)

        // 已掌握知识点
        Column() {
          Text('已掌握知识点').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#e2e8f0')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.strongTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor('#6ee7b7')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#10b98120')
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1e293b')
        .borderRadius(12)
        .margin({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }

  @Builder
  StatBox(value: string, label: string, color: string) {
    Column() {
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor('#94a3b8').margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor('#1e293b')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }
}
