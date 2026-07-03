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
  role: string;
  content: string;
  citations: Citation[];
  agentTrace: string[];
  thinking: string[];
  agentExpanded: boolean;
  citationExpanded: boolean;
  failed: boolean;
  retryQuestion: string;
}

interface MarkdownBlock {
  type: string;
  text: string;
  language?: string;
}

interface CodeLine {
  lineNumber: string;
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
    let codeLanguage = '';
    for (const rawLine of content.split('\n')) {
      const line = rawLine.trimEnd();
      const trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        if (inCode) {
          blocks.push({ type: 'code', text: codeLines.join('\n'), language: codeLanguage });
          codeLines.splice(0, codeLines.length);
          codeLanguage = '';
        } else {
          codeLanguage = this.cleanInline(trimmed.slice(3)).toLowerCase();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeLines.push(line);
        continue;
      }
      if (trimmed.length === 0) continue;
      const headingText = this.headingText(trimmed);
      if (headingText.length > 0) {
        blocks.push({ type: 'heading', text: headingText });
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.push({ type: 'bullet', text: this.cleanInline(trimmed.slice(2)) });
      } else if (this.numberedText(trimmed).length > 0) {
        blocks.push({ type: 'numbered', text: this.numberedText(trimmed) });
      } else if (this.isTableRow(trimmed)) {
        const tableText = this.tableText(trimmed);
        if (tableText.length > 0) {
          blocks.push({ type: 'table', text: tableText });
        }
      } else if (this.isDivider(trimmed)) {
        blocks.push({ type: 'divider', text: '' });
      } else {
        blocks.push({ type: 'paragraph', text: this.cleanInline(line) });
      }
    }
    if (codeLines.length > 0) {
      blocks.push({ type: 'code', text: codeLines.join('\n'), language: codeLanguage });
    }
    if (blocks.length === 0 && content.length > 0) {
      blocks.push({ type: 'paragraph', text: content });
    }
    return blocks;
  }

  private headingText(line: string): string {
    let level = 0;
    while (level < line.length && line.charAt(level) === '#') {
      level += 1;
    }
    if (level > 0 && level <= 6 && line.length > level && line.charAt(level) === ' ') {
      return this.cleanInline(line.slice(level + 1));
    }
    return '';
  }

  private numberedText(line: string): string {
    const dotIndex = line.indexOf('. ');
    const cnIndex = line.indexOf('、');
    let splitIndex = dotIndex;
    let offset = 2;
    if (splitIndex < 0 || (cnIndex > 0 && cnIndex < splitIndex)) {
      splitIndex = cnIndex;
      offset = 1;
    }
    if (splitIndex <= 0) return '';
    const prefix = line.slice(0, splitIndex);
    for (const ch of prefix) {
      if (ch < '0' || ch > '9') return '';
    }
    return prefix + '. ' + this.cleanInline(line.slice(splitIndex + offset));
  }

  private isDivider(line: string): boolean {
    if (line.length < 3) return false;
    for (const ch of line) {
      if (ch !== '-' && ch !== '*' && ch !== '_') return false;
    }
    return true;
  }

  private isTableRow(line: string): boolean {
    return line.indexOf('|') >= 0 && line.indexOf('|') !== line.lastIndexOf('|');
  }

  private tableText(line: string): string {
    const cells: string[] = [];
    for (const cell of line.split('|')) {
      const cleaned = this.cleanInline(cell.trim());
      if (cleaned.length > 0) {
        cells.push(cleaned);
      }
    }
    if (cells.length === 0) return '';
    let divider = true;
    for (const cell of cells) {
      for (const ch of cell) {
        if (ch !== '-' && ch !== ':') {
          divider = false;
        }
      }
    }
    if (divider) return '';
    return cells.join('  ·  ');
  }

  private cleanInline(text: string): string {
    return text
      .replace(/<br\s*\/?\s*>/g, '；')
      .replace(/<[^>]+>/g, '')
      .replace(/\*\*/g, '')
      .replace(/__/g, '')
      .replace(/`/g, '')
      .trim();
  }

  private codeLanguageLabel(language?: string): string {
    const value = (language ?? '').trim();
    return value.length > 0 ? value : 'code';
  }

  private codeLineRows(code: string): CodeLine[] {
    const rows: CodeLine[] = [];
    const lines = code.length > 0 ? code.split('\n') : [''];
    for (let index = 0; index < lines.length; index++) {
      rows.push({
        lineNumber: (index + 1).toString(),
        text: lines[index].length > 0 ? lines[index] : ' '
      });
    }
    return rows;
  }

  private prepareFollowUp(prefix: string, text: string): void {
    const clipped = text.length > 600 ? text.slice(0, 600) + '...' : text;
    this.inputText = prefix + '：\n' + clipped;
    this.scrollToBottom();
  }

  private async loadLocalHistory(): Promise<void> {
    try {
      const history = await LocalLearningRepository.getChatHistory();
      const restored: DisplayMessage[] = [];
      for (const item of history) {
        const message: DisplayMessage = {
          role: item.role,
          content: item.content,
          citations: item.citations ?? [],
          agentTrace: item.agentTrace ?? [],
          thinking: item.thinking ?? [],
          agentExpanded: false,
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
    this.probing = true;
    this.serviceMessage = '正在连接云端学伴';
    try {
      const health = await HttpClient.get<HealthResponse>(Constants.API_HEALTH);
      this.cloudAgentReady = health.status === 'ready';
      this.serviceMessage = this.cloudAgentReady ? '' : '云端学伴尚未就绪';
    } catch (error) {
      this.cloudAgentReady = false;
      this.serviceMessage = '云端学伴暂不可用';
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
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(56)
              .height(56)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(28)
            Image($rawfile('icons/fluent_brain_circuit_24_regular.svg'))
              .width(27)
              .height(27)
              .fillColor(Constants.COLOR_BRAND)
          }
            .width(56)
            .height(56)
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
          })
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
      role: 'user',
      content: content,
      citations: [],
      agentTrace: [],
      thinking: [],
      agentExpanded: false,
      citationExpanded: false,
      failed: false,
      retryQuestion: '',
    };
    this.messages.push(userMsg);

    const assistantMsg: DisplayMessage = {
      role: 'assistant',
      content: '',
      citations: [],
      agentTrace: [],
      thinking: [],
      agentExpanded: true,
      citationExpanded: false,
      failed: false,
      retryQuestion: content,
    };
    this.messages.push(assistantMsg);

    const message = content;
    this.inputText = '';
    this.loading = true;
    this.isCancelled = false;
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

        if (evt.type === 'thinking' && evt.agent) {
          if (!last.thinking.includes(evt.agent)) {
            last.thinking.push(evt.agent);
          }
        } else if (evt.type === 'trace' && evt.agent && evt.content) {
          const traceText = evt.agent + ': ' + evt.content.slice(0, 100);
          if (!last.agentTrace.includes(traceText)) {
            last.agentTrace.push(traceText);
          }
        } else if (evt.type === 'delta' && evt.content) {
          last.content += evt.content;
        } else if (evt.type === 'citation' && evt.source) {
          last.citations.push(evt.source);
        } else if (evt.type === 'error') {
          last.failed = true;
          this.cloudAgentReady = false;
          this.serviceMessage = evt.message ?? '云端学伴暂不可用';
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
        const last = this.messages[this.messages.length - 1];
        if (last.failed || last.content.length === 0) {
          this.messages = this.messages.slice(0, this.messages.length - 1);
        } else {
          this.saveLocalHistory();
        }
      },
      (_err: Error) => {
        if (this.isCancelled) {
          return;
        }
        this.messages = this.messages.slice(0, this.messages.length - 1);
        this.serviceMessage = '云端学伴暂不可用，请稍后重试';
        this.cloudAgentReady = false;
        this.loading = false;
        this.currentRequest = null;
        this.messages = this.messages.slice();
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
        citations: item.citations,
        agentTrace: item.agentTrace,
        thinking: item.thinking
      };
      history.push(message);
    }
    await LocalLearningRepository.saveChatHistory(history);
  }

  private agentLabel(agent: string): string {
    if (agent === 'Profile') return '画像';
    if (agent === 'Retrieval') return '检索';
    if (agent === 'Tutor') return '讲解';
    if (agent === 'Planner') return '规划';
    if (agent === 'Quiz') return '出题';
    if (agent === 'Evaluator') return '评估';
    if (agent === 'Safety') return '安全';
    return agent;
  }

  private agentDescription(agent: string): string {
    if (agent === 'Profile') return '读取本地画像';
    if (agent === 'Retrieval') return '检索课程证据';
    if (agent === 'Tutor') return '组织解释路径';
    if (agent === 'Planner') return '拆解学习计划';
    if (agent === 'Quiz') return '生成分层题目';
    if (agent === 'Evaluator') return '评估薄弱点';
    if (agent === 'Safety') return '检查安全与依据';
    return '执行回答步骤';
  }

  private agentSeen(msg: DisplayMessage, agent: string): boolean {
    if (msg.thinking.includes(agent)) return true;
    for (const trace of msg.agentTrace) {
      if (trace.startsWith(agent + ':')) return true;
    }
    return false;
  }

  private traceAgent(trace: string): string {
    const splitIndex = trace.indexOf(':');
    if (splitIndex <= 0) return '';
    return trace.slice(0, splitIndex);
  }

  private appendAgent(flow: string[], agent: string): void {
    if (agent.length === 0 || flow.includes(agent)) return;
    flow.push(agent);
  }

  private agentFlow(msg: DisplayMessage): string[] {
    const flow: string[] = [];
    const knownOrder: string[] = ['Profile', 'Retrieval', 'Planner', 'Tutor', 'Quiz', 'Evaluator', 'Safety'];
    for (const agent of knownOrder) {
      if (this.agentSeen(msg, agent)) {
        this.appendAgent(flow, agent);
      }
    }
    for (const agent of msg.thinking) {
      this.appendAgent(flow, agent);
    }
    for (const trace of msg.agentTrace) {
      this.appendAgent(flow, this.traceAgent(trace));
    }
    return flow;
  }

  private agentSummary(msg: DisplayMessage): string {
    const count = this.agentFlow(msg).length;
    if (msg.content.length === 0) return '正在协作 · ' + count.toString() + ' 步';
    return '已完成 · ' + count.toString() + ' 步 · ' + msg.citations.length.toString() + ' 条依据';
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
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(32)
              .height(32)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(16)
            Image($rawfile('icons/fluent_brain_circuit_24_regular.svg'))
              .width(17)
              .height(17)
              .fillColor(Constants.COLOR_BRAND)
          }
            .width(32)
            .height(32)

          Column() {
            if (msg.thinking.length > 0 || msg.agentTrace.length > 0) {
              this.AgentWorkbench(msg)
            }

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
              if (msg.thinking.length === 0 && msg.agentTrace.length === 0) {
                Row({ space: 8 }) {
                  LoadingProgress().width(16).height(16).color(Constants.COLOR_BRAND)
                  Text('正在组织回答过程')
                    .fontSize(13)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                }
                .width('100%')
                .padding(12)
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_MD)
              }
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
                Text('依据来源 (' + msg.citations.length + ')')
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
                Column({ space: 8 }) {
                  ForEach(msg.citations, (c: Citation, i: number) => {
                    this.CitationCard(c, i)
                  })
                }
                .width('100%')
                .padding({ left: 4, right: 4, top: 4 })
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
  CitationCard(citation: Citation, index: number) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text('依据 ' + (index + 1).toString())
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(9)
        Text(citation.doc)
          .layoutWeight(1)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if ((citation.snippet ?? '').length > 0) {
        Text(citation.snippet ?? '')
          .width('100%')
          .fontSize(11)
          .lineHeight(17)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .border({ width: 1, color: Constants.COLOR_BORDER })
    .borderRadius(Constants.RADIUS_SM)
  }

  @Builder
  AgentWorkbench(msg: DisplayMessage) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        if (msg.content.length === 0) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(Constants.COLOR_BRAND)
        } else {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .width(16)
            .height(16)
            .fontSize(16)
            .fontColor([Constants.COLOR_SUCCESS])
        }
        Column({ space: 2 }) {
          Text('回答生成过程')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.agentSummary(msg))
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(msg.agentExpanded ? '收起' : '展开')
          .fontSize(11)
          .fontColor(Constants.COLOR_BRAND)
      }
      .width('100%')
      .onClick((): void => {
        msg.agentExpanded = !msg.agentExpanded;
        this.messages = this.messages.slice();
      })

      Column({ space: 6 }) {
        ForEach(this.agentFlow(msg), (agent: string): void => {
          this.AgentStep(agent, msg)
        })
      }
      .width('100%')

      if (msg.agentExpanded) {
        Column({ space: 6 }) {
          ForEach(msg.agentTrace, (trace: string): void => {
            Text(trace)
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(Constants.COLOR_TEXT_TERTIARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Constants.COLOR_SURFACE_TINT)
    .borderRadius(Constants.RADIUS_MD)
    .margin({ bottom: 6 })
  }

  @Builder
  AgentStep(agent: string, msg: DisplayMessage) {
    Column({ space: 4 }) {
      Text(this.agentLabel(agent))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.agentSeen(msg, agent) ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER)
      Text(this.agentDescription(agent))
        .fontSize(9)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 7, right: 7, top: 6, bottom: 6 })
    .backgroundColor(this.agentSeen(msg, agent) ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
    .borderRadius(Constants.RADIUS_SM)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CodeBlockView(block: MarkdownBlock) {
    Column() {
      Row() {
        Row({ space: 6 }) {
          Image($rawfile('icons/fluent_code_24_regular.svg'))
            .width(14)
            .height(14)
            .fillColor(Constants.COLOR_MAP_TEXT_MUTED)
          Text(this.codeLanguageLabel(block.language))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
        }
        .layoutWeight(1)
        Text(this.codeLineRows(block.text).length.toString() + ' 行')
          .fontSize(10)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(Constants.COLOR_MAP_LINE)

      Column({ space: 0 }) {
        ForEach(this.codeLineRows(block.text), (line: CodeLine): void => {
          Row({ space: 8 }) {
            Text(line.lineNumber)
              .width(28)
              .fontSize(11)
              .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
              .textAlign(TextAlign.End)
            Text(line.text)
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .fontFamily('monospace')
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 8, right: 10, top: 2, bottom: 2 })
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Button({ type: ButtonType.Normal }) {
        Row({ space: 6 }) {
          Image($rawfile('icons/fluent_brain_circuit_24_regular.svg'))
            .width(14)
            .height(14)
            .fillColor(Constants.COLOR_BRAND)
          Text('追问此段')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_BRAND)
        }
      }
      .height(34)
      .padding({ left: 10, right: 10 })
      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
      .borderRadius(Constants.RADIUS_SM)
      .alignSelf(ItemAlign.End)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => {
        this.prepareFollowUp('请解释这段代码', block.text);
      })
    }
    .width('100%')
    .backgroundColor(Constants.COLOR_MAP_SURFACE)
    .borderRadius(Constants.RADIUS_SM)
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
        } else if (block.type === 'bullet' || block.type === 'numbered') {
          Row({ space: 7 }) {
            Text(block.type === 'numbered' ? block.text.split(' ')[0] : '•')
              .fontSize(14)
              .fontColor(Constants.COLOR_BRAND)
            Text(block.type === 'numbered' ? block.text.slice(block.text.indexOf(' ') + 1) : block.text)
              .layoutWeight(1)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else if (block.type === 'divider') {
          Divider()
            .width('100%')
            .color(Constants.COLOR_BORDER)
            .margin({ top: 4, bottom: 4 })
        } else if (block.type === 'code') {
          this.CodeBlockView(block)
        } else if (block.type === 'table') {
          Text(block.text)
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
            .padding(9)
            .backgroundColor(Constants.COLOR_SURFACE_TINT)
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
