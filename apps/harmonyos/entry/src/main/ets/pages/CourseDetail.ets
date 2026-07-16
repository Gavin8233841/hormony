import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
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

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topics = LearningContentRepository.getTopics(this.courseId);
    this.loadProgress();
  }

  private async loadProgress(): Promise<void> {
    try {
      const courses = await LocalLearningRepository.getCourses() ?? [];
      const course = courses.find((item: Course): boolean => item.id === this.courseId);
      this.progress = course?.progress ?? 0;
      this.lessonProgress = await LocalLearningRepository.getLessonProgress(this.courseId);
      const events = await LocalLearningRepository.getStudyEvents();
      const completed: string[] = [];
      for (const event of events) {
        if (event.courseId === this.courseId && event.topic !== undefined &&
          (event.type === 'lesson_completed' || event.type === 'quiz_mastered') &&
          !completed.includes(event.topic)) {
          completed.push(event.topic);
        }
      }
      for (const topic of this.resumeState().completedTopics) {
        if (!completed.includes(topic)) completed.push(topic);
      }
      this.completedTopics = completed;
    } catch (error) {
      this.message = '本地学习进度加载失败';
    }
  }

  private openTopic(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseDetailPage Lesson navigation failed: %{public}s', err.message);
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

  build() {
    Column() {
      GradientHeader(this.courseTitle, this.topics.length.toString() + ' 个知识主题',
        () => this.getUIContext().getRouter().back())

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
                .fontColor(Constants.COLOR_BRAND)
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
            Text(this.message).fontSize(12).fontColor(Constants.COLOR_ERROR)
          }

          Row() {
            Text('主题路径')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            if (this.nextTopic().length > 0) {
              Text(this.nextTopicHint())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_BRAND)
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
                      .backgroundColor(this.completedTopics.includes(topic) ?
                        Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BRAND_LIGHT)
                    Text((index + 1).toString())
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.completedTopics.includes(topic) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                  }
                  Column({ space: 4 }) {
                    Text(topic)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    Text(LearningContentRepository.getKnowledge(this.courseId, topic).length.toString() +
                      ' 个知识切片 · ' + LearningContentRepository.getQuestions(this.courseId, topic).length.toString() + ' 道练习')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 5 }) {
                    Text(this.topicStatusLabel(topic))
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.completedTopics.includes(topic) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(14)
                      .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
              }
              .width('100%')
              .constraintSize({ minHeight: 82 })
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .backgroundColor(topic === this.nextTopic() ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.openTopic(topic); })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 + SafeAreaInsets.bottomVp() })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
