import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct CourseDetailPage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topics: string[] = [];
  @State completedTopics: string[] = [];
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
      const events = await LocalLearningRepository.getStudyEvents();
      const completed: string[] = [];
      for (const event of events) {
        if (event.courseId === this.courseId && event.topic !== undefined &&
          (event.type === 'lesson_completed' || event.type === 'quiz_mastered') &&
          !completed.includes(event.topic)) {
          completed.push(event.topic);
        }
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

  private openPractice(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseDetailPage Practice navigation failed: %{public}s', err.message);
    });
  }

  build() {
    Column() {
      GradientHeader(this.courseTitle, this.topics.length.toString() + ' 个知识主题',
        () => this.getUIContext().getRouter().back())

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Row() {
              Text('真实学习进度')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text(Math.round(this.progress * 100).toString() + '%')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_BRAND)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
              .width('100%')
              .color(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
            Text('仅根据已完成学习与测验记录计算')
              .width('100%')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_LG)

          if (this.message.length > 0) {
            Text(this.message).fontSize(12).fontColor(Constants.COLOR_ERROR)
          }

          Column({ space: 10 }) {
            ForEach(this.topics, (topic: string, index: number): void => {
              Column({ space: 12 }) {
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
                }
                .width('100%')

                Row({ space: 10 }) {
                  Column() {
                    Text('学习内容')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_BRAND)
                  }
                    .layoutWeight(1)
                    .height(40)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.openTopic(topic); })
                  Column() {
                    Text('精选练习')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  }
                    .layoutWeight(1)
                    .height(40)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(Constants.COLOR_BRAND)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.openPractice(topic); })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
