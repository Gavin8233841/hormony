import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ReviewItem } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct MistakeBookPage {
  @State items: ReviewItem[] = [];
  @State reviewSummary: string = '0 道待巩固 · 0 道今日复习';
  @State expandedId: string = '';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadItems();
  }

  private async loadItems(): Promise<void> {
    try {
      const dueItems = await LocalLearningRepository.getDueReviewItems();
      const activeItems = await LocalLearningRepository.getReviewItems();
      const dueIds = dueItems.map((item: ReviewItem): string => item.id);
      this.items = dueItems.concat(activeItems.filter((item: ReviewItem): boolean => !dueIds.includes(item.id)));
      this.reviewSummary = this.items.length.toString() + ' 道待巩固 · ' +
        dueItems.length.toString() + ' 道今日复习';
    } catch (error) {
      this.message = '错题记录读取失败';
    } finally {
      this.loading = false;
    }
  }

  private retry(item: ReviewItem): void {
    this.prepareCourse(item);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', item.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage practice navigation failed: %{public}s', error.message);
    });
  }

  private openQuiz(item: ReviewItem): void {
    this.prepareCourse(item);
    AppStorage.setOrCreate<string>('selectedQuizTopic', item.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage quiz navigation failed: %{public}s', error.message);
    });
  }

  private askTutor(item: ReviewItem): void {
    this.prepareCourse(item);
    const question = '请结合课程资料讲解这道错题：' + item.stem +
      '。我的答案是“' + item.userAnswer + '”，正确答案是“' + item.correctAnswer +
      '”。请用步骤说明我应该如何判断，并给一个同类小练习。';
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage chat navigation failed: %{public}s', error.message);
    });
  }

  private prepareCourse(item: ReviewItem): void {
    const titles: string[] = ['数据结构', '操作系统', '计算机网络'];
    const ids: string[] = ['cs101', 'cs102', 'cs103'];
    const index = ids.indexOf(item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseId', item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', index >= 0 ? titles[index] : '课程');
  }

  private isDue(item: ReviewItem): boolean {
    return new Date(item.nextReviewAt).getTime() <= Date.now();
  }

  private reviewStatusLabel(item: ReviewItem): string {
    if (this.isDue(item)) return '今日复习';
    return '下次 ' + this.shortDate(item.nextReviewAt);
  }

  private reviewStatusColor(item: ReviewItem): string {
    return this.isDue(item) ? Constants.COLOR_WARNING : Constants.COLOR_TEXT_SECONDARY;
  }

  private reviewStatusBackground(item: ReviewItem): string {
    return this.isDue(item) ? Constants.COLOR_ERROR_LIGHT : Constants.COLOR_BG_TAG;
  }

  private shortDate(timestamp: string): string {
    if (timestamp.length < 10) return '待定';
    return timestamp.slice(5, 7) + '/' + timestamp.slice(8, 10);
  }

  build() {
    Column() {
      if (this.loading) {
        TitleBar('错题本', '正在读取本地复习队列', () => this.getUIContext().getRouter().back())
      } else {
        TitleBar('错题本', this.reviewSummary, () => this.getUIContext().getRouter().back())
      }
      if (this.loading) {
        Column().width('90%').height(200).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
      } else if (this.items.length === 0) {
        Column({ space: 9 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(42).fontColor([Constants.COLOR_SUCCESS])
          Text(this.message.length > 0 ? this.message : '当前没有待巩固错题')
            .fontSize(15)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.message.length === 0) {
            Text('完成精选练习或 AI 测验后会自动整理')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: ReviewItem): void => {
            ListItem() {
              Column({ space: 10 }) {
                Row() {
                  Text(item.topic)
                    .fontSize(11)
                    .fontColor(Constants.COLOR_ERROR)
                    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                    .backgroundColor(Constants.COLOR_ERROR_LIGHT)
                    .borderRadius(Constants.RADIUS_SM)
                  Text(this.reviewStatusLabel(item))
                    .fontSize(11)
                    .fontColor(this.reviewStatusColor(item))
                    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                    .backgroundColor(this.reviewStatusBackground(item))
                    .borderRadius(Constants.RADIUS_SM)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                Text('错 ' + item.attempts.toString() + ' 次 · 间隔 ' + item.intervalDays.toString() + ' 天')
                  .width('100%')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                if ((item.tags ?? []).length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(item.tags ?? [], (tag: string): void => {
                      Text(tag)
                        .fontSize(10)
                        .fontColor(Constants.COLOR_BRAND)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(9)
                        .margin({ right: 6, bottom: 2 })
                    })
                  }
                  .width('100%')
                }
                Text(item.stem)
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  .lineHeight(23)
                if (this.expandedId === item.id) {
                  Column({ space: 7 }) {
                    Text('你的答案：' + item.userAnswer).fontSize(12).fontColor(Constants.COLOR_ERROR)
                    Text('正确答案：' + item.correctAnswer).fontSize(12).fontColor(Constants.COLOR_SUCCESS)
                    Text('复习节奏：第 ' + item.attempts.toString() + ' 次 · ' +
                      this.reviewStatusLabel(item))
                      .fontSize(12)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                    Text(item.explanation).fontSize(12).lineHeight(20).fontColor(Constants.COLOR_TEXT_SECONDARY)
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding(12)
                  .backgroundColor(Constants.COLOR_SURFACE_TINT)
                  .borderRadius(Constants.RADIUS_MD)
                }
                Row({ space: 10 }) {
                  Button(this.expandedId === item.id ? '收起解析' : '查看解析')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    .backgroundColor(Constants.COLOR_BG_TAG)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.expandedId = this.expandedId === item.id ? '' : item.id; })
                  Button('重练主题')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                    .backgroundColor(Constants.COLOR_BRAND)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.retry(item); })
                }
                .width('100%')
                Row({ space: 10 }) {
                  Button('AI 测验')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                    .backgroundColor(Constants.COLOR_SUCCESS)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.openQuiz(item); })
                  Button('问学伴讲题')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_BRAND)
                    .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.askTutor(item); })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          })
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
