import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
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

  private courseTitle(courseId: string): string {
    if (courseId === 'cs101') return '数据结构';
    if (courseId === 'cs102') return '操作系统';
    if (courseId === 'cs103') return '计算机网络';
    return '课程';
  }

  private openTagPractice(item: TagInsight): void {
    if (item.lastCourseId === undefined || item.lastTopic === undefined) return;
    const topicQuestions = LearningContentRepository.getQuestions(item.lastCourseId, item.lastTopic);
    const practiceTopic = topicQuestions.length > 0 ? item.lastTopic : '';
    AppStorage.setOrCreate<string>('selectedCourseId', item.lastCourseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(item.lastCourseId));
    AppStorage.setOrCreate<string>('selectedPracticeTopic', practiceTopic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage tag practice navigation failed: %{public}s', error.message);
    });
  }

  private isFirstOfDay(index: number): boolean {
    if (index === 0) return true;
    return this.events[index - 1].timestamp.slice(0, 10) !== this.events[index].timestamp.slice(0, 10);
  }

  private dateLabel(timestamp: string): string {
    const date = timestamp.slice(0, 10);
    return date.slice(5, 7) + '月' + date.slice(8, 10) + '日';
  }

  private openCourseDetail(courseId: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(courseId));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetail' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage navigation failed: %{public}s', error.message);
    });
  }

  private openEventLesson(courseId: string, topic: string): void {
    const chunks = LearningContentRepository.getKnowledge(courseId, topic);
    if (chunks.length === 0) {
      this.openCourseDetail(courseId);
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(courseId));
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage lesson navigation failed: %{public}s', error.message);
    });
  }

  private openEventPractice(courseId: string, topic: string): void {
    const topicQuestions = LearningContentRepository.getQuestions(courseId, topic);
    const practiceTopic = topicQuestions.length > 0 ? topic : '';
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle(courseId));
    AppStorage.setOrCreate<string>('selectedPracticeTopic', practiceTopic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage practice navigation failed: %{public}s', error.message);
    });
  }

  private openEvent(event: StudyEvent): void {
    if (event.courseId === undefined) return;
    if (event.type === 'lesson_completed' && event.topic !== undefined) {
      this.openEventLesson(event.courseId, event.topic);
      return;
    }
    if ((event.type === 'quiz_mastered' || event.type === 'quiz_submitted') && event.topic !== undefined) {
      this.openEventPractice(event.courseId, event.topic);
      return;
    }
    this.openCourseDetail(event.courseId);
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
                      Progress({ value: Math.round(item.accuracy * 100), total: 100, type: ProgressType.Linear })
                        .layoutWeight(1)
                        .color(item.accuracy >= 0.8 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
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
                      Text('下一步：' + item.nextStep)
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_BRAND)
                        .layoutWeight(1)
                      if (item.lastCourseId !== undefined && item.lastTopic !== undefined) {
                        Button({ type: ButtonType.Normal }) {
                          Row({ space: 4 }) {
                            SymbolGlyph($r('sys.symbol.book_open_fill'))
                              .fontSize(13)
                              .fontColor([Constants.COLOR_BRAND])
                            Text('去练习')
                              .fontSize(11)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(Constants.COLOR_BRAND)
                          }
                        }
                        .height(32)
                        .padding({ left: 10, right: 10 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                        .onClick((): void => { this.openTagPractice(item); })
                      }
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
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
        .padding({ left: 16, right: 16, bottom: 24 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
