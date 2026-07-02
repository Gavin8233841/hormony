/**
 * AI 辅导页
 * 浅色主题 · 渐变标题栏 · SSE 流式接收 · 欢迎引导
 */

import http from '@ohos.net.http';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Citation, StreamEvent, ChatRequest, ChatMessage, HealthResponse } from '../model/DataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';

interface DisplayMessage {
  id: string;
  role: string;
  content: string;
  citations: Citation[];
  agentTrace: string[];
  thinking: string[];
  citationExpanded: boolean;
  failed: boolean;
  retryQuestion: string;
}

interface MarkdownBlock {
  type: string;
  text: string;
}

@Component
export struct ChatContent {
  @Prop quickQuestion: string = '';
  @State messages: DisplayMessage[] = [];
  @State inputText: string = '';
  @State loading: boolean = false;
  @State probing: boolean = false;
  @StorageLink('cloudAgentReady') cloudAgentReady: boolean = false;
  @State serviceMessage: string = '正在连接云端学伴';
  private scroller: Scroller = new Scroller();
  private currentRequest: http.HttpRequest | null = null;
  private isCancelled: boolean = false;
  private scrollScheduled: boolean = false;
  private deltaChunks: string[] = [];
  private messageRefreshScheduled: boolean = false;
  private messageSerial: number = 0;

  // 推荐问题
  private suggestions: string[] = [
    '什么是二叉搜索树？',
    'TCP 三次握手的过程',
    '动态规划的基本思想',
    '进程和线程的区别',
  ];

  aboutToAppear(): void {
    this.isCancelled = false;
    this.loadLocalHistory();
    this.probeCloudAgent();
    const pendingQuestion = AppStorage.get<string>('pendingChatQuestion') ?? '';
    this.inputText = this.quickQuestion.trim().length > 0 ? this.quickQuestion.trim() : pendingQuestion.trim();
    AppStorage.setOrCreate<string>('pendingChatQuestion', '');
  }

  aboutToDisappear() {
    this.isCancelled = true;
    this.deltaChunks = [];
    if (this.currentRequest) {
      try {
        this.currentRequest.off('dataReceive');
        this.currentRequest.destroy();
      } catch (e) {
        // 忽略销毁异常
      }
      this.currentRequest = null;
    }
  }

  get canSend(): boolean {
    return this.cloudAgentReady && !this.loading && this.inputText.trim().length > 0;
  }

  private markdownBlocks(content: string): MarkdownBlock[] {
    const blocks: MarkdownBlock[] = [];
    const codeLines: string[] = [];
    let inCode = false;
    for (const rawLine of content.split('\n')) {
      const line = rawLine.trimEnd();
      const trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        if (inCode) {
          blocks.push({ type: 'code', text: codeLines.join('\n') });
          codeLines.splice(0, codeLines.length);
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeLines.push(line);
        continue;
      }
      if (trimmed.length === 0) continue;
      if (trimmed.startsWith('### ')) {
        blocks.push({ type: 'heading', text: trimmed.slice(4) });
      } else if (trimmed.startsWith('## ')) {
        blocks.push({ type: 'heading', text: trimmed.slice(3) });
      } else if (trimmed.startsWith('# ')) {
        blocks.push({ type: 'heading', text: trimmed.slice(2) });
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.push({ type: 'bullet', text: trimmed.slice(2) });
      } else {
        blocks.push({ type: 'paragraph', text: line });
      }
    }
    if (codeLines.length > 0) {
      blocks.push({ type: 'code', text: codeLines.join('\n') });
    }
    if (blocks.length === 0 && content.length > 0) {
      blocks.push({ type: 'paragraph', text: content });
    }
    return blocks;
  }

  private createMessageId(prefix: string): string {
    this.messageSerial += 1;
    return prefix + '_' + Date.now().toString() + '_' + this.messageSerial.toString();
  }

  private async loadLocalHistory(): Promise<void> {
    try {
      const history = await LocalLearningRepository.getChatHistory();
      const restored: DisplayMessage[] = [];
      for (const item of history) {
        const message: DisplayMessage = {
          id: this.createMessageId('local'),
          role: item.role,
          content: item.content,
          citations: item.citations ?? [],
          agentTrace: [],
          thinking: [],
          citationExpanded: false,
          failed: false,
          retryQuestion: ''
        };
        restored.push(message);
      }
      this.messages = restored;
    } catch (error) {
      this.serviceMessage = '本地会话记录加载失败';
    }
  }

  private async probeCloudAgent(): Promise<void> {
    const checkedAt = AppStorage.get<number>('cloudAgentCheckedAt') ?? 0;
    const cachedReady = AppStorage.get<boolean>('cloudAgentReady') ?? false;
    if (cachedReady && Date.now() - checkedAt <= Constants.HEALTH_CACHE_MS) {
      this.cloudAgentReady = true;
      this.probing = false;
      this.serviceMessage = '';
      return;
    }

    this.probing = true;
    this.serviceMessage = '正在连接云端学伴';
    try {
      const health = await HttpClient.get<HealthResponse>(Constants.API_HEALTH);
      this.cloudAgentReady = health.status === 'ready';
      this.serviceMessage = this.cloudAgentReady ? '' : '云端学伴尚未就绪';
      AppStorage.setOrCreate<number>('cloudAgentCheckedAt', Date.now());
    } catch (error) {
      this.cloudAgentReady = false;
      this.serviceMessage = '云端学伴暂不可用';
      AppStorage.setOrCreate<number>('cloudAgentCheckedAt', Date.now());
    } finally {
      this.probing = false;
    }
  }

  private scrollToBottom(): void {
    if (this.scrollScheduled) {
      return;
    }
    this.scrollScheduled = true;
    setTimeout(() => {
      this.scrollScheduled = false;
      if (this.messages.length > 0) {
        this.scroller.scrollToIndex(this.messages.length - 1, true, ScrollAlign.END);
      }
    }, 50);
  }

  private refreshMessageList(): void {
    this.messages = this.messages.slice();
    this.scrollToBottom();
  }

  private flushPendingDelta(): void {
    if (this.deltaChunks.length === 0 || this.messages.length === 0) return;
    const last = this.messages[this.messages.length - 1];
    last.content += this.deltaChunks.join('');
    this.deltaChunks = [];
  }

  private scheduleDeltaRefresh(): void {
    if (this.messageRefreshScheduled) return;
    this.messageRefreshScheduled = true;
    setTimeout(() => {
      this.messageRefreshScheduled = false;
      if (this.isCancelled) {
        this.deltaChunks = [];
        return;
      }
      this.flushPendingDelta();
      this.refreshMessageList();
    }, 80);
  }

  build() {
    Column() {
      Column() {
        Text('学伴')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('基于课程资料，为每个问题给出依据')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22, top: 24, bottom: 12 })

      // 消息列表 / 欢迎页
      if (this.messages.length === 0) {
        // 欢迎引导
        Column() {
          // AI 头像
          SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
            .width(56)
            .height(56)
            .fontSize(26)
            .fontColor([Constants.COLOR_BRAND])
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(28)
            .shadow({ radius: 12, color: Constants.SHADOW_BRAND, offsetX: 0, offsetY: 4 })

          Text('你好，我是鸿学伴 AI 助教')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .margin({ top: 16 })

          Text('可以问我任何学习相关的问题，我会从课程资料中检索并给出带引用的回答')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .margin({ top: 8, left: 32, right: 32 })
            .textAlign(TextAlign.Center)

          // 推荐问题
          Text('试试问')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
            .margin({ top: 28, bottom: 10 })

          Column({ space: 8 }) {
            ForEach(this.suggestions, (s: string) => {
              Button(s)
                .fontSize(13)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_LG)
                .height(44)
                .padding({ left: 16, right: 16 })
                .enabled(this.cloudAgentReady && !this.loading)
                .onClick(() => {
                  this.inputText = s;
                  this.sendMessage();
                })
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24, bottom: 100 })
      } else {
        // 消息列表
        List({ scroller: this.scroller }) {
          ForEach(this.messages, (msg: DisplayMessage) => {
            ListItem() {
              this.MessageBubble(msg)
            }
          }, (msg: DisplayMessage): string => msg.id)
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      }

      // 输入栏
      if (this.probing || !this.cloudAgentReady) {
        Row() {
          Text(this.serviceMessage)
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .layoutWeight(1)
          if (this.probing) {
            LoadingProgress().width(18).height(18).color(Constants.COLOR_BRAND)
          } else {
            Button('重试')
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .height(32)
              .onClick((): void => { this.probeCloudAgent(); })
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 8 })
      }
      Row({ space: 12 }) {
        TextInput({
          text: this.inputText,
          placeholder: this.cloudAgentReady ? '输入你的问题...' : '云端学伴连接后可提问'
        })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.cloudAgentReady && !this.loading)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button() {
          SymbolGlyph($r('sys.symbol.paperplane_right_fill'))
            .fontSize(20)
            .fontColor([this.canSend ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND])
        }
          .width(44)
          .height(44)
          .backgroundColor(this.canSend ? Constants.COLOR_BRAND : Constants.COLOR_BRAND_LIGHT)
          .borderRadius(22)
          .enabled(this.canSend)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20, top: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  sendMessage(question?: string): void {
    const content = question !== undefined ? question.trim() : this.inputText.trim();
    if (content.length === 0 || this.loading || !this.cloudAgentReady) {
      return;
    }

    const userMsg: DisplayMessage = {
      id: this.createMessageId('user'),
      role: 'user',
      content: content,
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
      failed: false,
      retryQuestion: '',
    };
    this.messages.push(userMsg);

    const assistantMsg: DisplayMessage = {
      id: this.createMessageId('assistant'),
      role: 'assistant',
      content: '',
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
      failed: false,
      retryQuestion: content,
    };
    this.messages.push(assistantMsg);

    const message = content;
    this.inputText = '';
    this.loading = true;
    this.isCancelled = false;
    this.deltaChunks = [];
    this.scrollToBottom();

    const requestHistory: ChatMessage[] = [];
    for (const item of this.messages.slice(0, this.messages.length - 2).slice(-24)) {
      if (item.content.length === 0) continue;
      const historyItem: ChatMessage = {
        role: item.role,
        content: item.content,
        citations: item.citations
      };
      requestHistory.push(historyItem);
    }
    const req: ChatRequest = {
      userId: Constants.DEMO_USER_ID,
      message: message,
      history: requestHistory,
      context: {
        courseId: AppStorage.get<string>('selectedCourseId') ?? 'cs101'
      }
    };
    LocalLearningRepository.getProfile().then((profile): void => {
      if (profile !== null) req.profile = profile;
      this.startSseRequest(req);
    }).catch((): void => {
      this.startSseRequest(req);
    });
  }

  private startSseRequest(req: ChatRequest): void {
    HttpClient.postSSE(Constants.API_CHAT, JSON.stringify(req),
      (evt: StreamEvent) => {
        if (this.isCancelled) {
          return;
        }
        const last = this.messages[this.messages.length - 1];

        if (evt.type === 'delta' && evt.content) {
          this.deltaChunks.push(evt.content);
          this.scheduleDeltaRefresh();
          return;
        }

        this.flushPendingDelta();
        if (evt.type === 'thinking' && evt.agent) {
          last.thinking.push(evt.agent);
        } else if (evt.type === 'trace' && evt.agent && evt.content) {
          const traceText = evt.agent + ': ' + evt.content.slice(0, 100);
          last.agentTrace.push(traceText);
        } else if (evt.type === 'citation' && evt.source) {
          last.citations.push(evt.source);
        } else if (evt.type === 'error') {
          last.failed = true;
          this.cloudAgentReady = false;
          this.serviceMessage = evt.message ?? '云端学伴暂不可用';
        }

        this.refreshMessageList();
      },
      () => {
        if (this.isCancelled) {
          return;
        }
        this.flushPendingDelta();
        this.loading = false;
        this.currentRequest = null;
        const last = this.messages[this.messages.length - 1];
        if (last.failed || last.content.length === 0) {
          this.messages = this.messages.slice(0, this.messages.length - 1);
        } else {
          this.saveLocalHistory();
        }
        this.refreshMessageList();
      },
      (_err: Error) => {
        if (this.isCancelled) {
          return;
        }
        this.flushPendingDelta();
        this.messages = this.messages.slice(0, this.messages.length - 1);
        this.serviceMessage = '云端学伴暂不可用，请稍后重试';
        this.cloudAgentReady = false;
        this.loading = false;
        this.currentRequest = null;
        this.refreshMessageList();
      },
      (reqInstance: http.HttpRequest) => {
        this.currentRequest = reqInstance;
      }
    );
  }

  private async saveLocalHistory(): Promise<void> {
    const history: ChatMessage[] = [];
    for (const item of this.messages.slice(-24)) {
      if (item.content.length === 0 || item.failed) continue;
      const message: ChatMessage = {
        role: item.role,
        content: item.content,
        citations: item.citations
      };
      history.push(message);
    }
    await LocalLearningRepository.saveChatHistory(history);
  }

  @Builder
  MessageBubble(msg: DisplayMessage) {
    Column() {
      if (msg.role === 'user') {
        // 用户消息右对齐
        Row() {
          Column() {
            Text(msg.content)
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .padding(12)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
          }
          .alignItems(HorizontalAlign.End)
          .constraintSize({ maxWidth: '80%' })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else {
        // AI 消息（带头像）
        Row({ space: 8 }) {
          // AI 头像
          SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
            .width(32)
            .height(32)
            .fontSize(16)
            .fontColor([Constants.COLOR_BRAND])
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(16)

          Column() {
            if (msg.content.length > 0) {
              Column() {
                this.MarkdownContent(msg.content, msg.failed)
              }
                .padding(12)
                .backgroundColor(msg.failed ? Constants.COLOR_ERROR_LIGHT : Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_MD)
                .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
                .width('100%')
            } else {
              Row({ space: 8 }) {
                LoadingProgress().width(16).height(16).color(Constants.COLOR_BRAND)
                Text('正在检索课程资料')
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
            }

            if (msg.failed) {
              Button('重试')
                .fontSize(12)
                .fontColor(Constants.COLOR_BRAND)
                .height(36)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(18)
                .margin({ top: 6 })
                .onClick(() => {
                  msg.failed = false;
                  this.messages = this.messages.slice(0, this.messages.length - 1);
                  this.sendMessage(msg.retryQuestion);
                })
            }

            // 引用（折叠式）
            if (msg.citations.length > 0) {
              Row() {
                Text('参考资料 (' + msg.citations.length + ')')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_BRAND)
                  .padding({ left: 4, right: 4, top: 4, bottom: 4 })
                Text(msg.citationExpanded ? '收起' : '展开')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .margin({ left: 4 })
                if (msg.citationExpanded) {
                  SymbolGlyph($r('sys.symbol.chevron_up'))
                    .fontSize(12)
                    .fontColor([Constants.COLOR_TEXT_SECONDARY])
                    .margin({ left: 4 })
                } else {
                  SymbolGlyph($r('sys.symbol.chevron_down'))
                    .fontSize(12)
                    .fontColor([Constants.COLOR_TEXT_SECONDARY])
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .height(40)
              .margin({ top: 4 })
              .onClick(() => {
                msg.citationExpanded = !msg.citationExpanded;
                this.messages = this.messages.slice();
              })

              if (msg.citationExpanded) {
                Column() {
                  ForEach(msg.citations, (c: Citation, i: number) => {
                    Text('[' + (i + 1) + '] ' + c.doc + (c.snippet ? ' — ' + c.snippet : ''))
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .margin({ bottom: 2 })
                  })
                }
                .width('100%')
                .padding({ left: 4, top: 4 })
              }
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  MarkdownContent(content: string, failed: boolean) {
    Column({ space: 7 }) {
      ForEach(this.markdownBlocks(content), (block: MarkdownBlock): void => {
        if (block.type === 'heading') {
          Text(block.text)
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
        } else if (block.type === 'bullet') {
          Row({ space: 7 }) {
            Text('•')
              .fontSize(14)
              .fontColor(Constants.COLOR_BRAND)
            Text(block.text)
              .layoutWeight(1)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else if (block.type === 'code') {
          Text(block.text)
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor('#d1fae5')
            .fontFamily('monospace')
            .padding(10)
            .backgroundColor('#0f172a')
            .borderRadius(Constants.RADIUS_SM)
        } else {
          Text(block.text)
            .width('100%')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
        }
      })
    }
    .width('100%')
  }

}

@Entry
@Component
struct ChatPage {
  build() {
    Column() {
      ChatContent()
    }
  }
}
