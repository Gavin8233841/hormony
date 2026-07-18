import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, LessonProgress } from '../model/DataModels';
import {
  CourseResumeState,
  resolveCourseResumeState,
  resolveNextTopic,
  resolveTopicAction
} from './CourseResumeState';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct CourseDetailPage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topics: string[] = [];
  @State completedTopics: string[] = [];
  @State lessonProgress: LessonProgress[] = [];
  @State progress: number = 0;
  @State message: string = '';
  @State loading: boolean = true;
  @State progressReady: boolean = false;
  @StorageProp('safeAreaBottomVp') safeAreaBottomVpValue: number = 0;
  private loadRunId: number = 0;

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topics = LearningContentRepository.getTopics(this.courseId);
    this.loadProgress();
  }

  private async loadProgress(): Promise<void> {
    const runId = this.loadRunId + 1;
    this.loadRunId = runId;
    this.loading = true;
    this.message = '';
    try {
      const courses = await LocalLearningRepository.getCourses();
      if (courses === null) throw new Error('本地课程目录不存在');
      const course = courses.find((item: Course): boolean => item.id === this.courseId);
      const lessonProgress = await LocalLearningRepository.getLessonProgress(this.courseId);
      const events = await LocalLearningRepository.getStudyEvents();
      const resumeState = resolveCourseResumeState(this.courseId, this.topics, lessonProgress);
      const completed: string[] = [];
      for (const event of events) {
        if (event.courseId === this.courseId && event.topic !== undefined &&
          (event.type === 'lesson_completed' || event.type === 'quiz_mastered') &&
          !completed.includes(event.topic)) {
          completed.push(event.topic);
        }
      }
      for (const topic of resumeState.completedTopics) {
        if (!completed.includes(topic)) completed.push(topic);
      }
      if (this.loadRunId !== runId) return;
      this.progress = course?.progress ?? 0;
      this.lessonProgress = lessonProgress;
      this.completedTopics = completed;
      this.progressReady = true;
    } catch (error) {
      if (this.loadRunId !== runId) return;
      this.progressReady = false;
      this.message = '本地学习进度加载失败';
    } finally {
      if (this.loadRunId === runId) this.loading = false;
    }
  }

  private openTopic(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseDetailPage Lesson navigation failed: %{public}s', err.message);
      this.message = '暂时无法打开该主题，请再次点击重试';
    });
  }

  private topicStatusLabel(topic: string): string {
    return resolveTopicAction(topic, this.completedTopics, this.nextTopic(), this.resumeState());
  }

  private resumeState(): CourseResumeState {
    return resolveCourseResumeState(this.courseId, this.topics, this.lessonProgress);
  }

  private nextTopic(): string {
    return resolveNextTopic(this.topics, this.completedTopics, this.resumeState());
  }

  private nextTopicHint(): string {
    const topic = this.nextTopic();
    if (topic.length === 0) return '';
    return topic === this.resumeState().recentTopic ? '继续 · ' + topic : '下一步 · ' + topic;
  }

  private completedTopicCount(): number {
    return this.topics.filter((topic: string): boolean => this.completedTopics.includes(topic)).length;
  }

  private safeAreaBottomVp(): number {
    return Math.max(0, this.safeAreaBottomVpValue);
  }

  private topicAccentColor(topic: string): string {
    if (this.completedTopics.includes(topic)) return Constants.COLOR_SUCCESS;
    return topic === this.nextTopic() ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_TERTIARY;
  }

  private topicSurfaceColor(topic: string): string {
    if (this.completedTopics.includes(topic)) return Constants.COLOR_SUCCESS_LIGHT;
    return topic === this.nextTopic() ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD;
  }

  @Builder
  private CourseDetailSkeleton() {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Row() {
          Column().width(112).height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
          Column().width(48).height(20).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        Column().width('100%').height(8).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(4)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      Column().width('100%').height(88).backgroundColor(Constants.COLOR_BG_SKELETON)
        .borderRadius(Constants.RADIUS_LG)
      Column().width('100%').height(82).backgroundColor(Constants.COLOR_BG_SKELETON)
        .borderRadius(Constants.RADIUS_MD)
      Column().width('100%').height(82).backgroundColor(Constants.COLOR_BG_SKELETON)
        .borderRadius(Constants.RADIUS_MD)
      Column().width('100%').height(82).backgroundColor(Constants.COLOR_BG_SKELETON)
        .borderRadius(Constants.RADIUS_MD)
    }
    .width('100%')
  }

  @Builder
  private NextTopicAction() {
    if (this.nextTopic().length > 0) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(44)
              .height(44)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
            SymbolGlyph($r('sys.symbol.book_open_fill'))
              .fontSize(22)
              .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
          }
          Column({ space: 4 }) {
            Text(this.nextTopic() === this.resumeState().recentTopic ? '继续上次主题' : '开始下一主题')
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND_TEXT)
            Text(this.nextTopic())
              .width('100%')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(17)
            .fontColor([Constants.COLOR_BRAND])
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 88 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
      .borderRadius(Constants.RADIUS_LG)
      .accessibilityText((this.nextTopic() === this.resumeState().recentTopic ? '继续上次主题，' : '开始下一主题，') +
        this.nextTopic())
      .onClick((): void => { this.openTopic(this.nextTopic()); })
    }
  }

  build() {
    Column() {
      GradientHeader(this.courseTitle, this.topics.length.toString() + ' 个知识主题',
        () => this.getUIContext().getRouter().back())

      if (this.loading) {
        Column() {
          this.CourseDetailSkeleton()
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 28 + this.safeAreaBottomVp() })
      } else if (!this.progressReady) {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
            .fontSize(36)
            .fontColor([Constants.COLOR_ERROR])
          Text(this.message.length > 0 ? this.message : '暂时无法读取课程进度')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('课程内容没有被修改，可在当前页面重新读取')
            .fontSize(12)
            .lineHeight(19)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Button('重新读取进度')
            .constraintSize({ minHeight: 48 })
            .padding({ left: 18, right: 18 })
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.loadProgress(); })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24, bottom: this.safeAreaBottomVp() })
      } else if (this.topics.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(38)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('该课程还没有可学习的主题')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 20 }) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('课程进度')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('完成 ' + this.completedTopicCount().toString() + ' / ' + this.topics.length.toString() + ' 个主题')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                Text(Math.round(this.progress * 100).toString() + '%')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_BRAND_TEXT)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
                .width('100%')
                .color(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
            }
            .width('100%')

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(12)
                .fontColor(Constants.COLOR_ERROR)
            }

            this.NextTopicAction()

            Row() {
              Text('全部主题')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              if (this.nextTopic().length > 0) {
                Text(this.nextTopicHint())
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_BRAND_TEXT)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(Constants.RADIUS_SM)
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Column({ space: 8 }) {
              ForEach(this.topics, (topic: string, index: number): void => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(38)
                        .height(38)
                        .borderRadius(12)
                        .backgroundColor(this.topicSurfaceColor(topic))
                      Text((index + 1).toString())
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.topicAccentColor(topic))
                    }
                    Column({ space: 4 }) {
                      Text(topic)
                        .width('100%')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Constants.COLOR_TEXT_PRIMARY)
                        .maxLines(2)
                      Text(LearningContentRepository.getKnowledge(this.courseId, topic).length.toString() +
                        ' 个小节 · ' + LearningContentRepository.getQuestions(this.courseId, topic).length.toString() +
                        ' 道精选练习')
                        .width('100%')
                        .fontSize(11)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    Column({ space: 5 }) {
                      Text(this.topicStatusLabel(topic))
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.topicAccentColor(topic))
                      SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontSize(14)
                        .fontColor([this.topicAccentColor(topic)])
                    }
                    .alignItems(HorizontalAlign.End)
                  }
                  .width('100%')
                }
                .width('100%')
                .constraintSize({ minHeight: 82 })
                .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                .backgroundColor(this.topicSurfaceColor(topic))
                .borderRadius(Constants.RADIUS_MD)
                .accessibilityText(topic + '，' + this.topicStatusLabel(topic))
                .onClick((): void => { this.openTopic(topic); })
              })
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxWidth: 760 })
          .padding({ left: 16, right: 16, bottom: 28 + this.safeAreaBottomVp() })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
