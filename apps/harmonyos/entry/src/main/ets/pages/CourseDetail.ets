import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
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

  private openQuiz(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseDetailPage Quiz navigation failed: %{public}s', err.message);
    });
  }

  private topicStatusLabel(topic: string): string {
    return this.completedTopics.includes(topic) ? '有学习记录' : '待掌握';
  }

  @Builder
  private LoopStep(order: string, title: string, description: string, active: boolean) {
    Column({ space: 5 }) {
      Text(order)
        .width(26)
        .height(26)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? Constants.COLOR_BRAND : Constants.COLOR_BRAND_LIGHT)
        .borderRadius(13)
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Text(description)
        .fontSize(10)
        .lineHeight(15)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 76 })
    .padding({ left: 6, right: 6, top: 8, bottom: 8 })
    .backgroundColor(active ? Constants.COLOR_SURFACE_TINT : Constants.COLOR_BG_TAG)
    .borderRadius(Constants.RADIUS_MD)
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

          Column({ space: 12 }) {
            Column({ space: 4 }) {
              Text('主题学习闭环')
                .width('100%')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text('每个主题都按“读懂核心 → 做精选题 → AI 测验复盘”推进')
                .width('100%')
                .fontSize(12)
                .lineHeight(19)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Row({ space: 8 }) {
              this.LoopStep('1', '学习', '概念与案例', true)
              this.LoopStep('2', '练习', '离线即时评分', false)
              this.LoopStep('3', '测验', 'AI 标签复盘', false)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
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
                  Text(this.topicStatusLabel(topic))
                    .fontSize(11)
                    .fontColor(this.completedTopics.includes(topic) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                    .backgroundColor(this.completedTopics.includes(topic) ?
                      Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BRAND_LIGHT)
                    .borderRadius(Constants.RADIUS_SM)
                }
                .width('100%')

                Column({ space: 8 }) {
                  Column() {
                    Text('AI 测验 · 生成标签化题组')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  }
                    .width('100%')
                    .height(44)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(Constants.COLOR_BRAND)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.openQuiz(topic); })
                  Row({ space: 10 }) {
                    Column() {
                      Text('学习内容')
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_BRAND)
                    }
                      .layoutWeight(1)
                      .height(42)
                      .justifyContent(FlexAlign.Center)
                      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                      .borderRadius(Constants.RADIUS_MD)
                      .onClick((): void => { this.openTopic(topic); })
                    Column() {
                      Text('精选练习')
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    }
                      .layoutWeight(1)
                      .height(42)
                      .justifyContent(FlexAlign.Center)
                      .backgroundColor(Constants.COLOR_BG_TAG)
                      .borderRadius(Constants.RADIUS_MD)
                      .onClick((): void => { this.openPractice(topic); })
                  }
                  .width('100%')
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
