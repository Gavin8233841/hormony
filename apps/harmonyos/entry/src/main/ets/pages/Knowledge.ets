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
  @StorageProp('darkMode') darkMode: boolean = false;
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
    if (evidence.length > 0) return { label: '相关段落', text: evidence };

    evidence = this.matchedEvidence(segments, this.exactTopic(item));
    if (evidence.length > 0) return { label: '主题相关', text: evidence };
    return { label: '课程资料摘要', text: this.firstSentence(item.text) };
  }

  private validCourseResult(item: KnowledgeChunk): boolean {
    if (typeof item.text !== 'string' || typeof item.source !== 'string') return false;
    if (item.text.trim().length === 0 || item.source.trim().length === 0) return false;
    return typeof item.courseId === 'string' && item.courseId === this.courseId;
  }

  private openLesson(item: KnowledgeChunk): void {
    const topic = this.exactTopic(item);
    if (topic.length === 0) {
      this.message = '该资料尚未关联课程主题，暂时无法开始学习';
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

  private startTopicQuiz(): void {
    const topic = this.resultTopic();
    if (topic.length === 0) {
      this.message = '课程主题已变化，请重新搜索';
      this.hasError = true;
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Quiz router.pushUrl failed: %{public}s', err.message);
    });
  }

  private askTutor(item: KnowledgeChunk): void {
    const topic = this.exactTopic(item);
    const evidence = this.evidenceFor(item);
    const context = topic.length > 0 ? '对应课程主题“' + topic + '”' : '这条资料暂无对应的课程主题';
    const label = evidence.label === '课程资料摘要' ? '资料摘要' : '相关段落';
    AppStorage.setOrCreate<string>('pendingChatQuestion',
      '请解释这段课程资料，举一个例子，再出两道自测题。课程：' + this.courseTitle +
        '；搜索词：' + this.resultQuery + '；' + context + '。来源：' + item.source.trim() +
        '。' + label + '：' + evidence.text);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage Chat router.pushUrl failed: %{public}s', err.message);
    });
  }

  private resultTopic(): string {
    const courseTopics = LearningContentRepository.getTopics(this.courseId);
    for (const item of this.results) {
      const topic = item.topic ?? '';
      if (item.courseId === this.courseId && courseTopics.includes(topic)) return topic;
    }
    return '';
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
          Text(item.source.trim())
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
      }
      .width('100%')

      if (this.exactTopic(item).length > 0) {
        Text(this.exactTopic(item))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .alignSelf(ItemAlign.Start)
      }

      Column({ space: 5 }) {
        Text(this.evidenceFor(item).label)
          .width('100%')
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Text(this.evidenceFor(item).text)
          .width('100%')
          .fontSize(15)
          .lineHeight(23)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ top: 6, bottom: 6 })

      if (this.expandedIndex === index) {
        Text(item.text)
          .width('100%')
          .fontSize(13)
          .lineHeight(22)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }

      Row({ space: 5 }) {
        Text(this.expandedIndex === index ? '收起' : '阅读全文')
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
      .constraintSize({ minHeight: 48 })
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
          .height(48)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.openLesson(item); })
          Button('问学伴')
            .width(94)
            .height(48)
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
          .height(48)
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
    .borderRadius(Constants.RADIUS_LG)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      GradientHeader('课程资料', this.courseTitle, () => this.getUIContext().getRouter().back())

      // 搜索栏
      Row({ space: 12 }) {
        TextInput({ text: this.query, placeholder: '搜索知识点' })
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(12)
          .onChange((v: string) => { this.query = v; })
          .onSubmit(() => { this.search(); })

        Button('搜索')
          .height(48)
          .fontSize(14)
          .backgroundColor(this.canSearch ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
          .fontColor(this.canSearch ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .borderRadius(12)
          .enabled(this.canSearch)
          .onClick(() => { this.search(); })
      }
      .width('100%')
      .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER, bottom: 16 })

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
        Row() {
          Text(this.results.length.toString() + ' 条相关资料')
            .layoutWeight(1)
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          if (this.resultTopic().length > 0) {
            Button('测验 · ' + this.resultTopic())
              .constraintSize({ minHeight: 48 })
              .padding({ left: 12, right: 12 })
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND_TEXT)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.startTopicQuiz(); })
          }
        }
        .width('100%')
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER, bottom: 10 })

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
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER,
          bottom: 20 + SafeAreaInsets.bottomVp() })
      } else {
        Column({ space: 14 }) {
          Text('推荐搜索')
            .width('100%')
            .fontSize(Constants.PAGE_SECTION_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.suggestions, (suggestion: string) => {
              Button(suggestion)
                .constraintSize({ minHeight: 48 })
                .padding({ left: 16, right: 16 })
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND_TEXT)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.query = suggestion;
                  this.search();
                })
            })
          }
          Text('也可以输入其他知识点，从本课程资料中查找。')
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER,
          top: 24, bottom: 24 + SafeAreaInsets.bottomVp() })
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
        this.message = this.results.length > 0 ? '在线搜索没有结果，已显示课程资料' : '未找到相关资料，试试更具体的关键词';
      } else {
        this.message = '';
      }
    } catch (e) {
      if (requestVersion !== this.searchRequestVersion) return;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'KnowledgePage API failed: %{public}s', (e as Error).message);
      this.results = this.searchLocal(q);
      this.message = this.results.length > 0 ? '在线搜索暂不可用，已显示课程资料' :
        '在线搜索暂不可用，已收录资料中也没有结果';
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
