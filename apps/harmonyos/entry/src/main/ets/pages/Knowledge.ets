/**
 * 搜课程资料页
 * 浅色主题 · 用户友好文案 · 修复 courseId
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { KnowledgeChunk, KnowledgeSearchRequest, KnowledgeSearchResponse } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
  private suggestions: string[] = ['二叉搜索树', '图的遍历', '动态规划'];

  private demoChunks: KnowledgeChunk[] = [
    { text: '二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。', source: '数据结构.pdf', courseId: 'cs101' },
    { text: '动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算。', source: '数据结构.pdf', courseId: 'cs101' },
    { text: '进程调度算法包括 FCFS、SJF、时间片轮转、多级反馈队列等。', source: '操作系统.pdf', courseId: 'cs102' },
    { text: 'TCP 三次握手：SYN → SYN+ACK → ACK，建立可靠连接。', source: '计算机网络.pdf', courseId: 'cs103' },
    { text: '图的遍历分为 DFS 和 BFS，DFS 使用栈/递归，BFS 使用队列。', source: '数据结构.pdf', courseId: 'cs101' },
  ];

  get canSearch(): boolean {
    return !this.loading && this.query.trim().length > 0;
  }

  private startTopicQuiz(): void {
    const topic = this.query.trim().length > 0 ? this.query.trim() : '综合';
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
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
        // 结果列表
        Text('找到 ' + this.results.length + ' 条相关资料')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ left: 16, bottom: 8 })

        Button('复习后，针对“' + this.query + '”开始测验')
          .height(42)
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .margin({ left: 16, right: 16, bottom: 10 })
          .onClick(() => { this.startTopicQuiz(); })

        List({ space: 12 }) {
          ForEach(this.results, (item: KnowledgeChunk, i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Row({ space: 8 }) {
                    SymbolGlyph($r('sys.symbol.book_pages_fill_1'))
                      .fontSize(16)
                      .fontColor([Constants.COLOR_BRAND])
                    Text(item.source)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_BRAND)
                  }
                  .layoutWeight(1)
                  if (item.score !== undefined) {
                    Text('相关度 ' + (item.score * 100).toFixed(0) + '%')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_SUCCESS)
                  }
                }
                .width('100%')
                .margin({ bottom: 6 })

                Text(item.text)
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  .maxLines(this.expandedIndex === i ? 20 : 3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 4 }) {
                  Text(this.expandedIndex === i ? '收起全文' : '展开全文')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  if (this.expandedIndex === i) {
                    SymbolGlyph($r('sys.symbol.chevron_up'))
                      .fontSize(11)
                      .fontColor([Constants.COLOR_TEXT_SECONDARY])
                  } else {
                    SymbolGlyph($r('sys.symbol.chevron_down'))
                      .fontSize(11)
                      .fontColor([Constants.COLOR_TEXT_SECONDARY])
                  }
                }
                .height(36)
                .margin({ top: 6 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
              .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
              .alignItems(HorizontalAlign.Start)
              .scale({ x: this.pressedIndex === i ? 0.98 : 1, y: this.pressedIndex === i ? 0.98 : 1 })
              .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
              .onTouch((event?: TouchEvent) => {
                if (event) {
                  if (event.type === TouchType.Down) {
                    this.pressedIndex = i;
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedIndex = -1;
                  }
                }
              })
              .onClick(() => {
                this.expandedIndex = this.expandedIndex === i ? -1 : i;
              })
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
          Row({ space: 8 }) {
            ForEach(this.suggestions, (suggestion: string) => {
              Button(suggestion)
                .height(40)
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(20)
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
        .padding({ left: 28, right: 28, bottom: 24 })
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
        this.message = '未找到相关资料，试试更具体的关键词';
      }
    } catch (e) {
      if (Constants.__DEBUG__) {
        // 调试模式：回退本地检索
        this.results = this.demoChunks.filter(
          (c: KnowledgeChunk): boolean => c.courseId === this.courseId &&
            (c.text.toLowerCase().includes(q) || c.source.toLowerCase().includes(q))
        );
        this.message = this.results.length > 0 ? '网络不可用，已切换本地检索' : '本地资料中未找到相关内容';
      } else {
        this.message = '检索失败，请检查网络';
        this.hasError = true;
      }
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
