/**
 * AI 辅导页
 * 浅色主题 · 渐变标题栏 · SSE 流式接收 · 欢迎引导
 */

import http from '@ohos.net.http';
import { HttpClient } from '../common/HttpClient';
import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { Citation, StreamEvent, ChatRequest } from '../model/DataModels';

interface DisplayMessage {
  role: string;
  content: string;
  citations: Citation[];
  agentTrace: string[];
  thinking: string[];
  citationExpanded: boolean;
}

@Entry
@Component
struct Chat {
  @State messages: DisplayMessage[] = [];
  @State inputText: string = '';
  @State loading: boolean = false;
  private scroller: Scroller = new Scroller();
  private currentRequest: http.HttpRequest | null = null;
  private isCancelled: boolean = false;

  // 推荐问题
  private suggestions: string[] = [
    '什么是二叉搜索树？',
    'TCP 三次握手的过程',
    '动态规划的基本思想',
    '进程和线程的区别',
  ];

  aboutToDisappear() {
    this.isCancelled = true;
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
    return !this.loading && this.inputText.trim().length > 0;
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      if (this.messages.length > 0) {
        this.scroller.scrollToIndex(this.messages.length - 1, true, ScrollAlign.END);
      }
    }, 50);
  }

  build() {
    Column() {
      GradientHeader('AI 辅导', '', () => this.getUIContext().getRouter().back())

      // 消息列表 / 欢迎页
      if (this.messages.length === 0) {
        // 欢迎引导
        Column() {
          // AI 头像
          Text('AI')
            .width(56)
            .height(56)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(28)
            .textAlign(TextAlign.Center)
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
              Text(s)
                .fontSize(13)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_LG)
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
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
          })
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      }

      // 思考状态
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(Constants.COLOR_BRAND)
          Text('正在思考...')
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 20, bottom: 8 })
      }

      // 输入栏
      Row({ space: 12 }) {
        TextInput({ text: this.inputText, placeholder: '输入你的问题...' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_MD)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button('发送')
          .fontSize(14)
          .backgroundColor(this.canSend ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
          .fontColor(this.canSend ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .borderRadius(Constants.RADIUS_MD)
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

  sendMessage() {
    if (this.inputText.trim().length === 0 || this.loading) {
      return;
    }

    const userMsg: DisplayMessage = {
      role: 'user',
      content: this.inputText.trim(),
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
    };
    this.messages.push(userMsg);

    const assistantMsg: DisplayMessage = {
      role: 'assistant',
      content: '',
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
    };
    this.messages.push(assistantMsg);

    const message = this.inputText.trim();
    this.inputText = '';
    this.loading = true;
    this.isCancelled = false;
    this.scrollToBottom();

    const req: ChatRequest = {
      userId: Constants.DEMO_USER_ID,
      message: message,
    };
    HttpClient.postSSE(
      Constants.API_CHAT,
      JSON.stringify(req),
      (evt: StreamEvent) => {
        if (this.isCancelled) {
          return;
        }
        const last = this.messages[this.messages.length - 1];

        if (evt.type === 'thinking' && evt.agent) {
          last.thinking.push(evt.agent);
        } else if (evt.type === 'trace' && evt.agent && evt.content) {
          const traceText = evt.agent + ': ' + evt.content.slice(0, 100);
          last.agentTrace.push(traceText);
        } else if (evt.type === 'delta' && evt.content) {
          last.content += evt.content;
        } else if (evt.type === 'citation' && evt.source) {
          last.citations.push(evt.source);
        }

        this.messages = this.messages.slice();
        this.scrollToBottom();
      },
      () => {
        if (this.isCancelled) {
          return;
        }
        this.loading = false;
        this.currentRequest = null;
      },
      (err: Error) => {
        if (this.isCancelled) {
          return;
        }
        const last = this.messages[this.messages.length - 1];
        last.content = '请求失败: ' + err.message;
        this.loading = false;
        this.currentRequest = null;
        this.messages = this.messages.slice();
      },
      (reqInstance: http.HttpRequest) => {
        this.currentRequest = reqInstance;
      }
    );
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
          Text('AI')
            .width(32)
            .height(32)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(16)
            .textAlign(TextAlign.Center)

          Column() {
            Text(msg.content.length > 0 ? msg.content : '思考中...')
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .padding(12)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_MD)
              .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
              .width('100%')

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
              }
              .width('100%')
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

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
