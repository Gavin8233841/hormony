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
        List({ space: 12 }) {
          ForEach(this.achievements, (item: AchievementProgress): void => {
            ListItem() {
              Row({ space: 14 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(54)
                    .height(54)
                    .backgroundColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BG_TAG)
                    .borderRadius(27)
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(26)
                    .fontColor([this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_PLACEHOLDER])
                }
                Column({ space: 7 }) {
                  Row() {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.COLOR_TEXT_PRIMARY)
                    Text(this.isUnlocked(item) ? '已解锁' : item.current.toString() + '/' + item.target.toString())
                      .fontSize(11)
                      .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  Text(item.description).fontSize(12).fontColor(Constants.COLOR_TEXT_SECONDARY)
                  Progress({ value: item.current, total: item.target, type: ProgressType.Linear })
                    .width('100%')
                    .color(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                    .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(18)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          })
        }
        .width('100%')
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
