/**
 * 学习画像页
 * 浅色主题 · 加载状态 · 内联统计卡片
 */

import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { UserProfile } from '../model/DataModels';
import { LearningTagInsight as TagInsight } from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct ProfileContent {
  @State profile: UserProfile | null = null;
  @State tagInsights: TagInsight[] = [];
  @State loading: boolean = false;
  @State message: string = '';

  aboutToAppear() {
    this.loading = true;
    this.loadProfile();
  }

  async loadProfile() {
    try {
      this.profile = await LocalLearningRepository.getProfile();
      this.tagInsights = await LocalLearningRepository.getTagInsights(5);
    } catch (e) {
      this.message = '本地学习画像加载失败，请重新打开应用';
    } finally {
      this.loading = false;
    }
  }

  private openLearningMap(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/LearningMap' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ProfileContent LearningMap navigation failed: %{public}s', error.message);
    });
  }

  private openPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ProfileContent page navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  GrowthEntry(title: string, subtitle: string, icon: Resource, url: string) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(38).height(38).backgroundColor(Constants.COLOR_BRAND_LIGHT).borderRadius(12)
        SymbolGlyph(icon).fontSize(20).fontColor([Constants.COLOR_BRAND])
      }
      Column({ space: 3 }) {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(subtitle).fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(17).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
    }
    .width('100%')
    .height(62)
    .onClick((): void => { this.openPage(url); })
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

  private tagMasteryLevel(item: TagInsight): string {
    if (item.totalQuestions < 2) return '尝试';
    if (item.accuracy >= 0.9 && item.totalQuestions >= 6 && item.wrongQuestions === 0) return '掌握';
    if (item.accuracy >= 0.8 && item.totalQuestions >= 4 && item.wrongQuestions <= 1) return '熟练';
    if (item.accuracy >= 0.6) return '熟悉';
    return '尝试';
  }

  private tagMasteryColor(item: TagInsight): string {
    const level = this.tagMasteryLevel(item);
    if (level === '掌握' || level === '熟练') return Constants.COLOR_SUCCESS;
    if (level === '熟悉') return Constants.COLOR_WARNING;
    return Constants.COLOR_BRAND;
  }

  private tagMasteryBackground(item: TagInsight): string {
    const level = this.tagMasteryLevel(item);
    if (level === '掌握' || level === '熟练') return Constants.COLOR_SUCCESS_LIGHT;
    if (level === '熟悉') return Constants.COLOR_BG_TAG;
    return Constants.COLOR_BRAND_LIGHT;
  }

  private difficultyLabel(value: string): string {
    if (value === 'easy') return '基础';
    if (value === 'hard') return '挑战';
    return '进阶';
  }

  private practicedAtLabel(value: string): string {
    if (value.length >= 10) return value.slice(5, 7) + '月' + value.slice(8, 10) + '日';
    return '最近练习';
  }

  private tagMasteryAdvice(item: TagInsight): string {
    if (item.totalQuestions < 2) return '先完成 2 题建立基线';
    if (item.wrongQuestions > 0) return item.nextStep;
    if (this.tagMasteryLevel(item) === '掌握') return '保持复习节奏，下次挑战综合题';
    return item.nextStep;
  }

  @Builder
  TagInsightRow(item: TagInsight) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(item.tag)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('样本 ' + item.totalQuestions.toString() + ' 题 · 正确 ' + item.correctQuestions.toString() + ' 题')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.tagMasteryLevel(item))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tagMasteryColor(item))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.tagMasteryBackground(item))
          .borderRadius(Constants.RADIUS_SM)
      }
      .width('100%')
      Progress({ value: Math.round(item.accuracy * 100), total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(this.tagMasteryColor(item))
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        .borderRadius(4)
      Row({ space: 8 }) {
        Text(Math.round(item.accuracy * 100).toString() + '% 正确率')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
        Text('错题 ' + item.wrongQuestions.toString() + ' 道')
          .fontSize(11)
          .fontColor(item.wrongQuestions > 0 ? Constants.COLOR_ERROR : Constants.COLOR_SUCCESS)
        Text(this.practicedAtLabel(item.lastPracticedAt))
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        Text('基础 ' + item.easyQuestions.toString())
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .margin({ right: 6, bottom: 4 })
        Text('进阶 ' + item.mediumQuestions.toString())
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .margin({ right: 6, bottom: 4 })
        Text('挑战 ' + item.hardQuestions.toString())
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .margin({ right: 6, bottom: 4 })
        Text('最近 ' + this.difficultyLabel(item.lastDifficulty))
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .margin({ right: 6, bottom: 4 })
      }
      .width('100%')
      Column({ space: 4 }) {
        Text(item.weakReason)
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
          .lineHeight(18)
        Text('下一步：' + this.tagMasteryAdvice(item))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_SM)
    }
    .width('100%')
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

            Column() {
              this.GrowthEntry('学习记录', '按时间回看练习与任务', $r('sys.symbol.clock'), 'pages/ActivityRecords')
              Divider().color(Constants.COLOR_BORDER).margin({ left: 50 })
              this.GrowthEntry('错题本', '集中复习尚未解决的问题', $r('sys.symbol.xmark_circle_fill'), 'pages/MistakeBook')
              Divider().color(Constants.COLOR_BORDER).margin({ left: 50 })
              this.GrowthEntry('成就', '用真实完成记录解锁里程碑', $r('sys.symbol.star_fill'), 'pages/Achievements')
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 4, bottom: 4 })
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)

            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width('100%')
                .height(184)
                .backgroundColor(Constants.COLOR_MAP_SURFACE)
                .borderRadius(Constants.RADIUS_LG)

              Line()
                .width(250)
                .height(116)
                .startPoint([125, 58])
                .endPoint([30, 22])
                .stroke(Constants.COLOR_MAP_LINE)
                .strokeWidth(1)
              Line()
                .width(250)
                .height(116)
                .startPoint([125, 58])
                .endPoint([218, 18])
                .stroke(Constants.COLOR_MAP_LINE)
                .strokeWidth(1)
              Line()
                .width(250)
                .height(116)
                .startPoint([125, 58])
                .endPoint([207, 102])
                .stroke(Constants.COLOR_MAP_LINE)
                .strokeWidth(1)

              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(62)
                  .height(42)
                  .backgroundColor(Constants.COLOR_MAP_CORE)
                  .borderRadius(14)
                  .shadow({ radius: 7, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 2 })
                SymbolGlyph($r('sys.symbol.book_open_fill'))
                  .fontSize(20)
                  .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
              }
              .width(62)
              .height(42)
              Column().width(30).height(30).backgroundColor(Constants.COLOR_BRAND).borderRadius(15).opacity(0.12).position({ x: 29, y: 31 })
              Column().width(10).height(10).backgroundColor(Constants.COLOR_BRAND).borderRadius(5).position({ x: 39, y: 41 })
              Column().width(28).height(28).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(14).opacity(0.14).position({ x: 239, y: 23 })
              Column().width(12).height(12).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(6).position({ x: 247, y: 31 })
              Column().width(24).height(24).backgroundColor(Constants.COLOR_WARNING).borderRadius(12).opacity(0.14).position({ x: 227, y: 124 })
              Column().width(9).height(9).backgroundColor(Constants.COLOR_WARNING).borderRadius(5).position({ x: 235, y: 132 })

              Column({ space: 5 }) {
                Text('学习星图')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('查看知识之间的联系与掌握状态')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
              }
              .alignItems(HorizontalAlign.Start)
              .position({ x: 22, y: 118 })

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(20)
                .fontColor([Constants.COLOR_TEXT_PRIMARY])
                .position({ x: 292, y: 137 })
            }
            .width('100%')
            .height(184)
            .onClick((): void => { this.openLearningMap(); })

            Row() {
              this.Metric(Math.round(this.profile.stats.accuracy * 100).toString() + '%', '正确率', Constants.COLOR_SUCCESS)
              Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
              this.Metric(this.profile.stats.totalQuestions.toString(), '累计答题', Constants.COLOR_TEXT_PRIMARY)
              Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
              this.Metric(this.profile.stats.streakDays.toString(), '连续天数', Constants.COLOR_BRAND)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })

            Column({ space: 12 }) {
              Row() {
                Text('标签洞察')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('错因与下一步')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              if (this.tagInsights.length === 0) {
                Text('完成带标签的练习后，这里会显示能力短板和复习优先级')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .lineHeight(20)
              } else {
                ForEach(this.tagInsights, (item: TagInsight, index: number): void => {
                  this.TagInsightRow(item)
                  if (index < this.tagInsights.length - 1) {
                    Divider().color(Constants.COLOR_BORDER)
                  }
                })
              }
            }
            .width('100%')
            .padding(16)
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
          .padding({ left: 16, right: 16, bottom: 12 + SafeAreaInsets.bottomVp() })
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
