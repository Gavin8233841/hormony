import { common } from '@kit.AbilityKit';
import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { ExternalLearningResource } from '../model/DataModels';

@Entry
@Component
struct ResourceLibraryPage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State resources: ExternalLearningResource[] = [];
  @State selectedResourceId: string = '';
  @State message: string = '';
  @StorageProp('safeAreaBottomVp') safeAreaBottomVpValue: number = 0;

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    const topics = LearningContentRepository.getTopics(this.courseId);
    const requestedTopic = AppStorage.get<string>('selectedResourceTopic') ?? '';
    this.topic = topics.includes(requestedTopic) ? requestedTopic : (topics[0] ?? '');
    const curatedIds = this.featuredIds();
    this.resources = LearningContentRepository.getResources(this.courseId).filter(
      (item: ExternalLearningResource): boolean => curatedIds.includes(item.id) && item.url.startsWith('https://') &&
        item.provenance?.rightsStatus === 'external-link-only' &&
        item.provenance?.accessStatus !== 'unreachable');
  }

  private featuredIds(): string[] {
    if (this.courseId === 'cs102') return ['res_07', 'res_21'];
    if (this.courseId === 'cs103') {
      return this.topic.includes('TCP') ? ['res_15', 'res_22'] : ['res_22', 'res_15'];
    }
    return this.topic.includes('链表') ? ['res_20', 'res_19'] : ['res_19', 'res_20'];
  }

  private featuredResources(): ExternalLearningResource[] {
    const ids = this.featuredIds();
    return this.resources.filter((item: ExternalLearningResource): boolean => ids.includes(item.id))
      .sort((left: ExternalLearningResource, right: ExternalLearningResource): number =>
        ids.indexOf(left.id) - ids.indexOf(right.id));
  }

  private typeLabel(item: ExternalLearningResource): string {
    if (item.type === 'course') return '公开课程';
    if (item.type === 'standard') return '原始规范';
    if (item.type === 'documentation') return '官方文档';
    if (item.type === 'tool') return '学习工具';
    return '教材资料';
  }

  private host(item: ExternalLearningResource): string {
    return item.url.replace('https://', '').split('/')[0];
  }

  private readingGoal(item: ExternalLearningResource): string {
    if (item.id === 'res_20') return this.topic.includes('链表') ?
      '找 Linked Lists 讲义，看节点怎样连接。' : '在讲义中找一个数据结构的实现例子。';
    if (item.id === 'res_19') return '看 Lecture Notes 中的数据结构与复杂度分析。';
    if (item.id === 'res_07') return this.topic.includes('进程') || this.topic.includes('线程') ?
      '读 Processes 和 Concurrency and Threads 两章。' : '从目录找到当前主题，读一章正文。';
    if (item.id === 'res_21') return '看 xv6 Lab 如何实现系统调用。';
    if (item.id === 'res_15') return '查 3.5 节，理清 TCP 如何建立连接。';
    return '看课程讲义与 Lab 中的可靠传输。';
  }

  private async openResource(item: ExternalLearningResource): Promise<void> {
    this.message = '';
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await hostContext.openLink(item.url);
      this.selectedResourceId = item.id;
    } catch (error) {
      this.message = '暂时打不开这个链接，请稍后再试';
    }
  }

  private selectedResource(): ExternalLearningResource | undefined {
    return this.resources.find((item: ExternalLearningResource): boolean => item.id === this.selectedResourceId);
  }

  private startPractice(): void {
    if (this.topic.length === 0) return;
    AppStorage.setOrCreate<string>('selectedPracticeTopic', this.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((): void => {
      this.message = '练习暂时打不开，请重试';
    });
  }

  private askTutor(): void {
    if (this.selectedResource() === undefined || this.topic.length === 0) return;
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '给我一道关于' + this.topic + '的小题，先别给答案。');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '暂时无法打开学伴，请重试';
    });
  }

  @Builder
  private ResourceRow(item: ExternalLearningResource, featured: boolean) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(featured ? '先读这份 · ' + this.typeLabel(item) : this.typeLabel(item))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(featured ? Constants.COLOR_MAP_CORE : Constants.COLOR_TEXT_SECONDARY)
          Text(item.title)
            .width('100%')
            .fontSize(featured ? 18 : 16)
            .fontWeight(FontWeight.Medium)
            .fontColor(featured ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
            .maxLines(2)
            .textAlign(TextAlign.Start)
          Text(this.readingGoal(item))
            .width('100%')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(featured ? Constants.COLOR_MAP_TEXT_MUTED : Constants.COLOR_TEXT_SECONDARY)
            .maxLines(2)
            .textAlign(TextAlign.Start)
          Text(this.host(item) + ' · 浏览器打开')
            .fontSize(12)
            .fontColor(featured ? Constants.COLOR_MAP_TEXT_MUTED : Constants.COLOR_TEXT_SECONDARY)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.arrow_up_right'))
          .fontSize(16)
          .fontColor([featured ? Constants.COLOR_MAP_CORE : Constants.COLOR_TEXT_SECONDARY])
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: featured ? 138 : 118 })
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(featured ? Constants.COLOR_MAP_SURFACE : Constants.COLOR_BG_CARD)
    .border({ width: 1, color: featured ? Constants.COLOR_MAP_SURFACE : Constants.COLOR_BORDER })
    .borderRadius(Constants.RADIUS_LG)
    .accessibilityText(item.title + '，' + this.typeLabel(item) + '，打开外部网站')
    .onClick((): void => { this.openResource(item); })
  }

  build() {
    Column() {
      TitleBar('拓展资料', this.courseTitle, () => this.getUIContext().getRouter().back())

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text(this.topic.length > 0 ? this.topic : '本课程')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text(this.resources.length.toString() + ' 份公开资料')
              .fontSize(13)
              .lineHeight(20)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.resources.length === 0) {
            Text('这门课暂时没有可打开的资料')
              .width('100%')
              .padding(20)
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
          } else {
            ForEach(this.featuredResources(), (item: ExternalLearningResource, index: number): void => {
              this.ResourceRow(item, index === 0)
            }, (item: ExternalLearningResource): string => item.id)
          }

          if (this.message.length > 0) {
            Text(this.message)
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_ERROR)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER,
          top: 12, bottom: 24 + this.safeAreaBottomVpValue })
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)

      if (this.selectedResourceId.length > 0) {
        Column({ space: 10 }) {
          Text('继续学 ' + this.topic)
            .width('100%')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Row({ space: 10 }) {
            Button('问学伴')
              .layoutWeight(1)
              .height(48)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.askTutor(); })
            Button('练习本主题')
              .layoutWeight(1)
              .height(48)
              .enabled(this.topic.length > 0)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.startPractice(); })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER,
          top: 12, bottom: 12 + this.safeAreaBottomVpValue })
        .backgroundColor(Constants.COLOR_BG_CARD)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
