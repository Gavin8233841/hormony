import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, QuizResult, QuizResultDetail, StudyEvent, TagInsight } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface TagReviewTarget {
  tag: string;
  courseId: string;
  courseTitle: string;
  topic: string;
}

@Entry
@Component
struct ActivityRecordsPage {
  @State events: StudyEvent[] = [];
  @State tagInsights: TagInsight[] = [];
  @State tagReviewTargets: TagReviewTarget[] = [];
  @State courses: Course[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    try {
      this.events = (await LocalLearningRepository.getStudyEvents()).slice().reverse();
      this.tagInsights = await LocalLearningRepository.getTagInsights(4);
      this.courses = await LocalLearningRepository.getCourses() ?? [];
      const results = await LocalLearningRepository.getQuizResults();
      this.tagReviewTargets = this.buildTagReviewTargets(this.tagInsights, results);
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
    if (event.topic !== undefined && event.totalQuestions !== undefined && event.correctCount !== undefined) {
      return event.topic + ' · ' + event.correctCount.toString() + '/' + event.totalQuestions.toString() + ' 题正确';
    }
    if (event.topic !== undefined) return event.topic;
    if (event.taskId !== undefined) return '任务 ' + event.taskId;
    return '本地学习记录';
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

  private courseTitleFor(courseId: string): string {
    for (const course of this.courses) {
      if (course.id === courseId) return course.title;
    }
    return '课程';
  }

  private detailHasTag(detail: QuizResultDetail, tag: string): boolean {
    for (const value of detail.tags ?? []) {
      if (value.trim() === tag) return true;
    }
    return false;
  }

  private buildTagReviewTargets(insights: TagInsight[], results: QuizResult[]): TagReviewTarget[] {
    const targets: TagReviewTarget[] = [];
    const recentResults = results.slice().reverse();
    for (const insight of insights) {
      for (const result of recentResults) {
        let matched = false;
        for (const detail of result.details) {
          if (this.detailHasTag(detail, insight.tag)) {
            matched = true;
            break;
          }
        }
        if (matched) {
          targets.push({
            tag: insight.tag,
            courseId: result.courseId,
            courseTitle: this.courseTitleFor(result.courseId),
            topic: result.topic
          });
          break;
        }
      }
    }
    return targets;
  }

  private targetForTag(tag: string): TagReviewTarget | null {
    for (const target of this.tagReviewTargets) {
      if (target.tag === tag) return target;
    }
    return null;
  }

  private reviewTag(tag: string): void {
    const target = this.targetForTag(tag);
    if (target === null) {
      this.message = '暂时无法定位标签来源';
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', target.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', target.courseTitle);
    AppStorage.setOrCreate<string>('knowledgePrefillQuery', target.tag);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Knowledge' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage knowledge navigation failed: %{public}s', error.message);
      this.message = '无法打开资料检索，请重试';
    });
  }

  private quizTag(tag: string): void {
    const target = this.targetForTag(tag);
    if (target === null) {
      this.message = '暂时无法定位标签来源';
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', target.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', target.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', target.topic.length > 0 ? target.topic : '综合');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage quiz navigation failed: %{public}s', error.message);
      this.message = '无法打开 AI 测验，请重试';
    });
  }

  private openEvent(event: StudyEvent): void {
    if (event.courseId === undefined) return;
    AppStorage.setOrCreate<string>('selectedCourseId', event.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitleFor(event.courseId));
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
                  Text('最近薄弱标签')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('可直接复习')
                    .fontSize(11)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                ForEach(this.tagInsights, (item: TagInsight): void => {
                  Column({ space: 8 }) {
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
                    Row({ space: 8 }) {
                      Text('错 ' + item.wrongQuestions.toString() + ' 题 · 最近 ' + this.dateLabel(item.lastPracticedAt))
                        .layoutWeight(1)
                        .fontSize(11)
                        .fontColor(Constants.COLOR_TEXT_TERTIARY)
                      Button('复习')
                        .height(32)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_BRAND)
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                        .onClick((): void => { this.reviewTag(item.tag); })
                      Button('再测')
                        .height(32)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                        .backgroundColor(Constants.COLOR_BRAND)
                        .borderRadius(Constants.RADIUS_SM)
                        .onClick((): void => { this.quizTag(item.tag); })
                    }
                    .width('100%')
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
