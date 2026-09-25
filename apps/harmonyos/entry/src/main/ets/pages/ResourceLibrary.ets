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
    this.resources = LearningContentRepository.getResources(this.courseId).filter(
      (item: ExternalLearningResource): boolean => item.url.startsWith('https://') &&
        item.provenance?.rightsStatus === 'external-link-only' &&
        item.provenance?.accessStatus !== 'unreachable');
  }

  private featuredIds(): string[] {
    if (this.courseId === 'cs102') return ['res_07', 'res_21', 'res_05'];
    if (this.courseId === 'cs103') {
      if (this.topic.includes('TCP')) return ['res_15', 'res_22', 'res_33'];
      if (this.topic.includes('HTTP')) return ['res_14', 'res_22', 'res_33'];
      return ['res_22', 'res_14', 'res_33'];
    }
    if (this.topic.includes('图') || this.topic.includes('排序')) return ['res_03', 'res_20', 'res_19'];
    return ['res_20', 'res_03', 'res_19'];
  }

  private featuredResources(): ExternalLearningResource[] {
    const ids = this.featuredIds();
    return this.resources.filter((item: ExternalLearningResource): boolean => ids.includes(item.id))
      .sort((left: ExternalLearningResource, right: ExternalLearningResource): number =>
        ids.indexOf(left.id) - ids.indexOf(right.id));
  }

  private otherResources(): ExternalLearningResource[] {
    const ids = this.featuredIds();
    return this.resources.filter((item: ExternalLearningResource): boolean => !ids.includes(item.id));
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
    const resource = this.selectedResource();
    if (resource === undefined) return;
    const topicText = this.topic.length > 0 ? '，正在学“' + this.topic + '”' : '';
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '我刚读了《' + resource.title + '》' + topicText +
        '。问我一道小题，看看我是否理解了。');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '暂时无法打开学伴，请重试';
    });
  }

  @Builder
  private ResourceRow(item: ExternalLearningResource, featured: boolean) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(this.typeLabel(item))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(featured ? Constants.COLOR_BRAND_TEXT : Constants.COLOR_TEXT_SECONDARY)
            if (featured) {
              Text('推荐')
                .fontSize(10)
                .fontColor(Constants.COLOR_SUCCESS)
            }
          }
          Text(item.title)
            .width('100%')
            .fontSize(featured ? 16 : 15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .maxLines(2)
            .textAlign(TextAlign.Start)
          Text(this.host(item) + ' · 外部网站')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.arrow_up_right'))
          .fontSize(16)
          .fontColor([Constants.COLOR_BRAND])
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: featured ? 100 : 88 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(featured ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_MD)
    .accessibilityText(item.title + '，' + this.typeLabel(item) + '，打开外部网站')
    .onClick((): void => { this.openResource(item); })
  }

  build() {
    Column() {
      TitleBar('拓展资料', this.courseTitle, () => this.getUIContext().getRouter().back())

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text(this.topic.length > 0 ? this.topic + '的参考资料' : '本课程参考资料')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('点击在浏览器打开')
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
            Text('推荐阅读')
              .width('100%')
              .fontSize(Constants.PAGE_SECTION_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)

            ForEach(this.featuredResources(), (item: ExternalLearningResource): void => {
              this.ResourceRow(item, true)
            }, (item: ExternalLearningResource): string => item.id)

            if (this.otherResources().length > 0) {
              Text('更多资料')
                .width('100%')
                .margin({ top: 8 })
                .fontSize(Constants.PAGE_SECTION_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              ForEach(this.otherResources(), (item: ExternalLearningResource): void => {
                this.ResourceRow(item, false)
              }, (item: ExternalLearningResource): string => item.id)
            }
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
      .scrollBar(BarState.Off)

      if (this.selectedResourceId.length > 0) {
        Column({ space: 10 }) {
          Text('看完了？试着说说学到了什么。')
            .width('100%')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Row({ space: 10 }) {
            Button('和老师聊聊')
              .layoutWeight(1)
              .height(48)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.askTutor(); })
            Button('做几道题')
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
