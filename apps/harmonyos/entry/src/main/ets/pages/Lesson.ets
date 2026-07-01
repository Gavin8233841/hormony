import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CuratedKnowledgeChunk, LessonProgress } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const EMPTY_CHUNK: CuratedKnowledgeChunk = {
  id: '',
  text: '',
  source: '',
  courseId: '',
  topic: ''
};

@Entry
@Component
struct LessonPage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State chunks: CuratedKnowledgeChunk[] = [];
  @State activeChunk: CuratedKnowledgeChunk = EMPTY_CHUNK;
  @State completedChunkIds: string[] = [];
  @State currentIndex: number = 0;
  @State saving: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topic = AppStorage.get<string>('selectedContentTopic') ?? '';
    const content = LearningContentRepository.getKnowledge(this.courseId, this.topic);
    this.chunks = content;
    this.activeChunk = content.length > 0 ? content[0] : EMPTY_CHUNK;
    this.loadProgress();
  }

  private async loadProgress(): Promise<void> {
    try {
      const progress = await LocalLearningRepository.getLessonProgress(this.courseId);
      const item = progress.find((value: LessonProgress): boolean => value.topic === this.topic);
      this.completedChunkIds = item?.completedChunkIds ?? [];
      if (this.chunks.length > 0) {
        const nextIndex = this.chunks.findIndex((chunk: CuratedKnowledgeChunk): boolean =>
          !this.completedChunkIds.includes(chunk.id));
        this.currentIndex = nextIndex >= 0 ? nextIndex : 0;
        this.activeChunk = this.chunks[this.currentIndex];
      }
    } catch (error) {
      this.message = '学习进度读取失败，但课程内容仍可查看';
    }
  }

  private moveTo(index: number): void {
    if (index < 0 || index >= this.chunks.length) return;
    this.currentIndex = index;
    this.activeChunk = this.chunks[index];
  }

  private contentBeats(): string[] {
    return this.activeChunk.text
      .split('。')
      .map((sentence: string): string => sentence.trim())
      .filter((sentence: string): boolean => sentence.length > 0)
      .map((sentence: string): string => sentence + '。');
  }

  private async completeCurrent(): Promise<void> {
    if (this.saving || this.activeChunk.id.length === 0) return;
    this.saving = true;
    this.message = '';
    try {
      await LocalLearningRepository.completeLessonChunk(
        this.courseId,
        this.topic,
        this.activeChunk.id,
        this.chunks.length
      );
      if (!this.completedChunkIds.includes(this.activeChunk.id)) {
        this.completedChunkIds = this.completedChunkIds.concat([this.activeChunk.id]);
      }
      if (this.currentIndex < this.chunks.length - 1) {
        this.moveTo(this.currentIndex + 1);
      } else {
        this.openPractice();
      }
    } catch (error) {
      this.message = '学习进度保存失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private openPractice(): void {
    AppStorage.setOrCreate<string>('selectedPracticeTopic', this.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LessonPage Practice navigation failed: %{public}s', error.message);
    });
  }

  build() {
    Column() {
      TitleBar(this.topic.length > 0 ? this.topic : '课程内容', this.courseTitle,
        () => this.getUIContext().getRouter().back())

      if (this.chunks.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(38)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('该主题暂无课程内容')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          Row() {
            Text('精选课程内容')
              .fontSize(11)
              .fontColor(Constants.COLOR_BRAND)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
            Text((this.currentIndex + 1).toString() + ' / ' + this.chunks.length.toString())
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Progress({ value: this.currentIndex + 1, total: this.chunks.length, type: ProgressType.Linear })
            .width('100%')
            .color(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 12 })

        Scroll() {
          Column({ space: 24 }) {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.lightbulb_max_fill'))
                  .fontSize(18)
                  .fontColor([Constants.COLOR_BRAND])
                Text('先抓住核心')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_BRAND)
              }
              .width('100%')

              Text(this.contentBeats()[0] ?? this.activeChunk.text)
                .width('100%')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .lineHeight(34)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 22, bottom: 22 })
            .backgroundColor(Constants.COLOR_SURFACE_TINT)
            .borderRadius(Constants.RADIUS_LG)

            if (this.contentBeats().length > 1) {
              Column({ space: 16 }) {
                Text('拆开理解')
                  .width('100%')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)

                ForEach(this.contentBeats().slice(1), (sentence: string, index: number): void => {
                  Row({ space: 12 }) {
                    Column()
                      .width(8)
                      .height(8)
                      .backgroundColor(index === this.contentBeats().length - 2 ?
                        Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                      .borderRadius(4)
                      .margin({ top: 9 })
                    Text(sentence)
                      .layoutWeight(1)
                      .fontSize(15)
                      .lineHeight(26)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                })
              }
              .width('100%')
            }

            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(17)
                .fontColor([Constants.COLOR_TEXT_SECONDARY])
              Column({ space: 2 }) {
                Text('内容来源')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                Text(this.activeChunk.source)
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (this.completedChunkIds.includes(this.activeChunk.id)) {
                Text('已学')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_SUCCESS)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
                  .borderRadius(Constants.RADIUS_SM)
              }
            }
            .width('100%')
            .padding({ top: 16 })
            .border({ width: { top: 1 }, color: Constants.COLOR_BORDER })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18, top: 4, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })

        if (this.message.length > 0) {
          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor(this.message.includes('失败') ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            .padding({ left: 18, right: 18, top: 8 })
        }

        Row({ space: 10 }) {
          Button('上一篇')
            .width(92)
            .height(48)
            .enabled(this.currentIndex > 0)
            .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.moveTo(this.currentIndex - 1); })

          Button(this.saving ? '保存中...' :
            (this.currentIndex === this.chunks.length - 1 ? '完成主题并练习' : '学完本节，继续'))
            .layoutWeight(1)
            .height(48)
            .enabled(!this.saving)
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.completeCurrent(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
