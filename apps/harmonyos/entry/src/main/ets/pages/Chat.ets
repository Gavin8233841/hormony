/**
 * AI 辅导页
 * 浅色主题 · 用户友好文案 · SSE 流式接收
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { ChatMessage, Citation, StreamEvent, ChatRequest } from '../model/DataModels';

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

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#1a1a1a')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text('AI 辅导')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      // 消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (msg: DisplayMessage, index: number) => {
          ListItem() {
            this.MessageBubble(msg, index)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 思考状态
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color('#0a59f7')
          Text('正在思考...')
            .fontSize(13)
            .fontColor('#929292')
        }
        .width('100%')
        .padding({ left: 20, bottom: 8 })
      }

      // 输入栏
      Row({ space: 12 }) {
        TextInput({ text: this.inputText, placeholder: '输入你的问题...' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#ffffff')
          .borderRadius(12)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button('发送')
          .fontSize(14)
          .backgroundColor('#0a59f7')
          .fontColor('#ffffff')
          .borderRadius(12)
          .enabled(!this.loading && this.inputText.length > 0)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20, top: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f6f8')
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

    const req: ChatRequest = {
      userId: Constants.DEMO_USER_ID,
      message: message,
    };
    HttpClient.postSSE(
      Constants.API_CHAT,
      req,
      (event: Record<string, Object>) => {
        const evt: StreamEvent = {
          type: event['type'] as string,
          agent: event['agent'] as string | undefined,
          content: event['content'] as string | undefined,
          source: event['source'] as Citation | undefined,
          sessionId: event['sessionId'] as string | undefined,
        };
        const last = this.messages[this.messages.length - 1];

        if (evt.type === 'thinking' && evt.agent) {
          last.thinking.push(evt.agent);
        } else if (evt.type === 'trace' && evt.agent && evt.content) {
          last.agentTrace.push(`${evt.agent}: ${evt.content.slice(0, 100)}`);
        } else if (evt.type === 'delta' && evt.content) {
          last.content += evt.content;
        } else if (evt.type === 'citation' && evt.source) {
          last.citations.push(evt.source);
        }

        // 触发刷新
        this.messages = this.messages.slice();
      },
      () => {
        this.loading = false;
      },
      (err: Error) => {
        const last = this.messages[this.messages.length - 1];
        last.content = `请求失败: ${err.message}`;
        this.loading = false;
        this.messages = this.messages.slice();
      }
    );
  }

  @Builder
  MessageBubble(msg: DisplayMessage, index: number) {
    Column() {
      if (msg.role === 'user') {
        // 用户消息右对齐
        Row() {
          Column() {
            Text(msg.content)
              .fontSize(14)
              .fontColor('#ffffff')
              .padding(12)
              .backgroundColor('#0a59f7')
              .borderRadius(12)
          }
          .alignItems(HorizontalAlign.End)
          .constraintSize({ maxWidth: '80%' })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else {
        // AI 消息
        Column() {
          Text(msg.content.length > 0 ? msg.content : '思考中...')
            .fontSize(14)
            .fontColor('#1a1a1a')
            .padding(12)
            .backgroundColor('#ffffff')
            .borderRadius(12)
            .width('100%')

          // 引用（折叠式）
          if (msg.citations.length > 0) {
            Row() {
              Text(`参考资料 (${msg.citations.length})`)
                .fontSize(12)
                .fontColor('#0a59f7')
                .padding({ left: 4, right: 4, top: 4, bottom: 4 })
              Text(msg.citationExpanded ? '收起' : '展开')
                .fontSize(12)
                .fontColor('#929292')
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
                  Text(`[${i + 1}] ${c.doc}${c.snippet ? ' — ' + c.snippet : ''}`)
                    .fontSize(11)
                    .fontColor('#929292')
                    .margin({ bottom: 2 })
                })
              }
              .width('100%')
              .padding({ left: 4, top: 4 })
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
