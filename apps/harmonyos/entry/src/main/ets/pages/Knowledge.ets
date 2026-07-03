/**
 * 搜课程资料页
 * 浅色主题 · 用户友好文案 · 修复 courseId
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import {
  CuratedKnowledgeChunk,
  ExternalLearningResource,
  KnowledgeChunk,
  KnowledgeSearchRequest,
  KnowledgeSearchResponse
} from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface LocalKnowledgeMatch {
  chunk: CuratedKnowledgeChunk;
  score: number;
}

interface ResourceMatch {
  resource: ExternalLearningResource;
  score: number;
}

@Entry
@Component
struct KnowledgePage {
  @State query: string = '';
  @State results: KnowledgeChunk[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State pressedIndex: number = -1;
  @State expandedIndex: number = -1;
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State hasError: boolean = false;
  @State resultMode: string = '';
  @State relatedResources: ExternalLearningResource[] = [];
  private suggestions: string[] = ['二叉搜索树', '图的遍历', '动态规划'];

  get canSearch(): boolean {
    return !this.loading && this.query.trim().length > 0;
  }

  private searchLocal(query: string): KnowledgeChunk[] {
    const matches: LocalKnowledgeMatch[] = [];
    const chunks = LearningContentRepository.getKnowledge(this.courseId);
    for (const chunk of chunks) {
      const topic = chunk.topic.toLowerCase();
      const text = chunk.text.toLowerCase();
      const source = chunk.source.toLowerCase();
      let score = 0;
      if (topic.includes(query)) score += 1;
      if (text.includes(query)) score += 0.8;
      if (source.includes(query)) score += 0.3;
      if (score > 0) matches.push({ chunk: chunk, score: Math.min(score, 1) });
    }
    matches.sort((left: LocalKnowledgeMatch, right: LocalKnowledgeMatch): number => right.score - left.score);
    return matches.slice(0, 5).map((match: LocalKnowledgeMatch): KnowledgeChunk => {
      return {
        id: match.chunk.id,
        text: match.chunk.text,
        source: match.chunk.source,
        courseId: match.chunk.courseId,
        topic: match.chunk.topic,
        score: match.score
      };
    });
  }

  private updateRelatedResources(query: string): void {
    const resources = LearningContentRepository.getResources(this.courseId);
    const normalized = query.trim().toLowerCase();
    if (normalized.length === 0) {
      this.relatedResources = resources.slice(0, 3);
      return;
    }

    const matches: ResourceMatch[] = [];
    for (const resource of resources) {
      let score = 0;
      if (resource.title.toLowerCase().includes(normalized)) score += 2;
      if (resource.description.toLowerCase().includes(normalized)) score += 1;
      for (const tag of resource.tags) {
        if (tag.toLowerCase().includes(normalized)) score += 1;
      }
      if (score > 0) matches.push({ resource: resource, score: score });
    }

    if (matches.length === 0) {
      this.relatedResources = resources.slice(0, 3);
      return;
    }
    matches.sort((left: ResourceMatch, right: ResourceMatch): number => right.score - left.score);
    this.relatedResources = matches.slice(0, 3).map((match: ResourceMatch): ExternalLearningResource => match.resource);
  }

  private hasTopic(item: KnowledgeChunk): boolean {
    return item.topic !== undefined && item.topic.trim().length > 0;
  }

  private topicLabel(item: KnowledgeChunk): string {
    return this.hasTopic(item) ? (item.topic ?? '').trim() : '当前检索';
  }

  private scoreLabel(item: KnowledgeChunk): string {
    return item.score !== undefined ? '相关度 ' + (item.score * 100).toFixed(0) + '%' : '课程资料';
  }

  private firstSentence(text: string): string {
    const value = text.trim();
    if (value.length <= 96) return value;
    const stops: string[] = ['。', '；', '？', '！'];
    let endIndex = -1;
    for (const stop of stops) {
      const index = value.indexOf(stop);
      if (index >= 24 && (endIndex < 0 || index < endIndex)) {
        endIndex = index;
      }
    }
    if (endIndex >= 24 && endIndex < 108) {
      return value.substring(0, endIndex + 1);
    }
    return value.substring(0, 96) + '...';
  }

  private resourceTypeLabel(type: string): string {
    if (type === 'textbook') return '教材';
    if (type === 'course') return '课程';
    if (type === 'documentation') return '文档';
    if (type === 'standard') return '标准';
    if (type === 'tool') return '工具';
    return type;
  }

  private resourceTags(resource: ExternalLearningResource): string[] {
    return resource.tags.slice(0, 3);
  }

  private openLesson(item: KnowledgeChunk): void {
    if (!this.hasTopic(item)) return;
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', (item.topic ?? '').trim());
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Lesson router.pushUrl failed: %{public}s', err.message);
    });
  }

  private askTutor(item: KnowledgeChunk): void {
    const topic = this.hasTopic(item) ? (item.topic ?? '').trim() : this.query.trim();
    const topicText = topic.length > 0 ? topic : this.courseTitle;
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '我在“' + this.courseTitle + '”检索“' + this.query.trim() + '”时读到《' + item.source +
        '》的资料，主题是“' + topicText + '”。请用一个现实例子解释这段话，并给我 2 个自测问题：' +
        this.firstSentence(item.text));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Chat router.pushUrl failed: %{public}s', err.message);
    });
  }

  private startTopicQuiz(topic?: string): void {
    const trimmed = topic !== undefined ? topic.trim() : '';
    const fallback = this.query.trim().length > 0 ? this.query.trim() : '综合';
    const quizTopic = trimmed.length > 0 ? trimmed : fallback;
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', quizTopic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage quiz router.pushUrl failed: %{public}s', err.message);
    });
  }

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    if (this.courseId === 'cs102') {
      this.suggestions = ['进程调度', '内存管理', '文件系统'];
    } else if (this.courseId === 'cs103') {
      this.suggestions = ['TCP 三次握手', 'HTTP', '路由'];
    } else {
      this.suggestions = ['二叉搜索树', '图的遍历', '动态规划'];
    }
    this.updateRelatedResources('');
    const prefill = AppStorage.get<string>('knowledgePrefillQuery') ?? '';
    if (prefill.trim().length > 0) {
      this.query = prefill.trim();
      AppStorage.setOrCreate<string>('knowledgePrefillQuery', '');
      this.search();
    }
  }

  @Builder
  SearchSkeleton() {
    Column({ space: 10 }) {
      ForEach([1, 2, 3], (_: number): void => {
        Column({ space: 10 }) {
          Row() {
            Column().width(110).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width(64).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Column().width('100%').height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
          Column().width('74%').height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private PathStep(order: string, title: string, detail: string, color: string, background: string) {
    Column({ space: 6 }) {
      Text(order)
        .width(28)
        .height(28)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .textAlign(TextAlign.Center)
        .backgroundColor(background)
        .borderRadius(14)
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Text(detail)
        .fontSize(10)
        .lineHeight(15)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private StudyPathCard() {
    Column({ space: 12 }) {
      Row() {
        Text('资料使用路径')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(this.resultMode === 'local' ? '本地资料兜底' : '课程资料优先')
          .fontSize(11)
          .fontColor(this.resultMode === 'local' ? Constants.COLOR_WARNING : Constants.COLOR_BRAND)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.resultMode === 'local' ? Constants.COLOR_BG_TAG : Constants.COLOR_BRAND_LIGHT)
          .borderRadius(10)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 8 }) {
        this.PathStep('1', '抓关键句', '先看主题和一句核心解释', Constants.COLOR_BRAND, Constants.COLOR_BRAND_LIGHT)
        this.PathStep('2', '问学伴', '把片段变成例子和自测题', Constants.COLOR_WARNING, Constants.COLOR_BG_TAG)
        this.PathStep('3', '做测验', '用标签题检查是否真会用', Constants.COLOR_SUCCESS, Constants.COLOR_SUCCESS_LIGHT)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
  }

  @Builder
  private ResourceSuggestions() {
    if (this.relatedResources.length > 0) {
      Column({ space: 10 }) {
        Row() {
          Text('延伸阅读')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('已按当前课程筛选')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        ForEach(this.relatedResources.slice(0, 2), (resource: ExternalLearningResource): void => {
          Column({ space: 8 }) {
            Row() {
              Text(this.resourceTypeLabel(resource.type))
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_BRAND)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(9)
              Text(resource.title)
                .layoutWeight(1)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Text(resource.description)
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.resourceTags(resource), (tag: string): void => {
                Text(tag)
                  .fontSize(10)
                  .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(Constants.COLOR_BG_TAG)
                  .borderRadius(8)
                  .margin({ right: 5, bottom: 5 })
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(Constants.COLOR_SURFACE_TINT)
          .borderRadius(Constants.RADIUS_MD)
        })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
      .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
    }
  }

  @Builder
  private ResultActionButton(label: string, symbol: Resource, brand: boolean, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        SymbolGlyph(symbol)
          .fontSize(14)
          .fontColor([brand ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND])
        Text(label)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(brand ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND)
      }
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(38)
    .backgroundColor(brand ? Constants.COLOR_BRAND : Constants.COLOR_BRAND_LIGHT)
    .borderRadius(Constants.RADIUS_MD)
    .onClick(action)
  }

  @Builder
  private ResultCard(item: KnowledgeChunk, index: number) {
    Column({ space: 10 }) {
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_pages_fill_1'))
            .fontSize(16)
            .fontColor([Constants.COLOR_BRAND])
          Text(item.source)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_BRAND)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        Text(this.scoreLabel(item))
          .fontSize(11)
          .fontColor(item.score !== undefined ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.hasTopic(item)) {
          Text(this.topicLabel(item))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(10)
            .margin({ right: 6, bottom: 6 })
        }
        Text(this.resultMode === 'local' ? '本地课程资料' : '课程检索资料')
          .fontSize(11)
          .fontColor(this.resultMode === 'local' ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.resultMode === 'local' ? Constants.COLOR_BG_TAG : Constants.COLOR_SUCCESS_LIGHT)
          .borderRadius(10)
          .margin({ right: 6, bottom: 6 })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text('关键句')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Text(this.firstSentence(item.text))
          .width('100%')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)

      Text(item.text)
        .fontSize(13)
        .lineHeight(21)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)
        .maxLines(this.expandedIndex === index ? 20 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 4 }) {
        Text(this.expandedIndex === index ? '收起全文' : '展开全文')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        SymbolGlyph($r(this.expandedIndex === index ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
          .fontSize(11)
          .fontColor([Constants.COLOR_TEXT_SECONDARY])
      }
      .height(30)
      .alignSelf(ItemAlign.Start)
      .onClick((): void => {
        this.expandedIndex = this.expandedIndex === index ? -1 : index;
      })

      Row({ space: 8 }) {
        if (this.hasTopic(item)) {
          this.ResultActionButton('学主题', $r('sys.symbol.book_open_fill'), false, (): void => {
            this.openLesson(item);
          })
        }
        this.ResultActionButton('问学伴', $r('sys.symbol.lightbulb_max_fill'), false, (): void => {
          this.askTutor(item);
        })
        this.ResultActionButton('测验', $r('sys.symbol.play_circle_fill'), true, (): void => {
          this.startTopicQuiz(this.hasTopic(item) ? (item.topic ?? '') : this.query);
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
    .alignItems(HorizontalAlign.Start)
    .scale({ x: this.pressedIndex === index ? 0.98 : 1, y: this.pressedIndex === index ? 0.98 : 1 })
    .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
    .onTouch((event?: TouchEvent) => {
      if (event) {
        if (event.type === TouchType.Down) {
          this.pressedIndex = index;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedIndex = -1;
        }
      }
    })
  }

  @Builder
  private EmptyGuidance() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(44)
        .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
      Text('搜索' + this.courseTitle + '知识点')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      Text('输入概念、章节或问题，结果将限定在当前课程资料中')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.suggestions, (suggestion: string) => {
          Button(suggestion)
            .height(40)
            .fontSize(12)
            .fontColor(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(20)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.query = suggestion;
              this.search();
            })
        })
      }
      .width('100%')

      this.ResourceSuggestions()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 24, right: 24, bottom: 24 })
  }

  build() {
    Column() {
      GradientHeader('搜课程资料', '在' + this.courseTitle + '资料中检索', () => this.getUIContext().getRouter().back())

      // 搜索栏
      Row({ space: 12 }) {
        TextInput({ text: this.query, placeholder: '输入关键词...' })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(12)
          .onChange((v: string) => { this.query = v; })
          .onSubmit(() => { this.search(); })

        Button('检索')
          .height(44)
          .fontSize(14)
          .backgroundColor(this.canSearch ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
          .fontColor(this.canSearch ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .borderRadius(12)
          .enabled(this.canSearch)
          .onClick(() => { this.search(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 + SafeAreaInsets.bottomVp() })

      if (this.message.length > 0) {
        Row({ space: 8 }) {
          if (this.hasError) {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_ERROR])
          } else {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_SUCCESS])
          }
          Text(this.message)
            .fontSize(12)
            .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 10 })
      }

      // 加载中
      if (this.loading) {
        this.SearchSkeleton()
      } else if (this.results.length > 0) {
        List({ space: 12 }) {
          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Text('找到 ' + this.results.length + ' 条相关资料')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('先抓关键句，再带着片段去提问或测验')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 5 }) {
                    SymbolGlyph($r('sys.symbol.play_circle_fill'))
                      .fontSize(14)
                      .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
                    Text('开始测验')
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  }
                }
                .height(38)
                .padding({ left: 12, right: 12 })
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.startTopicQuiz(); })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              this.StudyPathCard()
              this.ResourceSuggestions()
            }
            .width('100%')
          }

          ForEach(this.results, (item: KnowledgeChunk, i: number) => {
            ListItem() {
              this.ResultCard(item, i)
            }
          })
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      } else {
        this.EmptyGuidance()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async search(): Promise<void> {
    const q = this.query.toLowerCase().trim();
    if (q.length === 0) {
      return;
    }

    this.loading = true;
    this.message = '';
    this.hasError = false;
    this.results = [];
    this.resultMode = '';
    this.updateRelatedResources(q);
    const request: KnowledgeSearchRequest = {
      userId: Constants.DEMO_USER_ID,
      query: q,
      courseId: this.courseId,
      topK: 5,
    };

    try {
      const response = await HttpClient.post<KnowledgeSearchResponse>(Constants.API_KNOWLEDGE_SEARCH, JSON.stringify(request));
      this.results = response.chunks;
      if (this.results.length === 0) {
        this.results = this.searchLocal(q);
        this.resultMode = this.results.length > 0 ? 'local' : '';
        this.message = this.results.length > 0 ? '云端未命中，以下来自本地课程资料' : '未找到相关资料，试试更具体的关键词';
      } else {
        this.resultMode = 'cloud';
        this.message = '已按当前课程整理出可复习资料';
      }
    } catch (e) {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage API failed: %{public}s', (e as Error).message);
      this.results = this.searchLocal(q);
      this.resultMode = this.results.length > 0 ? 'local' : '';
      this.message = this.results.length > 0 ? '云端检索暂不可用，以下来自本地课程资料' :
        '云端检索暂不可用，本地课程资料也未命中';
      this.hasError = this.results.length === 0;
    } finally {
      this.loading = false;
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
