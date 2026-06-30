/**
 * 学习画像页
 * 浅色主题 · 加载状态 · 内联统计卡片
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { UserProfile } from '../model/DataModels';

@Component
export struct ProfileContent {
  @State profile: UserProfile | null = null;
  @State loading: boolean = false;
  @State message: string = '';

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
      if (!Constants.__DEBUG__) {
        this.message = '学习画像加载失败，请检查网络后重试';
      }
    } finally {
      this.loading = false;
    }
  }

  @Builder
  Metric(value: string, label: string, color: ResourceColor) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ProfileSkeleton() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        Column().width(56).height(56).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(28)
        Column({ space: 8 }) {
          Column().width(130).height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
          Column().width(180).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        }
        .alignItems(HorizontalAlign.Start)
      }
      Column().width('100%').height(92).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(150).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
    }
    .width('100%')
    .padding(16)
  }

  build() {
    Column() {
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

      if (this.loading) {
        this.ProfileSkeleton()
      } else if (this.profile) {
        Scroll() {
          Column({ space: 12 }) {
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
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })

            Row() {
              this.Metric(Math.round(this.profile.stats.accuracy * 100).toString() + '%', '正确率', Constants.COLOR_SUCCESS)
              Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
              this.Metric(this.profile.stats.totalQuestions.toString(), '累计答题', Constants.COLOR_TEXT_PRIMARY)
              Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
              this.Metric(this.profile.stats.studyDays.toString(), '学习天数', Constants.COLOR_BRAND)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })

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

              Divider().color(Constants.COLOR_BORDER).margin({ top: 10, bottom: 14 })

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
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.person'))
            .fontSize(42)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.message.length > 0 ? this.message : '暂无学习画像')
            .fontSize(15)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
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
