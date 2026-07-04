/**
 * AI 辅导页
 * 浅色主题 · 渐变标题栏 · SSE 流式接收 · 欢迎引导
 */

import http from '@ohos.net.http';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Citation, StreamEvent, ChatRequest, ChatMessage, HealthResponse } from '../model/DataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { StagedProgress, WorkStep } from '../common/Builders';

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
  meta?: string;
  lines?: string[];
  tableRows?: string[][];
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
  private answerSteps: WorkStep[] = [
    { title: '理解', description: '识别问题和课程上下文' },
    { title: '查证', description: '检索课程资料与依据' },
    { title: '讲解', description: '组织例子、步骤和代码' },
    { title: '核对', description: '补充引用并检查表达' }
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
    const tableRows: string[][] = [];
    let codeLanguage = '';
    let inCode = false;
    for (const rawLine of content.split('\n')) {
      const line = rawLine.trimEnd();
      const trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        this.appendTableBlock(blocks, tableRows);
        if (inCode) {
          blocks.push({ type: 'code', text: codeLines.join('\n'), meta: codeLanguage, lines: codeLines.slice() });
          codeLines.splice(0, codeLines.length);
          codeLanguage = '';
        } else {
          codeLanguage = trimmed.slice(3).trim();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeLines.push(line);
        continue;
      }
      if (trimmed.length === 0) {
        this.appendTableBlock(blocks, tableRows);
        continue;
      }
      if (this.isTableRow(trimmed)) {
        const cells = this.tableCells(trimmed);
        if (cells.length > 0) {
          tableRows.push(cells);
        }
        continue;
      }
      this.appendTableBlock(blocks, tableRows);
      const headingText = this.headingText(trimmed);
      if (headingText.length > 0) {
        blocks.push({ type: 'heading', text: headingText });
      } else if (trimmed.startsWith('>')) {
        const quote = this.cleanInline(trimmed.slice(1));
        if (quote.length > 0) {
          blocks.push({ type: 'quote', text: quote });
        }
      } else if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('* [ ] ')) {
        blocks.push({ type: 'task', text: this.cleanInline(trimmed.slice(6)), meta: 'open' });
      } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ') ||
        trimmed.startsWith('* [x] ') || trimmed.startsWith('* [X] ')) {
        blocks.push({ type: 'task', text: this.cleanInline(trimmed.slice(6)), meta: 'done' });
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.push({ type: 'bullet', text: this.cleanInline(trimmed.slice(2)) });
      } else if (this.numberedText(trimmed).length > 0) {
        blocks.push({ type: 'numbered', text: this.numberedText(trimmed) });
      } else if (this.isDivider(trimmed)) {
        blocks.push({ type: 'divider', text: '' });
      } else {
        blocks.push({ type: 'paragraph', text: this.cleanInline(line) });
      }
    }
    this.appendTableBlock(blocks, tableRows);
    if (codeLines.length > 0) {
      blocks.push({ type: 'code', text: codeLines.join('\n'), meta: codeLanguage, lines: codeLines.slice() });
    }
    if (blocks.length === 0 && content.length > 0) {
      blocks.push({ type: 'paragraph', text: content });
    }
    return blocks;
  }

  private appendTableBlock(blocks: MarkdownBlock[], rows: string[][]): void {
    if (rows.length === 0) return;
    const copiedRows: string[][] = [];
    for (const row of rows) {
      copiedRows.push(row.slice());
    }
    blocks.push({ type: 'table', text: '', tableRows: copiedRows });
    rows.splice(0, rows.length);
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

  private tableCells(line: string): string[] {
    const cells: string[] = [];
    for (const cell of line.split('|')) {
      const cleaned = this.cleanInline(cell.trim());
      if (cleaned.length > 0) {
        cells.push(cleaned);
      }
    }
    if (cells.length === 0) return [];
    let divider = true;
    for (const cell of cells) {
      for (const ch of cell) {
        if (ch !== '-' && ch !== ':') {
          divider = false;
        }
      }
    }
    if (divider) return [];
    return cells;
  }

  private cleanInline(text: string): string {
    return this.formatInlineCode(text)
      .replace(/<br\s*\/?\s*>/g, '；')
      .replace(/<[^>]+>/g, '')
      .replace(/\*\*/g, '')
      .replace(/__/g, '')
      .replace(/\*/g, '')
      .replace(/`/g, '')
      .trim();
  }

  private formatInlineCode(text: string): string {
    let result = '';
    let segment = '';
    let inCode = false;
    for (let index = 0; index < text.length; index++) {
      const ch = text.charAt(index);
      if (ch === '`') {
        if (inCode) {
          result += '「' + segment + '」';
        } else {
          result += segment;
        }
        segment = '';
        inCode = !inCode;
      } else {
        segment += ch;
      }
    }
    return result + segment;
  }

  private codeLanguage(block: MarkdownBlock): string {
    const language = block.meta ?? '';
    return language.length > 0 ? language : 'code';
  }

  private taskDone(block: MarkdownBlock): boolean {
    return block.meta === 'done';
  }

  private codeLines(block: MarkdownBlock): string[] {
    if (block.lines !== undefined && block.lines.length > 0) return block.lines;
    return block.text.split('\n');
  }

  private codeContentWidth(block: MarkdownBlock): number {
    let maxLength = 24;
    for (const line of this.codeLines(block)) {
      maxLength = Math.max(maxLength, line.length);
    }
    return Math.min(Math.max(maxLength * 8 + 16, 260), 720);
  }

  private tableRows(block: MarkdownBlock): string[][] {
    return block.tableRows ?? [];
  }

  private tableColumnCount(block: MarkdownBlock): number {
    let count = 1;
    for (const row of this.tableRows(block)) {
      count = Math.max(count, row.length);
    }
    return count;
  }

  private tableWidth(block: MarkdownBlock): number {
    return Math.min(Math.max(this.tableColumnCount(block) * 118, 260), 708);
  }

  private tableCellText(row: string[], index: number): string {
    return index < row.length ? row[index] : '';
  }

  private tableColumnIndexes(block: MarkdownBlock): number[] {
    const indexes: number[] = [];
    for (let index = 0; index < this.tableColumnCount(block); index++) {
      indexes.push(index);
    }
    return indexes;
  }

  private codeQuestion(block: MarkdownBlock, mode: string): string {
    let snippet = block.text;
    if (snippet.length > 680) {
      snippet = snippet.substring(0, 680) + '\n...';
    }
    const language = this.codeLanguage(block);
    if (mode === 'output') {
      return '请帮我预测这段 ' + language + ' 代码的输出，并按步骤解释变量或状态变化：\n\n```' +
        language + '\n' + snippet + '\n```';
    }
    return '请用适合学生理解的步骤解释这段 ' + language + ' 代码，指出关键语句和容易错的地方：\n\n```' +
      language + '\n' + snippet + '\n```';
  }

  private prefillCodeQuestion(block: MarkdownBlock, mode: string): void {
    this.inputText = this.codeQuestion(block, mode);
  }

  private answerProgressIndex(msg: DisplayMessage): number {
    if (msg.content.length > 0 || msg.citations.length > 0) return 3;
    if (this.agentSeen(msg, 'Tutor') || this.agentSeen(msg, 'Planner') ||
      this.agentSeen(msg, 'Quiz') || this.agentSeen(msg, 'Evaluator')) return 2;
    if (this.agentSeen(msg, 'Retrieval')) return 1;
    return 0;
  }

  private answerProgressTitle(msg: DisplayMessage): string {
    if (msg.content.length > 0) return '回答已生成';
    const index = this.answerProgressIndex(msg);
    if (index >= 2) return '正在组织讲解';
    if (index === 1) return '正在查找课程依据';
    return '正在理解你的问题';
  }

  private answerProgressSubtitle(msg: DisplayMessage): string {
    const index = this.answerProgressIndex(msg);
    if (msg.content.length > 0) {
      return '已把解释、例子和参考资料整理到回答中';
    }
    return this.answerSteps[index].description;
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
          .onClick(() => {
            if (this.canSend) {
              this.sendMessage();
            } else if (!this.probing && !this.cloudAgentReady) {
              this.probeCloudAgent();
            }
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
    if (agent === 'Profile') return '理解你的学习情况';
    if (agent === 'Retrieval') return '查找课程依据';
    if (agent === 'Tutor') return '组织讲解';
    if (agent === 'Planner') return '拆解学习路径';
    if (agent === 'Quiz') return '生成练习';
    if (agent === 'Evaluator') return '定位薄弱点';
    if (agent === 'Safety') return '核对安全与依据';
    return agent;
  }

  private agentDescription(agent: string): string {
    if (agent === 'Profile') return '结合本地学习记录';
    if (agent === 'Retrieval') return '从课程资料中找证据';
    if (agent === 'Tutor') return '把概念转成例子和步骤';
    if (agent === 'Planner') return '给出可执行学习顺序';
    if (agent === 'Quiz') return '补充适合当前难度的练习';
    if (agent === 'Evaluator') return '标出需要回头补的知识点';
    if (agent === 'Safety') return '检查表达是否可靠';
    return '处理当前步骤';
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
    if (msg.content.length === 0) return '正在生成 · ' + count.toString() + ' 个步骤';
    return '已完成 · ' + count.toString() + ' 个步骤 · ' + msg.citations.length.toString() + ' 条依据';
  }

  private traceDisplayText(trace: string): string {
    const splitIndex = trace.indexOf(':');
    if (splitIndex <= 0) return trace;
    const agent = trace.slice(0, splitIndex);
    const content = trace.slice(splitIndex + 1).trim();
    if (content.length === 0) return this.agentLabel(agent);
    return this.agentLabel(agent) + '：' + content;
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
            if (msg.thinking.length > 0 || msg.agentTrace.length > 0) {
              this.AnswerProcessCard(msg)
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
                this.AnswerProcessCard(msg)
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
  AnswerProcessCard(msg: DisplayMessage) {
    Column({ space: 10 }) {
      if (msg.content.length === 0) {
        StagedProgress(this.answerProgressTitle(msg), this.answerProgressSubtitle(msg),
          this.answerProgressIndex(msg), this.answerSteps)
      }
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
            Text(this.traceDisplayText(trace))
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
  MarkdownContent(content: string, failed: boolean) {
    Column({ space: 7 }) {
      ForEach(this.markdownBlocks(content), (block: MarkdownBlock): void => {
        if (block.type === 'heading') {
          Text(block.text)
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
        } else if (block.type === 'quote') {
          Row({ space: 9 }) {
            Column()
              .width(3)
              .height('100%')
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(2)
            Text(block.text)
              .layoutWeight(1)
              .fontSize(13)
              .lineHeight(21)
              .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .padding({ left: 9, right: 9, top: 8, bottom: 8 })
          .backgroundColor(Constants.COLOR_SURFACE_TINT)
          .borderRadius(Constants.RADIUS_SM)
          .alignItems(VerticalAlign.Top)
        } else if (block.type === 'task') {
          Row({ space: 8 }) {
            Text(this.taskDone(block) ? '✓' : '○')
              .width(20)
              .height(20)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.taskDone(block) ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.taskDone(block) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND_LIGHT)
              .borderRadius(10)
            Text(block.text)
              .layoutWeight(1)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
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
          this.MarkdownCodeBlock(block)
        } else if (block.type === 'table') {
          this.MarkdownTable(block)
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

  @Builder
  MarkdownCodeBlock(block: MarkdownBlock) {
    Column({ space: 9 }) {
      Row() {
        Text(this.codeLanguage(block))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_MAP_LINE)
          .borderRadius(Constants.RADIUS_SM)
        Text(this.codeLines(block).length.toString() + ' 行')
          .fontSize(11)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 8 }) {
        Column({ space: 0 }) {
          ForEach(this.codeLines(block), (_line: string, index: number): void => {
            Text((index + 1).toString())
              .width(30)
              .fontSize(11)
              .lineHeight(20)
              .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
              .textAlign(TextAlign.End)
          })
        }
        .padding({ right: 4 })
        .border({ width: 1, color: Constants.COLOR_MAP_LINE })
        .borderRadius(Constants.RADIUS_SM)

        Scroll() {
          Column({ space: 0 }) {
            ForEach(this.codeLines(block), (line: string): void => {
              Text(line.length > 0 ? line : ' ')
                .width(this.codeContentWidth(block))
                .fontSize(12)
                .lineHeight(20)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .fontFamily('monospace')
                .maxLines(1)
            })
          }
          .width(this.codeContentWidth(block))
        }
        .layoutWeight(1)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .constraintSize({ maxHeight: 260 })

      Row({ space: 8 }) {
        Button('解释这段')
          .height(32)
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_SM)
          .padding({ left: 10, right: 10 })
          .onClick((): void => { this.prefillCodeQuestion(block, 'explain'); })
        Button('预测输出')
          .height(32)
          .fontSize(11)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
          .padding({ left: 10, right: 10 })
          .onClick((): void => { this.prefillCodeQuestion(block, 'output'); })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(11)
    .backgroundColor(Constants.COLOR_MAP_SURFACE)
    .borderRadius(Constants.RADIUS_SM)
  }

  @Builder
  MarkdownTable(block: MarkdownBlock) {
    Scroll() {
      Column({ space: 0 }) {
        ForEach(this.tableRows(block), (row: string[], rowIndex: number): void => {
          Row() {
            ForEach(this.tableColumnIndexes(block), (cellIndex: number): void => {
              Text(this.tableCellText(row, cellIndex))
                .width(118)
                .constraintSize({ minHeight: 34 })
                .fontSize(11)
                .lineHeight(17)
                .fontWeight(rowIndex === 0 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(rowIndex === 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_TERTIARY)
                .padding({ left: 8, right: 8, top: 7, bottom: 7 })
                .backgroundColor(rowIndex === 0 ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD)
                .border({ width: 0.5, color: Constants.COLOR_BORDER })
            })
          }
          .width(this.tableWidth(block))
        })
      }
      .width(this.tableWidth(block))
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .backgroundColor(Constants.COLOR_SURFACE_TINT)
    .borderRadius(Constants.RADIUS_SM)
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
