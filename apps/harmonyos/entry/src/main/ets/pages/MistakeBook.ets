import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ReviewItem } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ReviewGroup {
  key: string;
  title: string;
  subtitle: string;
  dueCount: number;
  totalAttempts: number;
  items: ReviewItem[];
}

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

  private courseTitleFor(courseId: string): string {
    const titles: string[] = ['数据结构', '操作系统', '计算机网络'];
    const ids: string[] = ['cs101', 'cs102', 'cs103'];
    const index = ids.indexOf(courseId);
    return index >= 0 ? titles[index] : '课程';
  }

  private isDue(item: ReviewItem): boolean {
    return new Date(item.nextReviewAt).getTime() <= Date.now();
  }

  private primaryTag(item: ReviewItem): string {
    for (const tag of item.tags ?? []) {
      const normalized = tag.trim();
      if (normalized.length > 0) return normalized;
    }
    return item.topic.length > 0 ? item.topic : '未标记';
  }

  private reviewGroups(): ReviewGroup[] {
    const groups: ReviewGroup[] = [];
    for (const item of this.items) {
      const due = this.isDue(item);
      const tag = this.primaryTag(item);
      const key = (due ? 'due:' : 'active:') + tag;
      let group = groups.find((value: ReviewGroup): boolean => value.key === key);
      if (group === undefined) {
        group = {
          key: key,
          title: tag,
          subtitle: due ? '今日到期，先复盘再进入新题' : '同标签集中巩固，减少零散刷题',
          dueCount: 0,
          totalAttempts: 0,
          items: []
        };
        groups.push(group);
      }
      group.items.push(item);
      group.totalAttempts += item.attempts;
      if (due) group.dueCount += 1;
    }
    return groups.sort((left: ReviewGroup, right: ReviewGroup): number => {
      if (left.dueCount !== right.dueCount) return right.dueCount - left.dueCount;
      if (left.items.length !== right.items.length) return right.items.length - left.items.length;
      return right.totalAttempts - left.totalAttempts;
    });
  }

  private groupSummary(group: ReviewGroup): string {
    const dueText = group.dueCount > 0 ? group.dueCount.toString() + ' 道今日复习 · ' : '';
    return dueText + group.items.length.toString() + ' 道错题 · 累计错 ' + group.totalAttempts.toString() + ' 次';
  }

  private reviewTimeLabel(item: ReviewItem): string {
    if (this.isDue(item)) return '今日复习';
    return '下次复习 ' + item.nextReviewAt.slice(5, 10);
  }

  private askTutor(item: ReviewItem): void {
    AppStorage.setOrCreate<string>('selectedCourseId', item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitleFor(item.courseId));
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '我在错题本里反复错了“' + this.primaryTag(item) + '”相关问题：' + item.stem +
        '。我的答案是“' + item.userAnswer + '”，正确答案是“' + item.correctAnswer +
        '”。请先指出错因，再给我一组复盘步骤。');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage tutor navigation failed: %{public}s', error.message);
    });
  }

  private retry(item: ReviewItem): void {
    AppStorage.setOrCreate<string>('selectedCourseId', item.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitleFor(item.courseId));
    AppStorage.setOrCreate<string>('selectedPracticeTopic', item.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'MistakeBookPage navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  private ReviewCard(item: ReviewItem) {
    Column({ space: 10 }) {
      Row() {
        Row({ space: 6 }) {
          Text(item.topic)
            .fontSize(11)
            .fontColor(Constants.COLOR_ERROR)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(Constants.COLOR_ERROR_LIGHT)
            .borderRadius(Constants.RADIUS_SM)
          Text(this.reviewTimeLabel(item))
            .fontSize(11)
            .fontColor(this.isDue(item) ? Constants.COLOR_WARNING : Constants.COLOR_TEXT_SECONDARY)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.isDue(item) ? Constants.COLOR_BG_TAG : Constants.COLOR_SURFACE_TINT)
            .borderRadius(Constants.RADIUS_SM)
        }
        Text('错 ' + item.attempts.toString() + ' 次')
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
      Row({ space: 8 }) {
        Button(this.expandedId === item.id ? '收起解析' : '查看解析')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.expandedId = this.expandedId === item.id ? '' : item.id; })
        Button('问学伴')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.askTutor(item); })
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
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
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
          ForEach(this.reviewGroups(), (group: ReviewGroup): void => {
            ListItem() {
              Column({ space: 12 }) {
                Column({ space: 6 }) {
                  Row() {
                    Text(group.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    Text(group.dueCount > 0 ? '优先' : '巩固')
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(group.dueCount > 0 ? Constants.COLOR_WARNING : Constants.COLOR_BRAND)
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(group.dueCount > 0 ? Constants.COLOR_BG_TAG : Constants.COLOR_BRAND_LIGHT)
                      .borderRadius(9)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  Text(this.groupSummary(group))
                    .width('100%')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  Text(group.subtitle)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                .width('100%')

                ForEach(group.items, (item: ReviewItem): void => {
                  this.ReviewCard(item)
                })
              }
            }
          })
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
