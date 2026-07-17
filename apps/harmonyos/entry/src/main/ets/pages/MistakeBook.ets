import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ReviewItem } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct MistakeBookPage {
  @State items: ReviewItem[] = [];
  @State reviewSummary: string = '0 道待巩固 · 0 道已到期';
  @State expandedId: string = '';
  @State loading: boolean = true;
  @State message: string = '';
  @State nowTimestamp: number = Date.now();
  private loadRunId: number = 0;

  onPageShow(): void {
    this.loadItems();
  }

  private async loadItems(): Promise<void> {
    const runId = this.loadRunId + 1;
    this.loadRunId = runId;
    this.loading = true;
    this.message = '';
    try {
      const now = new Date();
      const nowTimestamp = now.getTime();
      const reviewQueue = await LocalLearningRepository.getReviewQueue(now);
      if (this.loadRunId !== runId) return;
      const dueItems = reviewQueue.dueItems;
      const activeItems = reviewQueue.activeItems;
      const dueIds = dueItems.map((item: ReviewItem): string => item.id);
      const pendingItems = activeItems.filter((item: ReviewItem): boolean => !dueIds.includes(item.id))
        .sort((left: ReviewItem, right: ReviewItem): number => {
          const timeGap = new Date(left.nextReviewAt).getTime() - new Date(right.nextReviewAt).getTime();
          return timeGap !== 0 ? timeGap : right.attempts - left.attempts;
        });
      this.nowTimestamp = nowTimestamp;
      this.items = dueItems.concat(pendingItems);
      this.reviewSummary = this.items.length.toString() + ' 道待巩固 · ' +
        dueItems.length.toString() + ' 道已到期';
    } catch (error) {
      if (this.loadRunId !== runId) return;
      this.items = [];
      this.reviewSummary = '复习队列读取失败';
      this.message = '错题记录读取失败';
    } finally {
      if (this.loadRunId === runId) this.loading = false;
    }
  }

  private courseTitle(courseId: string): string {
    if (courseId === 'cs101') return '数据结构';
    if (courseId === 'cs102') return '操作系统';
    if (courseId === 'cs103') return '计算机网络';
    return '课程';
  }

  private isDue(item: ReviewItem): boolean {
    const reviewTime = new Date(item.nextReviewAt).getTime();
    return Number.isNaN(reviewTime) || reviewTime <= this.nowTimestamp;
  }

  private reviewTimeLabel(item: ReviewItem): string {
    if (this.isDue(item)) return '现在复习';
    const nextReview = new Date(item.nextReviewAt);
    if (Number.isNaN(nextReview.getTime())) return '复习时间待同步';
    return (nextReview.getMonth() + 1).toString() + '月' + nextReview.getDate().toString() + '日复习';
  }

  private hasOriginalQuestion(item: ReviewItem): boolean {
    const options = item.options ?? [];
    const labels: string[] = ['A', 'B', 'C', 'D'];
    return options.length === labels.length &&
      options.every((option: string): boolean => option.trim().length > 0) &&
      options.every((option: string, index: number): boolean =>
        option.trim().toUpperCase().startsWith(labels[index] + '.'));
  }

  private retry(item: ReviewItem): void {
    if (!this.isDue(item)) {
      this.message = '这道题尚未到复习时间，请按计划巩固';
      return;
    }
    if (!LearningContentRepository.getTopics(item.courseId).includes(item.topic)) {
      this.message = '错题主题已失效，无法进入练习';
      return;
    }
    this.message = '';
    AppStorage.setOrCreate<string>('selectedCourseId', item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(item.courseId));
    AppStorage.setOrCreate<string>('selectedPracticeTopic', item.topic);
    AppStorage.setOrCreate<string>('selectedReviewItemId', item.id);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      AppStorage.setOrCreate<string>('selectedReviewItemId', '');
      this.message = '无法打开复习，请重试';
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage navigation failed: %{public}s', error.message);
    });
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
      } else if (this.items.length === 0 && this.message.length > 0) {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill')).fontSize(42).fontColor([Constants.COLOR_ERROR])
          Text(this.message)
            .fontSize(15)
            .fontColor(Constants.COLOR_ERROR)
          Button('重新读取')
            .height(40)
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.loadItems(); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column({ space: 9 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(42).fontColor([Constants.COLOR_SUCCESS])
          Text('当前没有待巩固错题')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text('完成精选练习或 AI 测验后会自动整理')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.message.length > 0) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_ERROR])
            Text(this.message)
              .layoutWeight(1)
              .fontSize(12)
              .fontColor(Constants.COLOR_ERROR)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(Constants.COLOR_ERROR_LIGHT)
        }
        List({ space: 12 }) {
          ForEach(this.items, (item: ReviewItem): void => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Text(item.topic)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontSize(11)
                    .fontColor(Constants.COLOR_ERROR)
                    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                    .backgroundColor(Constants.COLOR_ERROR_LIGHT)
                    .borderRadius(Constants.RADIUS_SM)
                  Row({ space: 6 }) {
                    Text('练 ' + item.attempts.toString() + ' 次')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(this.reviewTimeLabel(item))
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.isDue(item) ? Constants.COLOR_ERROR : Constants.COLOR_WARNING)
                      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                      .backgroundColor(this.isDue(item) ? Constants.COLOR_ERROR_LIGHT : Constants.COLOR_BG_TAG)
                      .borderRadius(Constants.RADIUS_SM)
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
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
                    Text(item.explanation).fontSize(12).lineHeight(20).fontColor(Constants.COLOR_TEXT_SECONDARY)
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding(12)
                  .backgroundColor(Constants.COLOR_SURFACE_TINT)
                  .borderRadius(Constants.RADIUS_MD)
                }
                if (!this.hasOriginalQuestion(item)) {
                  Text('此记录未保留完整选项，将使用同主题精选题巩固')
                    .width('100%')
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
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
                  Button(this.isDue(item) ?
                    (this.hasOriginalQuestion(item) ? '重练原题' : '练同主题精选题') : '等待到期')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                    .backgroundColor(this.isDue(item) ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER)
                    .borderRadius(Constants.RADIUS_MD)
                    .enabled(this.isDue(item))
                    .onClick((): void => { this.retry(item); })
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
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 24 + SafeAreaInsets.bottomVp() })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
