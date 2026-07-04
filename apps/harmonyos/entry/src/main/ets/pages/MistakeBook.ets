import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ReviewItem } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct MistakeBookPage {
  @State items: ReviewItem[] = [];
  @State reviewSummary: string = '0 道待巩固 · 0 道今日复习';
  @State expandedId: string = '';
  @State askedReviewIds: string[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadItems();
  }

  private async loadItems(): Promise<void> {
    try {
      const dueItems = await LocalLearningRepository.getDueReviewItems();
      const allItems = await LocalLearningRepository.getReviewItems(false);
      const activeItems = allItems.filter((item: ReviewItem): boolean => !item.resolved);
      const resolvedItems = allItems.filter((item: ReviewItem): boolean => item.resolved)
        .sort((left: ReviewItem, right: ReviewItem): number =>
          new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime());
      const dueIds = dueItems.map((item: ReviewItem): string => item.id);
      this.items = dueItems
        .concat(activeItems.filter((item: ReviewItem): boolean => !dueIds.includes(item.id)))
        .concat(resolvedItems);
      this.reviewSummary = activeItems.length.toString() + ' 道待巩固 · ' +
        dueItems.length.toString() + ' 道今日复习 · ' + resolvedItems.length.toString() + ' 道已解决';
    } catch (error) {
      this.message = '错题记录读取失败';
    } finally {
      this.loading = false;
    }
  }

  private itemStatus(item: ReviewItem): string {
    if (item.resolved) return 'resolved';
    if (this.askedReviewIds.includes(item.id)) return 'asked';
    return 'open';
  }

  private groupItems(status: string): ReviewItem[] {
    return this.items.filter((item: ReviewItem): boolean => this.itemStatus(item) === status);
  }

  private statusTitle(status: string): string {
    if (status === 'asked') return '已追问';
    if (status === 'resolved') return '已解决';
    return '未复盘';
  }

  private statusDescription(status: string): string {
    if (status === 'asked') return '已带题干、答案、解析进入学伴，回来后继续重练';
    if (status === 'resolved') return '连续答对后进入低优先级，默认排在后面';
    return '先看解析或向学伴追问，再安排同主题重练';
  }

  private statusColor(status: string): string {
    if (status === 'asked') return Constants.COLOR_BRAND;
    if (status === 'resolved') return Constants.COLOR_SUCCESS;
    return Constants.COLOR_ERROR;
  }

  private statusBg(status: string): string {
    if (status === 'asked') return Constants.COLOR_BRAND_LIGHT;
    if (status === 'resolved') return Constants.COLOR_SUCCESS_LIGHT;
    return Constants.COLOR_ERROR_LIGHT;
  }

  private reviewDateText(item: ReviewItem): string {
    const raw = item.nextReviewAt.trim();
    if (raw.length >= 10) return raw.substring(0, 10);
    return '待安排';
  }

  private tagsText(item: ReviewItem): string {
    const tags = item.tags ?? [];
    if (tags.length === 0) return '未标注标签';
    return tags.join('、');
  }

  private markAsked(item: ReviewItem): void {
    if (this.askedReviewIds.includes(item.id)) return;
    const nextIds = this.askedReviewIds.slice();
    nextIds.push(item.id);
    this.askedReviewIds = nextIds;
  }

  private askTutor(item: ReviewItem): void {
    this.markAsked(item);
    const question = '请结合课程资料帮我复盘这道错题。题干：' + item.stem +
      '。我的答案：' + (item.userAnswer.length > 0 ? item.userAnswer : '未作答') +
      '。正确答案：' + item.correctAnswer +
      '。解析：' + item.explanation +
      '。标签：' + this.tagsText(item) +
      '。请先指出我可能卡住的概念，再给一个同标签小练习。';
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage Chat navigation failed: %{public}s', error.message);
      this.message = '无法打开学伴，请重试';
    });
  }

  private retry(item: ReviewItem): void {
    const titles: string[] = ['数据结构', '操作系统', '计算机网络'];
    const ids: string[] = ['cs101', 'cs102', 'cs103'];
    const index = ids.indexOf(item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseId', item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', index >= 0 ? titles[index] : '课程');
    AppStorage.setOrCreate<string>('selectedPracticeTopic', item.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  SectionHeader(status: string, count: number) {
    Row({ space: 10 }) {
      Text(this.statusTitle(status))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Text(count.toString() + ' 道')
        .fontSize(11)
        .fontColor(this.statusColor(status))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.statusBg(status))
        .borderRadius(9)
      Text(this.statusDescription(status))
        .fontSize(11)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 6, bottom: 2 })
  }

  @Builder
  MistakeCard(item: ReviewItem) {
    Column({ space: 10 }) {
      Row() {
        Text(item.topic)
          .fontSize(11)
          .fontColor(this.statusColor(this.itemStatus(item)))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.statusBg(this.itemStatus(item)))
          .borderRadius(Constants.RADIUS_SM)
        Text('错 ' + item.attempts.toString() + ' 次 · 复习 ' + this.reviewDateText(item))
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
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
      Row({ space: 10 }) {
        Button(this.expandedId === item.id ? '收起解析' : '查看解析')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.expandedId = this.expandedId === item.id ? '' : item.id; })
        Button('向学伴追问')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.askTutor(item); })
        Button('重练')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.retry(item); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .opacity(item.resolved ? 0.72 : 1)
  }

  @Builder
  MistakeSection(status: string) {
    if (this.groupItems(status).length > 0) {
      ListItem() {
        this.SectionHeader(status, this.groupItems(status).length)
      }
      ForEach(this.groupItems(status), (item: ReviewItem): void => {
        ListItem() {
          this.MistakeCard(item)
        }
      })
    }
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
          this.MistakeSection('open')
          this.MistakeSection('asked')
          this.MistakeSection('resolved')
        }
        .width('100%')
        .height('100%')
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
