import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { AchievementProgress } from '../model/DataModels';

@Entry
@Component
struct AchievementsPage {
  @State achievements: AchievementProgress[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadAchievements();
  }

  private async loadAchievements(): Promise<void> {
    try {
      this.achievements = await LocalLearningRepository.getAchievements();
    } catch (error) {
      this.message = '成就进度读取失败';
    } finally {
      this.loading = false;
    }
  }

  private isUnlocked(item: AchievementProgress): boolean {
    return item.current >= item.target;
  }

  private unlockedCount(): number {
    return this.achievements.filter((item: AchievementProgress): boolean => this.isUnlocked(item)).length;
  }

  private nextAchievementTitle(): string {
    const item = this.achievements.find((achievement: AchievementProgress): boolean => !this.isUnlocked(achievement));
    return item !== undefined ? item.title : '';
  }

  build() {
    Column() {
      TitleBar('成就', '每个里程碑都来自真实学习记录', () => this.getUIContext().getRouter().back())
      if (this.loading) {
        Column().width('90%').height(220).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
      } else if (this.achievements.length === 0) {
        Column() {
          Text(this.message.length > 0 ? this.message : '暂无成就规则')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 16 }) {
          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('里程碑进度')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('坚持完成真实学习任务，逐步点亮成就')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.unlockedCount().toString() + ' / ' + this.achievements.length.toString())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_BRAND)
              }
              .width('100%')

              Progress({ value: this.unlockedCount(), total: this.achievements.length, type: ProgressType.Linear })
                .width('100%')
                .height(6)
                .color(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)

              if (this.nextAchievementTitle().length > 0) {
                Row({ space: 7 }) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(15)
                    .fontColor([Constants.COLOR_WARNING])
                  Text('下一目标 · ' + this.nextAchievementTitle())
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                .width('100%')
              } else {
                Text('当前里程碑已全部解锁')
                  .width('100%')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_SUCCESS)
              }
            }
            .width('100%')
            .padding(18)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(Constants.RADIUS_LG)
          }

          ListItem() {
            Column() {
              Row() {
                Text('全部成就')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text(this.achievements.length.toString() + ' 项')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({ left: 16, right: 16, top: 16, bottom: 8 })

              ForEach(this.achievements, (item: AchievementProgress, index: number): void => {
                Column() {
                  Row({ space: 13 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(46)
                        .height(46)
                        .backgroundColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BG_TAG)
                        .borderRadius(23)
                      SymbolGlyph($r('sys.symbol.star_fill'))
                        .fontSize(22)
                        .fontColor([this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_PLACEHOLDER])
                    }
                    Column({ space: 6 }) {
                      Row() {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Constants.COLOR_TEXT_PRIMARY)
                        Text(this.isUnlocked(item) ? '已解锁' : item.current.toString() + '/' + item.target.toString())
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      Text(item.description)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      Progress({ value: item.current, total: item.target, type: ProgressType.Linear })
                        .width('100%')
                        .height(4)
                        .color(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })

                  if (index < this.achievements.length - 1) {
                    Divider()
                      .color(Constants.COLOR_BORDER)
                      .margin({ left: 75 })
                  }
                }
                .width('100%')
              })
            }
            .width('100%')
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
          }
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 24 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
