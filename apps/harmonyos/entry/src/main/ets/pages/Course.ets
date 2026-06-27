/**
 * 课程页 - 课程列表
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { Course, CoursesResponse } from '../model/DataModels';

@Entry
@Component
struct CoursePage {
  @State courses: Course[] = [];
  @State loading: boolean = false;

  aboutToAppear() {
    // 调试模式：先加载演示数据，避免网络等待时空白
    if (Constants.__DEBUG__) {
      const c1: Course = { id: 'cs101', title: '数据结构', progress: 0.65, docCount: 12, topics: ['数组', '链表', '树', '图'] };
      const c2: Course = { id: 'cs102', title: '操作系统', progress: 0.42, docCount: 8, topics: ['进程', '调度', '内存管理'] };
      this.courses = [c1, c2];
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
      // __DEBUG__ 模式下保留 aboutToAppear 中设置的演示数据
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      GradientHeader('我的课程', '查看课程进度和学习资料')

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(Constants.COLOR_BRAND)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.courses, (c: Course) => {
            ListItem() {
              Column() {
                // 课程标题行
                Row() {
                  Text(c.title)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text(c.docCount.toString() + ' 份资料')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
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
                    .fontColor(Constants.COLOR_SUCCESS)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 12, bottom: 6 })

                // 进度条
                Progress({ value: c.progress * 100, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .color(Constants.COLOR_SUCCESS)
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
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
