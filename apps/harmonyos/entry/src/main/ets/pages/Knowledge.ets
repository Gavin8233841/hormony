/**
 * 搜课程资料页
 * 浅色主题 · 用户友好文案 · 修复 courseId
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { CuratedKnowledgeChunk, KnowledgeChunk, KnowledgeSearchRequest, KnowledgeSearchResponse } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface LocalKnowledgeMatch {
  chunk: CuratedKnowledgeChunk;
  score: number;
}

interface KnowledgeEvidence {
  label: string;
  text: string;
}

@Entry
@Component
struct KnowledgePage {
  @State query: string = '';
  @State resultQuery: string = '';
  @State results: KnowledgeChunk[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State expandedIndex: number = -1;
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State hasError: boolean = false;
  private suggestions: string[] = ['二叉搜索树', '图的遍历', '动态规划'];
  private searchRequestVersion: number = 0;

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

  private exactTopic(item: KnowledgeChunk): string {
    if (item.topic === undefined || typeof item.topic !== 'string') return '';
    return LearningContentRepository.getTopics(this.courseId).includes(item.topic) ? item.topic : '';
  }

  private firstSentence(text: string): string {
    const value = text.trim();
    if (value.length <= 96) return value;
    const stops: string[] = ['。', '；', '？', '！'];
    let endIndex = -1;
    for (const stop of stops) {
      const index = value.indexOf(stop);
      if (index >= 24 && (endIndex < 0 || index < endIndex)) endIndex = index;
    }
    if (endIndex >= 24 && endIndex < 108) return value.substring(0, endIndex + 1);
    return value.substring(0, 96) + '...';
  }

  private evidenceSegments(text: string): string[] {
    return text
      .replace(/\r\n/g, '\n')
      .split(/[。；？！\n]/)
      .map((segment: string): string => segment.trim())
      .filter((segment: string): boolean => segment.length > 0);
  }

  private matchedEvidence(segments: string[], needle: string): string {
    const normalizedNeedle = needle.trim().toLowerCase();
    if (normalizedNeedle.length < 2) return '';
    for (const segment of segments) {
      const matchIndex = segment.toLowerCase().indexOf(normalizedNeedle);
      if (matchIndex >= 0) return this.clipMatchedEvidence(segment, matchIndex);
    }
    return '';
  }

  private clipMatchedEvidence(segment: string, matchIndex: number): string {
    if (segment.length <= 120) return segment + '。';
    const leadingContext = 36;
    let start = Math.max(matchIndex - leadingContext, 0);
    let end = Math.min(start + 120, segment.length);
    if (end - start < 120) start = Math.max(end - 120, 0);
    const before = start > 0 ? '...' : '';
    const after = end < segment.length ? '...' : '。';
    return before + segment.substring(start, end) + after;
  }

  private evidenceFor(item: KnowledgeChunk): KnowledgeEvidence {
    const segments = this.evidenceSegments(item.text);
    const query = this.resultQuery.trim();
    let evidence = this.matchedEvidence(segments, query);
    if (evidence.length === 0) {
      const queryTerms = query.split(/\s+/).filter((term: string): boolean => term.length >= 2);
      for (const term of queryTerms) {
        evidence = this.matchedEvidence(segments, term);
        if (evidence.length > 0) break;
      }
    }
    if (evidence.length > 0) return { label: '检索词命中', text: evidence };

    evidence = this.matchedEvidence(segments, this.exactTopic(item));
    if (evidence.length > 0) return { label: 'Topic 关联', text: evidence };
    return { label: '课程资料摘要', text: this.firstSentence(item.text) };
  }

  private scoreLabel(item: KnowledgeChunk): string {
    if (item.score === undefined || typeof item.score !== 'number') return '课程资料';
    const score = Math.max(0, Math.min(item.score, 1));
    return '相关度 ' + (score * 100).toFixed(0) + '%';
  }

  private hasNumericScore(item: KnowledgeChunk): boolean {
    return item.score !== undefined && typeof item.score === 'number';
  }

  private validCourseResult(item: KnowledgeChunk): boolean {
    if (typeof item.text !== 'string' || typeof item.source !== 'string') return false;
    if (item.text.trim().length === 0 || item.source.trim().length === 0) return false;
    return typeof item.courseId === 'string' && item.courseId === this.courseId;
  }

  private openLesson(item: KnowledgeChunk): void {
    const topic = this.exactTopic(item);
    if (topic.length === 0) {
      this.message = '该结果未关联当前课程 Topic，无法进入 Lesson';
      this.hasError = true;
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Lesson router.pushUrl failed: %{public}s', err.message);
    });
  }

  private askTutor(item: KnowledgeChunk): void {
    const topic = this.exactTopic(item);
    const evidence = this.evidenceFor(item);
    const context = topic.length > 0 ? '课程 Topic 是“' + topic + '”' : '当前结果没有精确 Topic';
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '我在“' + this.courseTitle + '”中检索“' + this.resultQuery + '”时读到以下课程资料，' + context +
        '。请只结合这段资料解释关键概念，给出一个例子和两个主动回忆问题。来源：' + item.source.trim() +
        '。匹配依据（' + evidence.label + '）：' + evidence.text);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Chat router.pushUrl failed: %{public}s', err.message);
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
    .padding({ left: 16, right: 16, bottom: 20 + SafeAreaInsets.bottomVp() })
  }

  @Builder
  private ResultCard(item: KnowledgeChunk, index: number) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_pages_fill_1'))
            .fontSize(16)
            .fontColor([Constants.COLOR_BRAND])
          Text(item.source.trim())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_BRAND)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        Text(this.scoreLabel(item))
          .fontSize(11)
          .fontColor(this.hasNumericScore(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')

      if (this.exactTopic(item).length > 0) {
        Text(this.exactTopic(item))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
          .alignSelf(ItemAlign.Start)
      }

      Column({ space: 5 }) {
        Text(this.evidenceFor(item).label)
          .width('100%')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Text(this.evidenceFor(item).text)
          .width('100%')
          .fontSize(14)
          .lineHeight(23)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_SM)

      if (this.expandedIndex === index) {
        Text(item.text)
          .width('100%')
          .fontSize(13)
          .lineHeight(22)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
          .maxLines(40)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Row({ space: 5 }) {
        Text(this.expandedIndex === index ? '收起全文' : '展开全文')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        if (this.expandedIndex === index) {
          SymbolGlyph($r('sys.symbol.chevron_up'))
            .fontSize(11)
            .fontColor([Constants.COLOR_TEXT_SECONDARY])
        } else {
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(11)
            .fontColor([Constants.COLOR_TEXT_SECONDARY])
        }
      }
      .height(32)
      .alignSelf(ItemAlign.Start)
      .onClick((): void => { this.expandedIndex = this.expandedIndex === index ? -1 : index; })

      if (this.exactTopic(item).length > 0) {
        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(15)
                .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
              Text('进入主题')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            }
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.openLesson(item); })
          Button('问学伴')
            .width(94)
            .height(44)
            .fontSize(12)
            .fontColor(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.askTutor(item); })
        }
        .width('100%')
      } else {
        Button('问学伴解释这段资料')
          .width('100%')
          .height(44)
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.askTutor(item); })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_MD)
    .alignItems(HorizontalAlign.Start)
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
      .padding({ left: 16, right: 16, bottom: 16 })

      if (this.message.length > 0) {
        Row({ space: 8 }) {
          if (this.hasError) {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_ERROR])
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
        // 结果列表
        Text('找到 ' + this.results.length + ' 条相关资料')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ left: 16, bottom: 8 })

        List({ space: 12 }) {
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
        .padding({ left: 16, right: 16, bottom: 20 + SafeAreaInsets.bottomVp() })
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(44)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('搜索' + this.courseTitle + '知识点')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('输入概念、章节或问题，结果将限定在当前课程资料中')
            .fontSize(12)
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
          .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 28, right: 28, bottom: 24 + SafeAreaInsets.bottomVp() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  async search(): Promise<void> {
    const submittedQuery = this.query.trim();
    if (submittedQuery.length === 0) {
      return;
    }
    const requestVersion = ++this.searchRequestVersion;
    const q = submittedQuery.toLowerCase();

    this.loading = true;
    this.resultQuery = submittedQuery;
    this.message = '';
    this.hasError = false;
    this.results = [];
    this.expandedIndex = -1;
    const request: KnowledgeSearchRequest = {
      userId: Constants.DEMO_USER_ID,
      query: q,
      courseId: this.courseId,
      topK: 5,
    };

    try {
      const response = await HttpClient.post<KnowledgeSearchResponse>(Constants.API_KNOWLEDGE_SEARCH, JSON.stringify(request));
      if (requestVersion !== this.searchRequestVersion) return;
      this.results = response.chunks.filter((item: KnowledgeChunk): boolean => this.validCourseResult(item)).slice(0, 5);
      if (this.results.length === 0) {
        this.results = this.searchLocal(q);
        this.message = this.results.length > 0 ? '云端未命中，以下来自本地课程资料' : '未找到相关资料，试试更具体的关键词';
      } else {
        this.message = '已返回当前课程的相关资料';
      }
    } catch (e) {
      if (requestVersion !== this.searchRequestVersion) return;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage API failed: %{public}s', (e as Error).message);
      this.results = this.searchLocal(q);
      this.message = this.results.length > 0 ? '云端检索暂不可用，以下来自本地课程资料' :
        '云端检索暂不可用，本地课程资料也未命中';
      this.hasError = this.results.length === 0;
    } finally {
      if (requestVersion === this.searchRequestVersion) this.loading = false;
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
