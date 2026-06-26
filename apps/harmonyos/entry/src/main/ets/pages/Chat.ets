/**
 * AI 对话页
 * 通过 SSE 流式接收多 Agent 协作结果
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
          .fontColor('#e2e8f0')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text('AI 对话辅导')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#e2e8f0')
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      // 消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (msg: DisplayMessage, index: number) => {
          ListItem() {
            this.MessageBubble(msg)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })

      // Agent 思考状态
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color('#3b82f6')
          Text('Agent 协作中...')
            .fontSize(12)
            .fontColor('#94a3b8')
        }
        .width('100%')
        .padding({ left: 20, bottom: 8 })
      }

      // 输入栏
      Row({ space: 12 }) {
        TextInput({ text: this.inputText, placeholder: '输入你的问题...' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#1e293b')
          .borderRadius(12)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button('发送')
          .fontSize(14)
          .backgroundColor('#2563eb')
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
    .backgroundColor('#0f172a')
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
    };
    this.messages.push(userMsg);

    const assistantMsg: DisplayMessage = {
      role: 'assistant',
      content: '',
      citations: [],
      agentTrace: [],
      thinking: [],
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
  MessageBubble(msg: DisplayMessage) {
    Column() {
      if (msg.role === 'user') {
        // 用户消息右对齐
        Row() {
          Column() {
            Text(msg.content)
              .fontSize(14)
              .fontColor('#e2e8f0')
              .padding(12)
              .backgroundColor('#2563eb40')
              .borderRadius(12)
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else {
        // 助手消息
        Column() {
          // Agent 思考标签
          if (msg.thinking.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(msg.thinking, (agent: string) => {
                Text(agent)
                  .fontSize(10)
                  .fontColor('#94a3b8')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#334155')
                  .borderRadius(8)
                  .margin({ right: 4, bottom: 4 })
              })
            }
            .width('100%')
            .margin({ bottom: 6 })
          }

          Text(msg.content.length > 0 ? msg.content : '思考中...')
            .fontSize(14)
            .fontColor('#e2e8f0')
            .padding(12)
            .backgroundColor('#1e293b')
            .borderRadius(12)
            .width('100%')

          // 引用
          if (msg.citations.length > 0) {
            Column() {
              Text('资料引用：')
                .fontSize(11)
                .fontColor('#64748b')
                .margin({ top: 8, bottom: 4 })
              ForEach(msg.citations, (c: Citation, i: number) => {
                Text(`[${i + 1}] ${c.doc}${c.snippet ? ' — ' + c.snippet : ''}`)
                  .fontSize(11)
                  .fontColor('#94a3b8')
                  .margin({ bottom: 2 })
              })
            }
            .width('100%')
          }

          // Agent 轨迹
          if (msg.agentTrace.length > 0) {
            Column() {
              Text('Agent 执行轨迹：')
                .fontSize(11)
                .fontColor('#64748b')
                .margin({ top: 8, bottom: 4 })
              ForEach(msg.agentTrace, (trace: string) => {
                Text(trace)
                  .fontSize(11)
                  .fontColor('#94a3b8')
                  .margin({ bottom: 2 })
              })
            }
            .width('100%')
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
