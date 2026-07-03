import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import {
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight
} from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ActivityDay {
  key: string;
  label: string;
  count: number;
  mastered: boolean;
}

@Entry
@Component
struct ActivityRecordsPage {
  @State events: StudyEvent[] = [];
  @State tagInsights: TagInsight[] = [];
  @State selectedFilter: string = 'all';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    try {
      this.events = (await LocalLearningRepository.getStudyEvents()).slice().reverse();
      this.tagInsights = await LocalLearningRepository.getTagInsights(4);
    } catch (error) {
      this.message = '学习记录读取失败';
    } finally {
      this.loading = false;
    }
  }

  private title(event: StudyEvent): string {
    if (event.type === 'task_completed') return '完成学习任务';
    if (event.type === 'lesson_completed') return '完成课程主题';
    if (event.type === 'quiz_mastered') return '掌握练习主题';
    if (event.type === 'quiz_submitted') return '提交练习';
    return '学习活动';
  }

  private detail(event: StudyEvent): string {
    const source = event.source === 'ai' ? 'AI 出题' : (event.source === 'curated' ? '精选题库' : '');
    const difficulty = event.difficulty !== undefined ? this.difficultyLabel(event.difficulty) : '';
    const prefix = source.length > 0 || difficulty.length > 0 ? source + (source.length > 0 && difficulty.length > 0 ? ' · ' : '') + difficulty + ' · ' : '';
    if (event.topic !== undefined && event.totalQuestions !== undefined && event.correctCount !== undefined) {
      return prefix + event.topic + ' · ' + event.correctCount.toString() + '/' + event.totalQuestions.toString() + ' 题正确';
    }
    if (event.topic !== undefined) return event.topic;
    if (event.taskId !== undefined) return '任务 ' + event.taskId;
    return '本地学习记录';
  }

  private difficultyLabel(value: string): string {
    if (value === 'easy') return '基础';
    if (value === 'hard') return '挑战';
    return '进阶';
  }

  private icon(event: StudyEvent): Resource {
    if (event.type === 'task_completed' || event.type === 'lesson_completed') {
      return $r('sys.symbol.checkmark_circle_fill');
    }
    return $r('sys.symbol.book_open_fill');
  }

  private iconColor(event: StudyEvent): string {
    if (event.type === 'task_completed' || event.type === 'lesson_completed' || event.type === 'quiz_mastered') {
      return Constants.COLOR_SUCCESS;
    }
    return Constants.COLOR_BRAND;
  }

  private iconBackground(event: StudyEvent): string {
    if (event.type === 'task_completed' || event.type === 'lesson_completed' || event.type === 'quiz_mastered') {
      return Constants.COLOR_SUCCESS_LIGHT;
    }
    return Constants.COLOR_BRAND_LIGHT;
  }

  private tagMasteryLabel(item: TagInsight): string {
    if (item.totalQuestions <= 0) return '未开始';
    if (item.totalQuestions < 3) return '已接触';
    if (item.accuracy < 0.6) return '待巩固';
    if (item.accuracy < 0.8) return '熟悉中';
    return '已掌握';
  }

  private tagMasteryColor(item: TagInsight): string {
    if (item.totalQuestions < 3) return Constants.COLOR_TEXT_TERTIARY;
    if (item.accuracy < 0.6) return Constants.COLOR_ERROR;
    if (item.accuracy < 0.8) return Constants.COLOR_WARNING;
    return Constants.COLOR_SUCCESS;
  }

  private tagMasteryBackground(item: TagInsight): string {
    if (item.totalQuestions < 3) return Constants.COLOR_BG_TAG;
    if (item.accuracy < 0.6) return Constants.COLOR_ERROR_LIGHT;
    if (item.accuracy < 0.8) return Constants.COLOR_BG_TAG;
    return Constants.COLOR_SUCCESS_LIGHT;
  }

  private localDateKey(date: Date): string {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private activityDays(): ActivityDay[] {
    const days: ActivityDay[] = [];
    const today = new Date();
    for (let offset = 27; offset >= 0; offset--) {
      const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - offset);
      const key = this.localDateKey(date);
      const dayEvents = this.events.filter((event: StudyEvent): boolean => event.timestamp.slice(0, 10) === key);
      days.push({
        key: key,
        label: (date.getMonth() + 1).toString() + '/' + date.getDate().toString(),
        count: dayEvents.length,
        mastered: dayEvents.some((event: StudyEvent): boolean =>
          event.type === 'quiz_mastered' || event.type === 'lesson_completed' || event.type === 'task_completed')
      });
    }
    return days;
  }

  private activityWeeks(): ActivityDay[][] {
    const days = this.activityDays();
    const weeks: ActivityDay[][] = [];
    for (let index = 0; index < days.length; index += 7) {
      weeks.push(days.slice(index, index + 7));
    }
    return weeks;
  }

  private activeDaysCount(): number {
    return this.activityDays().filter((day: ActivityDay): boolean => day.count > 0).length;
  }

  private totalEventsInHeatmap(): number {
    let total = 0;
    for (const day of this.activityDays()) total += day.count;
    return total;
  }

  private bestDayLabel(): string {
    let best: ActivityDay | null = null;
    for (const day of this.activityDays()) {
      if (best === null || day.count > best.count) best = day;
    }
    return best !== null && best.count > 0 ? best.label + ' · ' + best.count.toString() + ' 条' : '还没有连续记录';
  }

  private activityDayColor(day: ActivityDay): string {
    if (day.count === 0) return Constants.COLOR_BG_TAG;
    if (day.mastered) return Constants.COLOR_SUCCESS;
    if (day.count >= 3) return Constants.COLOR_BRAND;
    return Constants.COLOR_BRAND_LIGHT;
  }

  private activityDayTextColor(day: ActivityDay): string {
    if (day.count === 0) return Constants.COLOR_TEXT_PLACEHOLDER;
    if (day.mastered || day.count >= 3) return Constants.COLOR_TEXT_ON_GRADIENT;
    return Constants.COLOR_BRAND;
  }

  private filterLabel(value: string): string {
    if (value === 'quiz') return '练习';
    if (value === 'lesson') return '课程';
    if (value === 'task') return '任务';
    return '全部';
  }

  private eventMatchesFilter(event: StudyEvent): boolean {
    if (this.selectedFilter === 'all') return true;
    if (this.selectedFilter === 'quiz') return event.type === 'quiz_mastered' || event.type === 'quiz_submitted';
    if (this.selectedFilter === 'lesson') return event.type === 'lesson_completed';
    if (this.selectedFilter === 'task') return event.type === 'task_completed';
    return true;
  }

  private filteredEvents(): StudyEvent[] {
    return this.events.filter((event: StudyEvent): boolean => this.eventMatchesFilter(event));
  }

  private isFirstOfDayIn(items: StudyEvent[], index: number): boolean {
    if (index === 0) return true;
    return items[index - 1].timestamp.slice(0, 10) !== items[index].timestamp.slice(0, 10);
  }

  private dateLabel(timestamp: string): string {
    const date = timestamp.slice(0, 10);
    return date.slice(5, 7) + '月' + date.slice(8, 10) + '日';
  }

  private openEvent(event: StudyEvent): void {
    if (event.courseId === undefined) return;
    const titles: string[] = ['数据结构', '操作系统', '计算机网络'];
    const ids: string[] = ['cs101', 'cs102', 'cs103'];
    const index = ids.indexOf(event.courseId);
    AppStorage.setOrCreate<string>('selectedCourseId', event.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', index >= 0 ? titles[index] : '课程');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetail' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  private FilterPill(value: string) {
    Button({ type: ButtonType.Normal }) {
      Text(this.filterLabel(value))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedFilter === value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_TERTIARY)
    }
    .height(34)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.selectedFilter === value ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
    .borderRadius(17)
    .onClick((): void => { this.selectedFilter = value; })
  }

  @Builder
  private ActivityHeatmap() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('近 4 周学习热力')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('真实本地事件 · ' + this.activeDaysCount().toString() + ' 天有记录')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.totalEventsInHeatmap().toString() + ' 条')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_BRAND)
      }
      .width('100%')

      Column({ space: 7 }) {
        ForEach(this.activityWeeks(), (week: ActivityDay[]): void => {
          Row({ space: 7 }) {
            ForEach(week, (day: ActivityDay): void => {
              Column({ space: 2 }) {
                Text(day.count > 0 ? day.count.toString() : '')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.activityDayTextColor(day))
                Text(day.label)
                  .fontSize(8)
                  .fontColor(day.count > 0 ? this.activityDayTextColor(day) : Constants.COLOR_TEXT_PLACEHOLDER)
              }
              .layoutWeight(1)
              .height(42)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.activityDayColor(day))
              .borderRadius(Constants.RADIUS_SM)
            })
          }
          .width('100%')
        })
      }
      .width('100%')

      Row() {
        Text('峰值日：' + this.bestDayLabel())
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
        Row({ space: 6 }) {
          Text('少')
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Column().width(16).height(8).backgroundColor(Constants.COLOR_BG_TAG).borderRadius(4)
          Column().width(16).height(8).backgroundColor(Constants.COLOR_BRAND_LIGHT).borderRadius(4)
          Column().width(16).height(8).backgroundColor(Constants.COLOR_BRAND).borderRadius(4)
          Column().width(16).height(8).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(4)
          Text('多')
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  build() {
    Column() {
      if (this.loading) {
        TitleBar('学习记录', '正在读取本地记录', () => this.getUIContext().getRouter().back())
      } else {
        TitleBar('学习记录', this.events.length.toString() + ' 条活动 · 仅保存在本机',
          () => this.getUIContext().getRouter().back())
      }
      if (this.loading) {
        Column().width('90%').height(180).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
      } else if (this.events.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.clock')).fontSize(38).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.message.length > 0 ? this.message : '完成第一次学习后，记录会出现在这里')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ListItem() {
            this.ActivityHeatmap()
          }

          ListItem() {
            Row({ space: 8 }) {
              this.FilterPill('all')
              this.FilterPill('quiz')
              this.FilterPill('lesson')
              this.FilterPill('task')
            }
            .width('100%')
            .padding({ left: 2, right: 2 })
          }

          if (this.tagInsights.length > 0) {
            ListItem() {
              Column({ space: 12 }) {
                Row() {
                  Text('最近薄弱标签')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('用于安排下一次复习')
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                ForEach(this.tagInsights, (item: TagInsight): void => {
                  Column({ space: 6 }) {
                    Row({ space: 10 }) {
                      Text(item.tag)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_BRAND)
                        .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                      Text(this.tagMasteryLabel(item))
                        .fontSize(10)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.tagMasteryColor(item))
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(this.tagMasteryBackground(item))
                        .borderRadius(9)
                      Progress({ value: Math.round(item.accuracy * 100), total: 100, type: ProgressType.Linear })
                        .layoutWeight(1)
                        .color(this.tagMasteryColor(item))
                        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                        .borderRadius(4)
                      Text(Math.round(item.accuracy * 100).toString() + '%')
                        .fontSize(11)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    }
                    .width('100%')
                    Text(item.weakReason)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                      .lineHeight(18)
                    Text('下一步：' + item.nextStep)
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_BRAND)
                  }
                  .width('100%')
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          }
          ForEach(this.filteredEvents(), (event: StudyEvent, index: number): void => {
            ListItem() {
              Column() {
                if (this.isFirstOfDayIn(this.filteredEvents(), index)) {
                  Row() {
                    Text(this.dateLabel(event.timestamp))
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                    if (index === 0) {
                      Text('最近')
                        .fontSize(10)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_BRAND)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .padding({ left: 4, right: 4, top: index === 0 ? 2 : 12, bottom: 2 })
                }

                Row({ space: 12 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    Column()
                      .width(44)
                      .height(44)
                      .backgroundColor(this.iconBackground(event))
                      .borderRadius(Constants.RADIUS_MD)
                    SymbolGlyph(this.icon(event))
                      .fontSize(21)
                      .fontColor([this.iconColor(event)])
                  }
                  Column({ space: 4 }) {
                    Text(this.title(event))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    Text(this.detail(event))
                      .fontSize(12)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Text(event.timestamp.slice(11, 16))
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  if (event.courseId !== undefined) {
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(15)
                      .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
                  }
                }
                .width('100%')
                .constraintSize({ minHeight: 76 })
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_LG)
                .onClick((): void => { this.openEvent(event); })
              }
              .width('100%')
            }
          })
          if (this.filteredEvents().length === 0) {
            ListItem() {
              Column({ space: 8 }) {
                Text('这个筛选下暂时没有记录')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('完成一次' + this.filterLabel(this.selectedFilter) + '后会自动出现')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .padding(18)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          }
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
