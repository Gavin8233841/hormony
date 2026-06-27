/**
 * 搜课程资料页
 * 浅色主题 · 用户友好文案 · 修复 courseId
 */

import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { KnowledgeChunk, KnowledgeSearchRequest, KnowledgeSearchResponse } from '../model/DataModels';

@Entry
@Component
struct KnowledgePage {
  @State query: string = '';
  @State results: KnowledgeChunk[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State pressedIndex: number = -1;

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

  build() {
    Column() {
      GradientHeader('搜课程资料', '搜索知识点和相关资料', () => this.getUIContext().getRouter().back())

      // 搜索栏
      Row({ space: 12 }) {
        TextInput({ text: this.query, placeholder: '输入关键词...' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(12)
          .onChange((v: string) => { this.query = v; })
          .onSubmit(() => { this.search(); })

        Button('检索')
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
        Text(this.message)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ left: 16, bottom: 8 })
          .width('100%')
      }

      // 加载中
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Constants.COLOR_BRAND)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.results.length > 0) {
        // 结果列表
        Text('找到 ' + this.results.length + ' 条相关资料')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ left: 16, bottom: 8 })

        List({ space: 12 }) {
          ForEach(this.results, (item: KnowledgeChunk, i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.source)
                    .fontSize(13)
                    .fontColor(Constants.COLOR_BRAND)
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
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
              .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
              .alignItems(HorizontalAlign.Start)
              .scale({ x: this.pressedIndex === i ? 0.98 : 1, y: this.pressedIndex === i ? 0.98 : 1 })
              .animation({ duration: 100, curve: Curve.EaseOut })
              .onTouch((event?: TouchEvent) => {
                if (event) {
                  if (event.type === TouchType.Down) {
                    this.pressedIndex = i;
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedIndex = -1;
                  }
                }
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
        // 空状态
        Column() {
          Text('输入关键词开始搜索')
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
    this.results = [];
    const request: KnowledgeSearchRequest = {
      query: q,
      courseId: 'cs101',
      topK: 5,
    };

    try {
      const response = await HttpClient.post<KnowledgeSearchResponse>(Constants.API_KNOWLEDGE_SEARCH, JSON.stringify(request));
      this.results = response.chunks;
      this.message = '检索到 ' + this.results.length + ' 条资料';
    } catch (e) {
      if (Constants.__DEBUG__) {
        // 调试模式：回退本地检索
        this.results = this.demoChunks.filter(
          (c: KnowledgeChunk): boolean => c.text.toLowerCase().includes(q) || c.source.toLowerCase().includes(q)
        );
        this.message = '网络不可用，已切换本地检索';
      } else {
        this.message = '检索失败，请检查网络';
      }
    } finally {
      this.loading = false;
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
