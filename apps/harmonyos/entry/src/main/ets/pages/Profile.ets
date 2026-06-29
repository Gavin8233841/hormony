/**
 * 学习画像页
 * 浅色主题 · 加载状态 · 内联统计卡片
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { StatCard, GradientHeader } from '../common/Builders';
import { UserProfile } from '../model/DataModels';

@Component
export struct ProfileContent {
  @Prop embedded: boolean = false;
  @State profile: UserProfile | null = null;
  @State loading: boolean = false;
  @State pressedSection: number = -1;

  aboutToAppear() {
    // 调试模式：先加载演示数据，避免网络等待时空白
    if (Constants.__DEBUG__) {
      this.profile = {
        userId: 'demo',
        name: '演示同学',
        stage: '本科二年级',
        weakTopics: ['树与图', '动态规划', '操作系统调度'],
        strongTopics: ['数组', '链表', '基础语法'],
        learningStyle: '视觉型',
        stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 },
      };
    } else {
      this.loading = true;
    }
    this.loadProfile();
  }

  async loadProfile() {
    try {
      this.profile = await HttpClient.get<UserProfile>(
        Constants.API_PROFILE + '?userId=' + Constants.DEMO_USER_ID
      );
    } catch (e) {
      // __DEBUG__ 模式下保留 aboutToAppear 中设置的演示数据
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      if (this.embedded) {
        Column() {
          Text('我的')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('你的学习节奏与成长记录')
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: 24, bottom: 18 })
      } else {
        GradientHeader('学习画像', '查看薄弱点和优势', () => this.getUIContext().getRouter().back())
      }

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Constants.COLOR_BRAND)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.profile) {
        // 基本信息卡片
        Row({ space: 16 }) {
          Text(this.profile.name.charAt(0))
            .fontSize(28)
            .fontColor(Constants.COLOR_BRAND)
            .width(56)
            .height(56)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(28)
            .textAlign(TextAlign.Center)

          Column() {
            Text(this.profile.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text(this.profile.stage + ' · ' + this.profile.learningStyle)
              .fontSize(13)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(12)
        .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
        .margin({ left: 16, right: 16, bottom: 16 })

        // 统计卡片
        Row({ space: 10 }) {
          StatCard(
            Math.round(this.profile.stats.accuracy * 100).toString() + '%',
            '正确率',
            Constants.COLOR_SUCCESS
          )
          StatCard(
            this.profile.stats.totalQuestions.toString(),
            '累计答题',
            Constants.COLOR_WARNING
          )
          StatCard(
            this.profile.stats.studyDays.toString(),
            '学习天数',
            Constants.COLOR_BRAND
          )
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })

        // 薄弱知识点
        Column() {
          Text('薄弱知识点')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.weakTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor(Constants.COLOR_ERROR)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(Constants.COLOR_ERROR_LIGHT)
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(12)
        .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
        .margin({ left: 16, right: 16, bottom: 12 })
        .alignItems(HorizontalAlign.Start)
        .scale({ x: this.pressedSection === 0 ? 0.98 : 1, y: this.pressedSection === 0 ? 0.98 : 1 })
        .animation({ duration: 100, curve: Curve.EaseOut })
        .onTouch((event?: TouchEvent) => {
          if (event) {
            if (event.type === TouchType.Down) {
              this.pressedSection = 0;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedSection = -1;
            }
          }
        })

        // 已掌握知识点
        Column() {
          Text('已掌握知识点')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.profile.strongTopics, (t: string) => {
              Text(t)
                .fontSize(12)
                .fontColor(Constants.COLOR_SUCCESS)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
                .borderRadius(10)
                .margin({ right: 6, bottom: 6, top: 8 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(12)
        .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
        .margin({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
        .scale({ x: this.pressedSection === 1 ? 0.98 : 1, y: this.pressedSection === 1 ? 0.98 : 1 })
        .animation({ duration: 100, curve: Curve.EaseOut })
        .onTouch((event?: TouchEvent) => {
          if (event) {
            if (event.type === TouchType.Down) {
              this.pressedSection = 1;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedSection = -1;
            }
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}

@Entry
@Component
struct ProfilePage {
  build() {
    Column() {
      ProfileContent()
    }
  }
}
