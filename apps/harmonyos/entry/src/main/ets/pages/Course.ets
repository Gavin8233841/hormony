/**
 * 课程页 - 课程列表
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Course, CoursesResponse } from '../model/DataModels';

@Entry
@Component
struct CoursePage {
  @State courses: Course[] = [];
  @State loading: boolean = true;

  aboutToAppear() {
    this.loadCourses();
  }

  async loadCourses() {
    try {
      const res = await HttpClient.get<CoursesResponse>(
        `${Constants.API_COURSES}?userId=${Constants.DEMO_USER_ID}`
      );
      this.courses = res.courses;
    } catch (e) {
      // 回退演示数据
      const c1: Course = { id: 'cs101', title: '数据结构', progress: 0.65, docCount: 12, topics: ['数组', '链表', '树', '图'] };
      const c2: Course = { id: 'cs102', title: '操作系统', progress: 0.42, docCount: 8, topics: ['进程', '调度', '内存管理'] };
      this.courses = [c1, c2];
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#1a1a1a')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })

        Column() {
          Text('我的课程')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')
          Text('查看课程进度和学习资料')
            .fontSize(12)
            .fontColor('#929292')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color('#0a59f7')
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
                    .fontColor('#1a1a1a')
                  Text(`${c.docCount} 份资料`)
                    .fontSize(12)
                    .fontColor('#929292')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                // 进度行
                Row() {
                  Text('学习进度')
                    .fontSize(12)
                    .fontColor('#929292')
                  Text(`${Math.round(c.progress * 100)}%`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4caf50')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 12, bottom: 6 })

                // 进度条
                Progress({ value: c.progress * 100, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .color('#4caf50')
                  .backgroundColor('#e8e8e8')
                  .borderRadius(4)

                // 知识点标签
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(c.topics, (t: string) => {
                    Text(t)
                      .fontSize(11)
                      .fontColor('#666666')
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .backgroundColor('#f0f0f2')
                      .borderRadius(8)
                      .margin({ right: 6, bottom: 6 })
                  })
                }
                .width('100%')
                .margin({ top: 12 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#ffffff')
              .borderRadius(14)
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
    .backgroundColor('#f5f6f8')
  }
}
