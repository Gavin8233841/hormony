/**
 * 课程页 - 课程列表
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Course, CoursesResponse } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct CourseContent {
  @State courses: Course[] = [];
  @State loading: boolean = false;
  @State pressedIndex: number = -1;
  @State message: string = '';

  aboutToAppear() {
    // 调试模式：先加载演示数据，避免网络等待时空白
    if (Constants.__DEBUG__) {
      const c1: Course = { id: 'cs101', title: '数据结构', progress: 0.65, docCount: 12, topics: ['数组', '链表', '树', '图'] };
      const c2: Course = { id: 'cs102', title: '操作系统', progress: 0.42, docCount: 8, topics: ['进程', '调度', '内存管理'] };
      const c3: Course = { id: 'cs103', title: '计算机网络', progress: 0.30, docCount: 6, topics: ['TCP/IP', 'HTTP', '路由'] };
      this.courses = [c1, c2, c3];
    } else {
      this.loading = true;
    }
    this.loadCourses();
  }

  async loadCourses() {
    try {
      const res = await HttpClient.get<CoursesResponse>(
        Constants.API_COURSES + '?userId=' + Constants.DEMO_USER_ID
      );
      this.courses = res.courses;
    } catch (e) {
      if (!Constants.__DEBUG__) {
        this.message = '课程加载失败，请检查网络后重试';
      }
    } finally {
      this.loading = false;
    }
  }

  private openKnowledge(course: Course): void {
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Knowledge' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'CourseContent router.pushUrl failed: %{public}s', err.message);
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
      Column() {
        Text('我的课程')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('沿着清晰进度，继续今天的学习')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22, top: 24, bottom: 18 })

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
        List({ space: 10 }) {
          ForEach(this.courses, (c: Course, i: number) => {
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
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  }
                  Text(c.docCount.toString() + ' 份资料')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(14)
                    .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
                    .margin({ left: 8 })
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                // 进度行
                Row() {
                  Text('学习进度')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  Text(Math.round(c.progress * 100).toString() + '%')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_BRAND)
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

                // 知识点标签
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(c.topics, (t: string) => {
                    Text(t)
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .backgroundColor(Constants.COLOR_BG_TAG)
                      .borderRadius(8)
                      .margin({ right: 6, bottom: 6 })
                  })
                }
                .width('100%')
                .margin({ top: 12 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
              .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
              .scale({ x: this.pressedIndex === i ? 0.98 : 1, y: this.pressedIndex === i ? 0.98 : 1 })
              .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
              .onTouch((event?: TouchEvent) => {
                if (event) {
                  if (event.type === TouchType.Down) {
                    this.pressedIndex = i;
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedIndex = -1;
                  }
                }
              })
              .onClick(() => {
                this.openKnowledge(c);
              })
            }
          })
        }
        .width('100%')
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
          Text(this.message.length > 0 ? '稍后可下拉或重新进入页面重试' : '课程加入后会在这里显示学习进度')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
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
