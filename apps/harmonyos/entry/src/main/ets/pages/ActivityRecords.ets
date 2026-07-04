import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import {
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight
} from '../model/LearningMetadataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct ActivityRecordsPage {
  @State events: StudyEvent[] = [];
  @State tagInsights: TagInsight[] = [];
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

  private isFirstOfDay(index: number): boolean {
    if (index === 0) return true;
    return this.events[index - 1].timestamp.slice(0, 10) !== this.events[index].timestamp.slice(0, 10);
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
          if (this.tagInsights.length > 0) {
            ListItem() {
              Column({ space: 12 }) {
                Row() {
                  Text('标签掌握等级')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('样本 · 错题 · 下一步')
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                ForEach(this.tagInsights, (item: TagInsight): void => {
                  Column({ space: 8 }) {
                    Row({ space: 8 }) {
                      Column({ space: 3 }) {
                        Text(item.tag)
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(Constants.COLOR_TEXT_PRIMARY)
                        Text('样本 ' + item.totalQuestions.toString() + ' 题 · 错题 ' +
                          item.wrongQuestions.toString() + ' 道')
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
                    Row({ space: 10 }) {
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
                    Row({ space: 8 }) {
                      Text(this.practicedAtLabel(item.lastPracticedAt))
                        .fontSize(10)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(Constants.COLOR_BG_TAG)
                        .borderRadius(Constants.RADIUS_SM)
                      Text('最近 ' + this.difficultyLabel(item.lastDifficulty))
                        .fontSize(10)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(Constants.COLOR_BG_TAG)
                        .borderRadius(Constants.RADIUS_SM)
                    }
                    .width('100%')
                    Text('下一步：' + this.tagMasteryAdvice(item))
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_BRAND)
                  }
                  .width('100%')
                  .padding({ top: 2, bottom: 6 })
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          }
          ForEach(this.events, (event: StudyEvent, index: number): void => {
            ListItem() {
              Column() {
                if (this.isFirstOfDay(index)) {
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
