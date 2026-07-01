import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { StudyEvent } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct ActivityRecordsPage {
  @State events: StudyEvent[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    try {
      this.events = (await LocalLearningRepository.getStudyEvents()).slice().reverse();
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

  private openEvent(event: StudyEvent): void {
    if (event.courseId === undefined) return;
    const titles: string[] = ['数据结构', '操作系统', '计算机网络'];
    const ids: string[] = ['cs101', 'cs102', 'cs103'];
    const index = ids.indexOf(event.courseId);
    AppStorage.setOrCreate<string>('selectedCourseId', event.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', index >= 0 ? titles[index] : '课程');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetail' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage navigation failed: %{public}s', error.message);
    });
  }

  build() {
    Column() {
      TitleBar('学习记录', '所有数据只保存在本机', () => this.getUIContext().getRouter().back())
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
        List({ space: 0 }) {
          ForEach(this.events, (event: StudyEvent, index: number): void => {
            ListItem() {
              Column() {
                Row({ space: 12 }) {
                  SymbolGlyph(this.icon(event))
                    .fontSize(21)
                    .fontColor([event.type === 'quiz_mastered' ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND])
                  Column({ space: 4 }) {
                    Text(this.title(event)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.COLOR_TEXT_PRIMARY)
                    Text(this.detail(event)).fontSize(12).fontColor(Constants.COLOR_TEXT_SECONDARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 3 }) {
                    Text(event.timestamp.slice(5, 10)).fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
                    Text(event.timestamp.slice(11, 16)).fontSize(10).fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
                  }
                  if (event.courseId !== undefined) {
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
                  }
                }
                .width('100%')
                .height(74)
                .onClick((): void => { this.openEvent(event); })
                if (index < this.events.length - 1) {
                  Divider().color(Constants.COLOR_BORDER).margin({ left: 32 })
                }
              }
              .width('100%')
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 18, right: 18, bottom: 24 })
        .backgroundColor(Constants.COLOR_BG_CARD)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
