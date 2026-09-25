/**
 * 课程页 - 课程列表
 */

import { Constants } from '../common/Constants';
import { MainPageHeader } from '../common/Builders';
import { Course, LessonProgress } from '../model/DataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CourseResumeState, hasCourseStarted, resolveCourseResumeState } from './CourseResumeState';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct CourseContent {
  @Prop @Watch('refreshLearningView') learningViewVersion: number = 0;
  @State courses: Course[] = [];
  @State lessonProgress: LessonProgress[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  private loadRunId: number = 0;

  aboutToAppear() {
    this.loading = true;
    this.loadCourses();
  }


  private refreshLearningView(): void {
    this.loadCourses();
  }

  async loadCourses(): Promise<void> {
    const runId = this.loadRunId + 1;
    this.loadRunId = runId;
    this.loading = true;
    this.message = '';
    try {
      const courses = (await LocalLearningRepository.getCourses()) ?? [];
      let lessonProgress: LessonProgress[] = [];
      let progressMessage: string = '';
      try {
        lessonProgress = await LocalLearningRepository.getLessonProgress();
      } catch (error) {
        progressMessage = '课程已加载，续学位置读取失败';
      }
      if (this.loadRunId !== runId) return;
      this.courses = courses;
      this.lessonProgress = lessonProgress;
      this.message = progressMessage;
    } catch (e) {
      if (this.loadRunId !== runId) return;
      this.message = '课程暂时打不开，请重试';
    } finally {
      if (this.loadRunId === runId) this.loading = false;
    }
  }

  private openCourse(course: Course): void {
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetail' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseContent router.pushUrl failed: %{public}s', err.message);
      this.message = '暂时无法打开课程，请再次点击课程入口';
    });
  }

  private resumeState(course: Course): CourseResumeState {
    return resolveCourseResumeState(course.id, course.topics, this.lessonProgress);
  }

  private courseActionLabel(course: Course): string {
    return course.progress > 0 || hasCourseStarted(this.resumeState(course)) ? '继续课程' : '进入课程';
  }

  private courseProgressLabel(course: Course): string {
    const recentTopic = this.resumeState(course).recentTopic;
    return recentTopic.length > 0 ? '上次学到 · ' + recentTopic : '学习进度';
  }

  private courseUpdatedAt(course: Course): string {
    let updatedAt: string = '';
    for (const item of this.lessonProgress) {
      if (item.courseId !== course.id || item.completedChunkIds.length === 0) continue;
      if (updatedAt.length === 0 || item.updatedAt > updatedAt) updatedAt = item.updatedAt;
    }
    return updatedAt;
  }

  private visibleCourses(): Course[] {
    return this.courses.slice().sort((left: Course, right: Course): number => {
      const leftStarted = left.progress > 0 || hasCourseStarted(this.resumeState(left));
      const rightStarted = right.progress > 0 || hasCourseStarted(this.resumeState(right));
      if (leftStarted !== rightStarted) return rightStarted ? 1 : -1;
      const updatedOrder = this.courseUpdatedAt(right).localeCompare(this.courseUpdatedAt(left));
      if (updatedOrder !== 0) return updatedOrder;
      return this.courses.indexOf(left) - this.courses.indexOf(right);
    });
  }

  @Builder
  CourseSkeleton() {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 10 }) {
          Column().width(42).height(42).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(13)
          Column().width(120).height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
        }
        Column().width(54).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Column().width('100%').height(8).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(4)
      Row({ space: 8 }) {
        Column().width(52).height(24).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(8)
        Column().width(52).height(24).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(8)
        Column().width(52).height(24).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(8)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  build() {
    Column() {
      MainPageHeader('课程', '接着学，或选一个新主题')

      if (this.loading) {
        Column({ space: 10 }) {
          this.CourseSkeleton()
          this.CourseSkeleton()
          this.CourseSkeleton()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      } else if (this.courses.length > 0) {
        if (this.message.length > 0) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_WARNING])
            Text(this.message)
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(18)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Button('重试')
              .constraintSize({ minHeight: 48 })
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
              .onClick((): void => { this.loadCourses(); })
          }
          .width('100%')
          .padding({ left: 14, right: 10, top: 10, bottom: 10 })
          .margin({ left: 16, right: 16, bottom: 10 })
          .backgroundColor(Constants.COLOR_SURFACE_TINT)
          .border({ width: 1, color: Constants.COLOR_BORDER })
          .borderRadius(Constants.RADIUS_MD)
        }
        List({ space: 10 }) {
          ForEach(this.visibleCourses(), (c: Course) => {
            ListItem() {
              Column() {
                // 课程标题行
                Row() {
                  Row({ space: 10 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(42)
                        .height(42)
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(13)
                      SymbolGlyph($r('sys.symbol.book_open_fill'))
                        .fontSize(22)
                        .fontColor([Constants.COLOR_BRAND])
                    }
                    Text(c.title)
                      .layoutWeight(1)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                      .maxLines(2)
                  }
                  .layoutWeight(1)
                  Text(c.docCount.toString() + ' 份资料')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    .margin({ left: 8 })
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                // 进度行
                Row() {
                  Text(this.courseProgressLabel(c))
                    .layoutWeight(1)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ right: 12 })
                  Text(Math.round(c.progress * 100).toString() + '%')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_BRAND_TEXT)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 12, bottom: 6 })

                // 进度条
                Progress({ value: c.progress * 100, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .color(Constants.COLOR_BRAND)
                  .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                  .borderRadius(4)

                // 课程主题预览
                Text(c.topics.slice(0, 3).join(' · '))
                  .width('100%')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  .maxLines(2)
                  .margin({ top: 12 })

                Button({ type: ButtonType.Normal }) {
                  Row({ space: 8 }) {
                    SymbolGlyph($r('sys.symbol.book_open_fill'))
                      .fontSize(16)
                      .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
                    Text(this.courseActionLabel(c))
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                    Blank()
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(14)
                      .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
                  }
                  .width('100%')
                }
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .margin({ top: 6 })
                .padding({ left: 14, right: 14 })
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick(() => {
                  this.openCourse(c);
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
              .border({ width: 1, color: Constants.COLOR_BORDER })
            }
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .height('100%')
        .layoutWeight(1)
        .cachedCount(3)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(42)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.message.length > 0 ? this.message : '还没有课程')
            .fontSize(15)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.message.length === 0) {
            Text('课程加入后会在这里显示学习进度')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          if (this.message.length > 0) {
            Button('重新加载课程')
              .constraintSize({ minHeight: 48 })
              .padding({ left: 18, right: 18 })
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.loadCourses(); })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

}

@Entry
@Component
struct CoursePage {
  build() {
    Column() {
      CourseContent()
    }
  }
}
