/**
 * 课程页
 */

import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Course } from '../model/DataModels';

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
      const res = await HttpClient.get<{ courses: Course[] }>(
        `${Constants.API_COURSES}?userId=${Constants.DEMO_USER_ID}`
      );
      this.courses = res.courses;
    } catch (e) {
      // 回退演示数据
      this.courses = [
        { id: 'cs101', title: '数据结构', progress: 0.65, docCount: 12, topics: ['数组', '链表', '树', '图'] },
        { id: 'cs102', title: '操作系统', progress: 0.42, docCount: 8, topics: ['进程', '调度', '内存管理'] },
      ];
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Text('我的课程')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 4, left: 20 })
        .width('100%')

      Text('课程资料已纳入 RAG 知识库')
        .fontSize(13)
        .fontColor('#94a3b8')
        .margin({ bottom: 20, left: 20 })
        .width('100%')

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#3b82f6')
        }
        .width('100%')
        .height('60%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.courses, (c: Course) => {
            ListItem() {
              Column() {
                Row() {
                  Text(c.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#e2e8f0')
                  Text(`${c.docCount} 份资料`).fontSize(12).fontColor('#94a3b8')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                // 进度条
                Row() {
                  Text('学习进度').fontSize(11).fontColor('#64748b')
                  Text(`${Math.round(c.progress * 100)}%`).fontSize(11).fontColor('#94a3b8')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 10, bottom: 4 })

                Progress({ value: c.progress * 100, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .color('#3b82f6')

                // 主题标签
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(c.topics, (t: string) => {
                    Text(t)
                      .fontSize(11)
                      .fontColor('#94a3b8')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor('#334155')
                      .borderRadius(8)
                      .margin({ right: 4, bottom: 4 })
                  })
                }
                .width('100%')
                .margin({ top: 10 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#1e293b')
              .borderRadius(12)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }
}
