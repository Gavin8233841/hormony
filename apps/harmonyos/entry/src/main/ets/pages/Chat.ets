/**
 * AI 辅导页
 * 学伴对话 · SSE 流式接收 · 学习行动
 */

import http from '@ohos.net.http';
import { HttpClient, HttpRequestCancellation, HttpStreamError } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { Citation, StreamEvent, ChatRequest, ChatMessage, ChatContext, ChatAction, Course,
  HealthResponse } from '../model/DataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ProactiveLearningAction, ProactiveLearningLaunch, ProactiveLearningService } from '../common/ProactiveLearningService';
import { InsightIntentPage } from '@kit.AbilityKit';
import { textToSpeech } from '@kit.CoreSpeechKit';

interface DisplayMessage {
  role: string;
  content: string;
  citations: Citation[];
  agentTrace: string[];
  thinking: string[];
  citationExpanded: boolean;
  streaming: boolean;
  failed: boolean;
  cancelled: boolean;
  statusMessage: string;
  httpStatus: number;
  errorCode: string;
  statusExpanded: boolean;
  retryQuestion: string;
  action: ChatAction | null;
}

interface MarkdownBlock {
  type: string;
  text: string;
  meta?: string;
}

@Component
export struct ChatContent {
  @StorageProp('darkMode') darkMode: boolean = false;
  @Prop quickQuestion: string = '';
  @Prop bottomInset: number = 0;
  @State messages: DisplayMessage[] = [];
  @State inputText: string = '';
  @State loading: boolean = false;
  @State probing: boolean = false;
  @State historyLoading: boolean = true;
  @State historySaving: boolean = false;
  @State historyMessage: string = '';
  @State historyLoadFailed: boolean = false;
  @State historySaveFailed: boolean = false;
  @StorageLink('cloudAgentReady') cloudAgentReady: boolean = false;
  @State serviceMessage: string = '正在连接云端学伴';
  @State contextSummary: string = '';
  @State contextQuestion: string = '';
  @State contextExpanded: boolean = false;
  @State actionMessage: string = '';
  @State actionOpening: boolean = false;
  @State welcomeOpacity: number = 0;
  @State welcomeOffset: number = 8;
  @State speechMessageIndex: number = -1;
  @State speechStarting: boolean = false;
  @State speechError: string = '';
  private activeChatContext: ChatContext | null = null;
  private scroller: Scroller = new Scroller();
  private inputController: TextInputController = new TextInputController();
  private currentRequest: http.HttpRequest | null = null;
  private currentCancellation: HttpRequestCancellation | null = null;
  private isCancelled: boolean = false;
  private receivedDone: boolean = false;
  private requestSequence: number = 0;
  private activeRequestId: number = 0;
  private scrollScheduled: boolean = false;
  private historySaveQueued: boolean = false;
  private lifecycleRunId: number = 0;
  private pageActive: boolean = false;
  private speechEngine: textToSpeech.TextToSpeechEngine | null = null;
  private speechRequestId: string = '';
  private speechSequence: number = 0;

  // 推荐问题
  private suggestions: string[] = [
    '什么是二叉搜索树？',
    'TCP 三次握手的过程',
    '动态规划的基本思想',
    '进程和线程的区别',
  ];

  aboutToAppear(): void {
    this.lifecycleRunId += 1;
    const lifecycleRunId = this.lifecycleRunId;
    this.pageActive = true;
    this.isCancelled = false;
    this.loading = false;
    this.currentRequest = null;
    this.currentCancellation = null;
    this.receivedDone = false;
    this.activeRequestId = 0;
    this.welcomeOpacity = 0;
    this.welcomeOffset = 8;
    setTimeout((): void => {
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, (): void => {
        this.welcomeOpacity = 1;
        this.welcomeOffset = 0;
      });
    }, 50);
    this.historyLoading = true;
    this.loadLocalHistory(lifecycleRunId);
    this.probeCloudAgent(lifecycleRunId);
    const pendingQuestion = AppStorage.get<string>('pendingChatQuestion') ?? '';
    this.inputText = this.quickQuestion.trim().length > 0 ? this.quickQuestion.trim() : pendingQuestion.trim();
    AppStorage.setOrCreate<string>('pendingChatQuestion', '');
    if (this.quickQuestion.trim().length === 0 && pendingQuestion.trim().length > 0) {
      this.loadPendingContext();
    } else {
      AppStorage.setOrCreate<string>('pendingChatContextJson', '');
      this.activeChatContext = null;
      this.contextSummary = '';
      this.contextQuestion = '';
    }
  }

  private loadPendingContext(): void {
    this.activeChatContext = null;
    this.contextSummary = '';
    this.contextQuestion = '';
    this.contextExpanded = false;
    const pending = AppStorage.get<string>('pendingChatContextJson') ?? '';
    AppStorage.setOrCreate<string>('pendingChatContextJson', '');
    if (pending.length === 0) return;
    try {
      const context: ChatContext = JSON.parse(pending);
      if (context.courseId === undefined || context.topic === undefined ||
        context.question === undefined || context.courseId.length === 0 ||
        context.topic.length === 0 || context.question.length === 0) return;
      this.activeChatContext = context;
      this.contextSummary = context.submitted === true ?
        '已提交作答 · ' + context.topic : '正在作答 · ' + context.topic;
      this.contextQuestion = context.question;
    } catch (_) {
      this.contextSummary = '题目上下文无法读取，请重新从题目进入';
    }
  }

  private validAction(action: ChatAction): boolean {
    return action !== null && typeof action.kind === 'string' &&
      typeof action.courseId === 'string' && typeof action.topic === 'string' &&
      typeof action.title === 'string' && typeof action.reason === 'string' &&
      (action.kind === 'lesson' || action.kind === 'practice' ||
      action.kind === 'quiz' || action.kind === 'review') &&
      action.courseId.length > 0 && action.courseId.length <= 128 &&
      action.topic.length > 0 && action.topic.length <= 128 &&
      action.title.length > 0 && action.title.length <= 120 &&
      action.reason.length > 0 && action.reason.length <= 200;
  }

  private actionTarget(kind: string): string {
    if (kind === 'lesson') return 'pages/Lesson';
    if (kind === 'quiz') return 'pages/Quiz';
    return 'pages/Practice';
  }

  private actionButtonLabel(kind: string): string {
    if (kind === 'lesson') return '看课程';
    if (kind === 'quiz') return '开始测验';
    if (kind === 'review') return '复习错题';
    return '去练习';
  }

  private continueTutoring(kind: string): void {
    if (this.loading || !this.cloudAgentReady || this.historyLoading || this.historySaving || this.historyLoadFailed) return;
    if (kind === 'hint') {
      this.sendMessage('再提示我一下？');
    } else {
      this.sendMessage('能换个例子吗？');
    }
  }

  private async openAction(action: ChatAction): Promise<void> {
    if (this.actionOpening || this.loading || !this.validAction(action)) return;
    this.actionOpening = true;
    this.actionMessage = '';
    try {
      const courses: Course[] = await LocalLearningRepository.getCourses() ?? [];
      const targetPage = this.actionTarget(action.kind);
      const launch: ProactiveLearningLaunch | undefined = ProactiveLearningService.validateChatAction(
        courses, targetPage, action.courseId, action.topic, action.kind);
      if (launch === undefined) {
        this.actionMessage = '当前课程或主题已变化，请重新提问';
        return;
      }
      const selection: ProactiveLearningAction = {
        kind: action.kind, badge: '学伴建议', title: action.title,
        subtitle: launch.courseTitle + ' · ' + launch.topic,
        cta: action.title, courseId: launch.courseId, courseTitle: launch.courseTitle,
        topic: launch.topic, focusTag: '', taskAction: action.kind, targetPage: targetPage,
        evidence: '本次回答建议', progressText: ''
      };
      ProactiveLearningService.applySelection(selection);
      await this.getUIContext().getRouter().pushUrl({ url: targetPage });
    } catch (_) {
      this.actionMessage = '暂时打不开，请重试';
    } finally {
      this.actionOpening = false;
    }
  }

  aboutToDisappear(): void {
    this.pageActive = false;
    this.lifecycleRunId += 1;
    this.cancelCurrentRequest(false);
    this.stopSpeech();
    this.speechEngine?.shutdown();
    this.speechEngine = null;
  }

  private stopSpeech(): void {
    this.speechSequence += 1;
    this.speechStarting = false;
    this.speechRequestId = '';
    this.speechMessageIndex = -1;
    try {
      this.speechEngine?.stop();
    } catch (_) {
      // A stopped or unavailable engine must not interrupt the chat page.
    }
  }

  private finishSpeech(): void {
    this.speechStarting = false;
    this.speechRequestId = '';
    this.speechMessageIndex = -1;
  }

  private async readAnswer(message: DisplayMessage): Promise<void> {
    const messageIndex = this.messages.indexOf(message);
    if (messageIndex < 0 || message.streaming || message.failed || message.cancelled) return;
    if (this.speechMessageIndex === messageIndex) {
      this.stopSpeech();
      return;
    }
    const spokenText = this.readableMarkdown(message.content).trim();
    if (spokenText.length === 0) return;
    if (spokenText.length > 10000) {
      this.speechError = '这段回答太长，暂时无法朗读';
      return;
    }
    this.stopSpeech();
    this.speechError = '';
    this.speechStarting = true;
    const sequence = this.speechSequence;
    try {
      let engine = this.speechEngine;
      if (engine === null) {
        engine = await textToSpeech.createEngine({ language: 'zh-CN', person: 0, online: 1 });
        if (!this.pageActive || sequence !== this.speechSequence) {
          engine.shutdown();
          return;
        }
        this.speechEngine = engine;
      }
      engine.setListener({
        onStart: (requestId: string): void => {
          console.info('HongxuebanTTS onStart');
          if (requestId === this.speechRequestId) this.speechStarting = false;
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
          console.info('HongxuebanTTS onComplete ' + response.type.toString());
          if (requestId === this.speechRequestId && response.type === 1) this.finishSpeech();
        },
        onStop: (requestId: string): void => {
          console.info('HongxuebanTTS onStop');
          if (requestId === this.speechRequestId) this.finishSpeech();
        },
        onError: (requestId: string, errorCode: number): void => {
          console.error('HongxuebanTTS onError ' + errorCode.toString());
          if (requestId !== this.speechRequestId) return;
          this.stopSpeech();
          this.speechError = '朗读暂时不可用，请稍后重试';
        }
      });
      this.speechRequestId = 'answer' + Date.now().toString() + sequence.toString();
      this.speechMessageIndex = messageIndex;
      console.info('HongxuebanTTS speak');
      engine.speak(spokenText, { requestId: this.speechRequestId, extraParams: { 'playType': 1 } });
    } catch (_) {
      console.error('HongxuebanTTS unavailable');
      if (sequence !== this.speechSequence) return;
      this.stopSpeech();
      this.speechError = '朗读暂时不可用，请稍后重试';
    }
  }

  private isActiveLifecycle(lifecycleRunId: number): boolean {
    return this.pageActive && this.lifecycleRunId === lifecycleRunId;
  }

  private canSend(): boolean {
    return this.cloudAgentReady && !this.loading && !this.historyLoading && !this.historySaving &&
      !this.historyLoadFailed && this.inputText.trim().length > 0;
  }

  private canRetryCloudAgent(): boolean {
    return !this.probing && !this.cloudAgentReady;
  }

  private sendButtonBackground(): string {
    if (this.loading) return Constants.COLOR_ERROR_LIGHT;
    if (this.canSend()) return Constants.COLOR_BRAND;
    if (this.canRetryCloudAgent()) return Constants.COLOR_WARNING;
    return Constants.COLOR_BRAND_LIGHT;
  }

  private sendButtonIconColor(): string {
    if (this.loading) return Constants.COLOR_ERROR;
    if (this.canSend() || this.canRetryCloudAgent()) return Constants.COLOR_TEXT_ON_GRADIENT;
    return Constants.COLOR_BRAND;
  }

  private sendButtonAccessibilityText(): string {
    if (this.loading) return '停止回答';
    if (this.canSend()) return '发送问题';
    if (this.canRetryCloudAgent()) return '重新连接云端学伴';
    if (this.probing) return '正在连接云端学伴';
    return '发送问题不可用';
  }

  private sendButtonHint(): string {
    if (this.loading) return '正在回答，可随时停止';
    if (this.historyLoading) return '正在加载对话';
    if (this.historySaving) return '正在保存对话';
    if (this.historyLoadFailed || this.historySaveFailed) return this.historyMessage;
    return '';
  }

  private sendButtonHintColor(): string {
    if (this.historyLoadFailed || this.historySaveFailed) return Constants.COLOR_ERROR;
    if (this.canRetryCloudAgent()) return Constants.COLOR_WARNING;
    return Constants.COLOR_TEXT_SECONDARY;
  }

  private markdownBlocks(content: string): MarkdownBlock[] {
    const blocks: MarkdownBlock[] = [];
    const codeLines: string[] = [];
    const tableRows: string[] = [];
    let codeLanguage = '';
    let inCode = false;
    for (const rawLine of content.split('\n')) {
      const line = rawLine.trimEnd();
      const trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        this.pushTableBlock(blocks, tableRows);
        if (inCode) {
          blocks.push({ type: 'code', text: codeLines.join('\n'), meta: codeLanguage });
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
        this.pushTableBlock(blocks, tableRows);
        continue;
      }
      const headingText = this.headingText(trimmed);
      if (headingText.length > 0) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'heading', text: headingText });
      } else if (trimmed.startsWith('>')) {
        this.pushTableBlock(blocks, tableRows);
        const quote = this.cleanInline(trimmed.slice(1));
        if (quote.length > 0) {
          blocks.push({ type: 'quote', text: quote });
        }
      } else if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('* [ ] ')) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'task', text: this.cleanInline(trimmed.slice(6)), meta: 'open' });
      } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ') ||
        trimmed.startsWith('* [x] ') || trimmed.startsWith('* [X] ')) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'task', text: this.cleanInline(trimmed.slice(6)), meta: 'done' });
      } else if (this.bulletText(trimmed).length > 0) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'bullet', text: this.bulletText(trimmed) });
      } else if (this.numberedText(trimmed).length > 0) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'numbered', text: this.numberedText(trimmed) });
      } else if (this.looksLikeTableLine(trimmed)) {
        const tableText = this.tableText(trimmed);
        if (tableText.length > 0) {
          this.appendTableRow(tableRows, tableText, trimmed);
        }
      } else if (this.isDivider(trimmed)) {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'divider', text: '' });
      } else {
        this.pushTableBlock(blocks, tableRows);
        blocks.push({ type: 'paragraph', text: this.cleanInline(line) });
      }
    }
    this.pushTableBlock(blocks, tableRows);
    if (codeLines.length > 0) {
      blocks.push({ type: 'code', text: codeLines.join('\n'), meta: codeLanguage });
    }
    if (blocks.length === 0 && content.length > 0) {
      blocks.push({ type: 'paragraph', text: content });
    }
    return blocks;
  }

  private readableMarkdown(content: string): string {
    const lines: string[] = [];
    const tableRows: string[] = [];
    let inCode = false;
    for (const rawLine of content.split('\n')) {
      const line = rawLine.trimEnd();
      const trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        this.pushReadableTable(lines, tableRows);
        lines.push(line);
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        lines.push(line);
        continue;
      }
      if (this.looksLikeTableLine(trimmed)) {
        const tableText = this.tableText(trimmed);
        if (tableText.length > 0) {
          this.appendTableRow(tableRows, tableText, trimmed);
        }
        continue;
      }
      this.pushReadableTable(lines, tableRows);
      if (this.isDivider(trimmed)) {
        if (lines.length > 0 && lines[lines.length - 1].trim().length > 0) {
          lines.push('');
        }
        continue;
      }
      lines.push(this.cleanInline(line));
    }
    this.pushReadableTable(lines, tableRows);
    return lines.join('\n');
  }

  private pushReadableTable(lines: string[], tableRows: string[]): void {
    if (tableRows.length === 0) return;
    const header = this.tableCells(tableRows[0]);
    if (header.length > 1 && tableRows.length > 1) {
      lines.push('表格整理');
      for (let rowIndex = 1; rowIndex < tableRows.length; rowIndex++) {
        const cells = this.tableCells(tableRows[rowIndex]);
        if (cells.length === header.length && cells.length > 1) {
          lines.push('- ' + cells[0]);
          for (let cellIndex = 1; cellIndex < cells.length; cellIndex++) {
            lines.push('- ' + header[cellIndex] + '：' + cells[cellIndex]);
          }
        } else if (cells.length > 0) {
          lines.push('- ' + cells.join(' / '));
        }
      }
    } else {
      for (const row of tableRows) {
        const cells = this.tableCells(row);
        if (cells.length > 0) {
          lines.push('- ' + cells.join(' / '));
        }
      }
    }
    tableRows.splice(0, tableRows.length);
  }

  private pushTableBlock(blocks: MarkdownBlock[], tableRows: string[]): void {
    if (tableRows.length === 0) return;
    blocks.push({ type: 'table', text: tableRows.join('\n') });
    tableRows.splice(0, tableRows.length);
  }

  private headingText(line: string): string {
    let level = 0;
    while (level < line.length && line.charAt(level) === '#') {
      level += 1;
    }
    if (level > 0 && level <= 6 && line.length > level) {
      const next = line.charAt(level);
      if (next === ' ') return this.cleanInline(line.slice(level + 1));
      return this.cleanInline(line.slice(level));
    }
    return '';
  }

  private bulletText(line: string): string {
    if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ')) {
      return this.cleanInline(line.slice(2));
    }
    if (line.startsWith('• ')) {
      return this.cleanInline(line.slice(2));
    }
    return '';
  }

  private numberedText(line: string): string {
    const dotIndex = line.indexOf('. ');
    const cnIndex = line.indexOf('、');
    const halfParenIndex = line.indexOf(') ');
    const fullParenIndex = line.indexOf('）');
    let splitIndex = dotIndex;
    let offset = 2;
    if (splitIndex < 0 || (cnIndex > 0 && cnIndex < splitIndex)) {
      splitIndex = cnIndex;
      offset = 1;
    }
    if (splitIndex < 0 || (halfParenIndex > 0 && halfParenIndex < splitIndex)) {
      splitIndex = halfParenIndex;
      offset = 2;
    }
    if (splitIndex < 0 || (fullParenIndex > 0 && fullParenIndex < splitIndex)) {
      splitIndex = fullParenIndex;
      offset = 1;
    }
    if (splitIndex <= 0) return '';
    let prefix = line.slice(0, splitIndex);
    if (prefix.startsWith('(') || prefix.startsWith('（')) {
      prefix = prefix.slice(1);
    }
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

  private looksLikeTableLine(line: string): boolean {
    if (this.isTableRow(line)) return true;
    if (!line.startsWith('|')) return false;
    const text = line.replace(/\|/g, '').trim();
    if (text.length === 0) return true;
    let divider = true;
    for (const ch of text) {
      if (ch !== '-' && ch !== ':' && ch !== ' ') divider = false;
    }
    return divider || text.length > 0;
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
    return cells.join('|');
  }

  private appendTableRow(tableRows: string[], tableText: string, rawLine: string): void {
    const cells = this.tableCells(tableText);
    if (cells.length === 0) return;
    if (tableRows.length > 0 && rawLine.startsWith('|') && cells.length === 1) {
      const lastIndex = tableRows.length - 1;
      const lastCells = this.tableCells(tableRows[lastIndex]);
      if (lastCells.length > 0 && lastCells.length < 3) {
        tableRows[lastIndex] = tableRows[lastIndex] + '|' + cells[0];
        return;
      }
    }
    tableRows.push(tableText);
  }

  private cleanInline(text: string): string {
    return text
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1（$2）')
      .replace(/`([^`]+)`/g, '「$1」')
      .replace(/<br\s*\/?\s*>/g, '；')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/\*\*([^*]+)\*\*/g, '$1')
      .replace(/__([^_]+)__/g, '$1')
      .replace(/\*\*/g, '')
      .replace(/__/g, '')
      .replace(/\*/g, '')
      .replace(/`/g, '')
      .trim();
  }

  private codeLanguage(block: MarkdownBlock): string {
    const language = block.meta ?? '';
    return language.length > 0 ? language : '代码片段';
  }

  private codeFenceLanguage(block: MarkdownBlock): string {
    const language = block.meta ?? '';
    return language.length > 0 ? language : 'text';
  }

  private codeLines(block: MarkdownBlock): string[] {
    const lines = block.text.split('\n');
    return lines.length > 0 ? lines : [''];
  }

  private codeLineNumber(index: number): string {
    const value = (index + 1).toString();
    return value.length === 1 ? '0' + value : value;
  }

  private tableRows(block: MarkdownBlock): string[] {
    const rows: string[] = [];
    for (const row of block.text.split('\n')) {
      if (row.trim().length > 0) rows.push(row);
    }
    return rows;
  }

  private tableCells(row: string): string[] {
    const cells: string[] = [];
    for (const cell of row.split('|')) {
      const cleaned = cell.trim();
      if (cleaned.length > 0) cells.push(cleaned);
    }
    return cells;
  }

  private boundedCodeText(block: MarkdownBlock): string {
    const text = block.text.trim();
    if (text.length <= 1600) return text;
    return text.slice(0, 1600) + '\n...';
  }

  private explainCodeBlock(block: MarkdownBlock): void {
    const language = this.codeFenceLanguage(block);
    this.inputText = '请逐行解释这段 ' + language + ' 代码，说明关键变量、执行顺序，并给一个现实类比帮助记忆：\n\n```' +
      language + '\n' + this.boundedCodeText(block) + '\n```';
    if (!this.cloudAgentReady && !this.probing) {
      this.probeCloudAgent();
    }
    this.scrollToBottom();
  }

  private taskDone(block: MarkdownBlock): boolean {
    return block.meta === 'done';
  }

  private async loadLocalHistory(lifecycleRunId: number): Promise<void> {
    try {
      const history = await LocalLearningRepository.getChatHistory();
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      const restored: DisplayMessage[] = [];
      for (const item of history) {
        const message: DisplayMessage = {
          role: item.role,
          content: item.content,
          citations: item.citations ?? [],
          agentTrace: item.agentTrace ?? [],
          thinking: item.thinking ?? [],
          citationExpanded: false,
          streaming: false,
          failed: false,
          cancelled: false,
          statusMessage: '',
          httpStatus: 0,
          errorCode: '',
          statusExpanded: false,
          retryQuestion: '',
          action: item.action && this.validAction(item.action) ? item.action : null
        };
        restored.push(message);
      }
      this.messages = restored;
      this.historyLoadFailed = false;
      this.historySaveFailed = false;
      this.historyMessage = restored.length > 0 ?
        '已恢复 ' + restored.length.toString() + ' 条对话' : '';
    } catch (error) {
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      this.historyLoadFailed = true;
      this.historyMessage = '对话暂时无法打开';
    } finally {
      if (this.isActiveLifecycle(lifecycleRunId)) {
        this.historyLoading = false;
        if (this.messages.length > 0) this.scrollToBottom();
      }
    }
  }

  private retryLocalHistoryLoad(): void {
    if (this.historyLoading || this.historySaving || this.loading) return;
    this.historyLoading = true;
    this.historyLoadFailed = false;
    this.historyMessage = '正在打开对话';
    this.loadLocalHistory(this.lifecycleRunId);
  }

  private cancelCurrentRequest(showStatus: boolean): void {
    this.isCancelled = true;
    this.activeRequestId = 0;
    const request = this.currentRequest;
    const cancellation = this.currentCancellation;
    this.currentRequest = null;
    this.currentCancellation = null;
    if (request !== null) {
      try {
        request.off('dataReceive');
        request.off('dataEnd');
      } catch (_) {
      }
    }
    if (cancellation !== null) {
      cancellation.cancel();
    } else if (request !== null) {
      try {
        request.destroy();
      } catch (_) {
      }
    }
    this.loading = false;
    this.receivedDone = false;
    if (!showStatus || this.messages.length === 0) return;
    const last = this.messages[this.messages.length - 1];
    if (last.role !== 'assistant' || !last.streaming) return;
    last.streaming = false;
    last.failed = false;
    last.cancelled = true;
    last.httpStatus = 0;
    last.errorCode = '';
    last.statusExpanded = false;
    last.statusMessage = last.content.length > 0 ?
      '已停止回答，这段内容未保存' : '已停止回答，可以重新提问';
    this.inputText = last.retryQuestion;
    this.messages = this.messages.slice();
  }

  private retryMessage(msg: DisplayMessage): void {
    const question = msg.retryQuestion.trim();
    if (question.length === 0 || this.loading || this.historyLoading || this.historySaving ||
      this.historyLoadFailed) return;
    if (!this.cloudAgentReady) {
      this.inputText = question;
      if (!this.probing) this.probeCloudAgent();
      return;
    }
    const targetIndex = this.messages.indexOf(msg);
    if (targetIndex < 0) return;
    const next: DisplayMessage[] = [];
    for (let index = 0; index < this.messages.length; index++) {
      const item = this.messages[index];
      const pairedUser = index === targetIndex - 1 && item.role === 'user' && item.content === question;
      if (index !== targetIndex && !pairedUser) next.push(item);
    }
    this.messages = next;
    this.sendMessage(question);
  }

  private async probeCloudAgent(lifecycleRunId: number = this.lifecycleRunId): Promise<void> {
    if (!this.isActiveLifecycle(lifecycleRunId)) return;
    this.probing = true;
    this.serviceMessage = '正在连接云端学伴';
    try {
      const health = await HttpClient.get<HealthResponse>(Constants.API_HEALTH);
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      this.cloudAgentReady = health.status === 'ready';
      this.serviceMessage = this.cloudAgentReady ? '' : '云端学伴尚未就绪';
    } catch (error) {
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      this.cloudAgentReady = false;
      this.serviceMessage = '云端学伴暂不可用';
    } finally {
      if (this.isActiveLifecycle(lifecycleRunId)) {
        this.probing = false;
      }
    }
  }

  private scrollToBottom(): void {
    if (this.scrollScheduled) {
      return;
    }
    this.scrollScheduled = true;
    const lifecycleRunId = this.lifecycleRunId;
    setTimeout(() => {
      this.scrollScheduled = false;
      if (this.isActiveLifecycle(lifecycleRunId) && this.messages.length > 0) {
        this.scroller.scrollToIndex(this.messages.length - 1, true, ScrollAlign.END);
      }
    }, 50);
  }

  build() {
    Column() {
      Row({ space: 9 }) {
        Image($r('app.media.mascot_xiaohong_avatar'))
          .width(34)
          .height(34)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(13)
        Text('学伴')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      .height(50)
      .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER })

      if (this.contextSummary.length > 0) {
        Column({ space: 2 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.book_open_fill'))
              .fontSize(16)
              .fontColor([Constants.COLOR_BRAND])
            Text(this.contextSummary)
              .layoutWeight(1)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_BRAND_TEXT)
            SymbolGlyph($r(this.contextExpanded ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
              .fontSize(14)
              .fontColor([Constants.COLOR_TEXT_SECONDARY])
          }
          .width('100%')
          .constraintSize({ minHeight: 44 })
          .onClick((): void => { this.contextExpanded = !this.contextExpanded; })

          if (this.contextExpanded && this.contextQuestion.length > 0) {
            Text(this.contextQuestion)
              .width('100%')
              .fontSize(13)
              .maxLines(8)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          }
          if (this.contextExpanded) {
            Button('移除题目')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .backgroundColor(Constants.COLOR_BG_TAG)
              .constraintSize({ minHeight: 48 })
              .onClick((): void => {
                this.activeChatContext = null;
                this.contextSummary = '';
                this.contextQuestion = '';
                this.contextExpanded = false;
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 1, bottom: 1 })
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
        .margin({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER, bottom: 8 })
      }

      // 消息列表 / 欢迎页
      if (this.messages.length === 0) {
        // 欢迎引导：角色只在空状态完整出现，不挤占回答区域。
        Scroll() {
          Column() {
            Row() {
              Column({ space: 8 }) {
                Text('小鸿在这儿')
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_MAP_CORE)
                Text('课程、错题，都可以问。')
                  .fontSize(13)
                  .lineHeight(19)
                  .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Image($r('app.media.mascot_xiaohong_welcome'))
                .width(112)
                .height(142)
                .objectFit(ImageFit.Contain)
                .accessibilityText('小鸿挥手欢迎')
            }
            .width('100%')
            .height(176)
            .padding({ left: 20, right: 8, top: 12, bottom: 8 })
            .backgroundColor(Constants.COLOR_HERO_SURFACE)
            .borderRadius(Constants.RADIUS_XL)
            .opacity(this.welcomeOpacity)
            .translate({ y: this.welcomeOffset })

            Text('试试这样问')
              .width('100%')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .margin({ top: 24, bottom: 12 })

            Column({ space: 8 }) {
              ForEach(this.suggestions, (s: string, index: number) => {
                Button({ type: ButtonType.Normal }) {
                  Row() {
                    Text(s)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(13)
                      .fontColor([Constants.COLOR_TEXT_SECONDARY])
                  }
                  .width('100%')
                }
                  .width('100%')
                  .constraintSize({ minHeight: 56 })
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(index === 0 ? Constants.COLOR_BRAND_LIGHT :
                    (index === 1 ? Constants.COLOR_COURSE_OS_LIGHT : Constants.COLOR_HERO_INSET))
                  .borderRadius(Constants.RADIUS_LG)
                  .enabled(this.cloudAgentReady && !this.loading && !this.historyLoading && !this.historySaving &&
                    !this.historyLoadFailed)
                  .accessibilityText('提问：' + s)
                  .accessibilityDescription('使用该问题向云端学伴提问')
                  .onClick(() => {
                    this.inputText = s;
                    this.sendMessage();
                  })
              })
            }
            .width('100%')
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER, top: 20, bottom: 20 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .constraintSize({ maxWidth: 760 })
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
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER })
        .constraintSize({ maxWidth: 760 })
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
              .constraintSize({ minHeight: 48 })
              .padding({ left: 14, right: 14 })
              .accessibilityText('重新连接云端学伴')
              .onClick((): void => { this.probeCloudAgent(); })
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 8 })
        .constraintSize({ maxWidth: 760 })
      }
      Column({ space: 6 }) {
        Row({ space: 4 }) {
          TextInput({
            text: $$this.inputText,
            controller: this.inputController,
            placeholder: this.cloudAgentReady ? '输入你的问题...' : '云端学伴连接后可提问'
          })
            .layoutWeight(1)
            .constraintSize({ minHeight: 48 })
            .fontSize(15)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.cloudAgentReady && !this.loading && !this.historyLoading && !this.historyLoadFailed)
            .accessibilityText('输入学习问题')
            .accessibilityDescription('输入后可通过右侧按钮发送给云端学伴')
            .maxLength(2000)
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => {
              this.inputText = value;
              if (!this.historyLoadFailed && !this.historySaveFailed) this.historyMessage = '';
            })
            .onSubmit((_enterKey: EnterKeyType, event: SubmitEvent): void => {
              this.inputText = event.text;
              this.sendMessage(event.text);
            })

          Button() {
            if (this.loading) {
              SymbolGlyph($r('sys.symbol.stop_circle_fill'))
                .fontSize(20)
                .fontColor([this.sendButtonIconColor()])
            } else if (this.probing) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color(Constants.COLOR_BRAND)
            } else {
              SymbolGlyph($r('sys.symbol.paperplane_right_fill'))
                .fontSize(20)
                .fontColor([this.sendButtonIconColor()])
            }
          }
            .width(48)
            .height(48)
            .backgroundColor(this.sendButtonBackground())
            .border({
              width: 1,
              color: this.loading ? Constants.COLOR_ERROR :
                (this.canSend() ? Constants.COLOR_BRAND : Constants.COLOR_BRAND_LIGHT)
            })
            .borderRadius(24)
            .accessibilityText(this.sendButtonAccessibilityText())
            .accessibilityDescription(this.sendButtonHint())
            .onClick(() => {
              if (this.loading) {
                this.cancelCurrentRequest(true);
              } else if (this.canSend()) {
                this.sendMessage();
              } else if (this.canRetryCloudAgent()) {
                this.probeCloudAgent();
              }
            })
        }
        .width('100%')
        .padding({ left: 3, right: 3, top: 3, bottom: 3 })
        .backgroundColor(Constants.COLOR_BG_CARD)
        .border({ width: 1, color: Constants.COLOR_BORDER })
        .borderRadius(Constants.RADIUS_LG)

        if (this.sendButtonHint().length > 0 || this.historyLoadFailed || this.historySaveFailed) {
          Row({ space: 8 }) {
            Text(this.sendButtonHint())
              .layoutWeight(1)
              .fontSize(11)
              .lineHeight(18)
              .fontColor(this.sendButtonHintColor())
            if (this.historyLoadFailed || this.historySaveFailed) {
              Button(this.historyLoadFailed ? '重新读取' : (this.historySaving ? '保存中' : '重试保存'))
                .constraintSize({ minHeight: 48 })
                .fontSize(11)
                .fontColor(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
                .padding({ left: 12, right: 12 })
                .enabled(!this.loading && !this.historySaving && !this.historyLoading)
                .accessibilityText(this.historyLoadFailed ? '重新打开对话' : '重试保存对话')
                .onClick((): void => {
                  if (this.historyLoadFailed) this.retryLocalHistoryLoad();
                  else this.retryLocalHistorySave();
                })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 24 })
        }
      }
      .width('100%')
      .padding({ left: Constants.PAGE_GUTTER, right: Constants.PAGE_GUTTER, bottom: 7, top: 5 })
      .constraintSize({ maxWidth: 760 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
    .padding({ bottom: this.bottomInset })
  }

  private localDateKey(date: Date = new Date()): string {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  sendMessage(question?: string): void {
    const content = question !== undefined ? question.trim() : this.inputText.trim();
    if (content.length === 0 || this.loading || this.historyLoading || this.historySaving ||
      this.historyLoadFailed || !this.cloudAgentReady) {
      return;
    }
    this.stopSpeech();
    this.speechError = '';
    this.inputController.stopEditing();
    this.historyMessage = '';

    const userMsg: DisplayMessage = {
      role: 'user',
      content: content,
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
      streaming: false,
      failed: false,
      cancelled: false,
      statusMessage: '',
      httpStatus: 0,
      errorCode: '',
      statusExpanded: false,
      retryQuestion: '',
      action: null,
    };
    this.messages.push(userMsg);

    const assistantMsg: DisplayMessage = {
      role: 'assistant',
      content: '',
      citations: [],
      agentTrace: [],
      thinking: [],
      citationExpanded: false,
      streaming: true,
      failed: false,
      cancelled: false,
      statusMessage: '',
      httpStatus: 0,
      errorCode: '',
      statusExpanded: false,
      retryQuestion: content,
      action: null,
    };
    this.messages.push(assistantMsg);

    const message = content;
    this.inputText = '';
    this.loading = true;
    this.isCancelled = false;
    this.receivedDone = false;
    this.requestSequence += 1;
    const requestId = this.requestSequence;
    const cancellation = new HttpRequestCancellation();
    this.activeRequestId = requestId;
    this.currentCancellation = cancellation;
    this.scrollToBottom();

    const requestHistory = this.completeChatHistory(this.messages.slice(0, this.messages.length - 2), false)
      .slice(-12)
      .map((item: ChatMessage): ChatMessage => {
        return {
          role: item.role,
          content: item.content.slice(0, 1000),
          citations: item.citations
        };
      });
    const req: ChatRequest = {
      userId: Constants.DEMO_USER_ID,
      message: message,
      startDate: this.localDateKey(),
      history: requestHistory,
      context: {
        courseId: this.activeChatContext?.courseId ?? AppStorage.get<string>('selectedCourseId') ?? 'cs101',
        topic: this.activeChatContext?.topic,
        question: this.activeChatContext?.question,
        userAnswer: this.activeChatContext?.userAnswer,
        correctAnswer: this.activeChatContext?.correctAnswer,
        submitted: this.activeChatContext?.submitted
      }
    };
    LocalLearningRepository.getProfile().then((profile): void => {
      if (profile !== null) req.profile = profile;
      this.startSseRequest(req, requestId, cancellation);
    }).catch((): void => {
      this.startSseRequest(req, requestId, cancellation);
    });
  }

  private isActiveRequest(requestId: number): boolean {
    return requestId === this.activeRequestId && !this.isCancelled;
  }

  private startSseRequest(req: ChatRequest, requestId: number, cancellation: HttpRequestCancellation): void {
    if (!this.isActiveRequest(requestId) || !this.loading) return;
    HttpClient.postSSE(Constants.API_CHAT, JSON.stringify(req),
      (evt: StreamEvent) => {
        if (!this.isActiveRequest(requestId)) {
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
        } else if (evt.type === 'action' && evt.action && this.validAction(evt.action)) {
          last.action = evt.action;
        } else if (evt.type === 'error') {
          last.streaming = false;
          last.failed = true;
          last.cancelled = false;
          last.statusMessage = this.streamFailureMessage(evt.code ?? '', evt.message ?? '');
          last.httpStatus = 0;
          last.errorCode = evt.code ?? '';
          last.statusExpanded = false;
          if (evt.code === 'MODEL_UNAVAILABLE') {
            this.cloudAgentReady = false;
          }
          this.serviceMessage = last.statusMessage;
        } else if (evt.type === 'done') {
          this.receivedDone = true;
          if (!last.failed && !last.cancelled) {
            last.streaming = false;
          }
        }

        this.messages = this.messages.slice();
        this.scrollToBottom();
      },
      () => {
        if (!this.isActiveRequest(requestId)) {
          return;
        }
        this.loading = false;
        this.currentRequest = null;
        this.currentCancellation = null;
        this.activeRequestId = 0;
        const last = this.messages[this.messages.length - 1];
        last.streaming = false;
        if (last.failed || last.cancelled) {
          this.messages = this.messages.slice();
          return;
        }
        if (!this.receivedDone) {
          last.failed = true;
          last.statusMessage = '连接中断，这次回答未完成，请重试';
          this.messages = this.messages.slice();
          return;
        }
        if (last.content.length === 0) {
          last.failed = true;
          last.statusMessage = '这次没有收到可显示的回答，请重试';
          this.messages = this.messages.slice();
          return;
        }
        this.messages = this.messages.slice();
        this.saveLocalHistory();
      },
      (err: HttpStreamError) => {
        if (!this.isActiveRequest(requestId)) {
          return;
        }
        const last = this.messages[this.messages.length - 1];
        last.streaming = false;
        last.failed = true;
        last.cancelled = false;
        last.statusMessage = this.requestFailureMessage(err);
        last.httpStatus = err.statusCode;
        last.errorCode = err.errorCode;
        last.statusExpanded = false;
        this.serviceMessage = last.statusMessage;
        const requestRejected = err.statusCode >= 400 && err.statusCode < 500;
        if (!requestRejected) {
          this.cloudAgentReady = false;
        }
        this.loading = false;
        this.currentRequest = null;
        this.currentCancellation = null;
        this.activeRequestId = 0;
        this.messages = this.messages.slice();
      },
      (reqInstance: http.HttpRequest) => {
        if (!this.isActiveRequest(requestId)) {
          try {
            reqInstance.destroy();
          } catch (_) {
          }
          return;
        }
        this.currentRequest = reqInstance;
      },
      cancellation
    );
  }

  private streamFailureMessage(code: string, fallback: string): string {
    if (code === 'MODEL_UNAVAILABLE') return '在线学伴暂时无法回答，请稍后重试';
    if (code === 'MODEL_TIMEOUT') return '等待回答超时，请稍后重试';
    if (code === 'MODEL_INVALID_RESPONSE') return '这次回答无法正常显示，请重新提问';
    if (code === 'KNOWLEDGE_UNAVAILABLE') return '当前主题还没有足够课程资料，请换个问题重试';
    if (code === 'SAFETY_BLOCKED') return '这次回答未通过安全检查，请调整问题后重试';
    const message = fallback.trim();
    return message.length > 0 ? message : '云端未能完成这次回答，请稍后重试';
  }

  private requestFailureMessage(error: HttpStreamError): string {
    if (error.statusCode === 0) return '网络连接中断，请检查网络后重试';
    if (error.errorCode === 'INPUT_REJECTED') return '问题内容未通过安全检查，请调整后重试';
    if (error.errorCode === 'MESSAGE_TOO_LONG') return '问题太长，请精简后重新发送';
    const streamMessage = this.streamFailureMessage(error.errorCode, '');
    if (streamMessage !== '云端未能完成这次回答，请稍后重试') return streamMessage;
    if (error.statusCode === 429) return '提问太频繁，请稍后再试';
    if (error.statusCode >= 400 && error.statusCode < 500) return '问题或学习上下文不符合要求，请调整后重试';
    return '在线学伴暂时无法回答，请稍后重试';
  }

  private completeChatHistory(source: DisplayMessage[], includeLocalEvidence: boolean): ChatMessage[] {
    const history: ChatMessage[] = [];
    for (let index: number = 0; index + 1 < source.length; index += 1) {
      const userMessage = source[index];
      const assistantMessage = source[index + 1];
      const completeTurn = userMessage.role === 'user' && userMessage.content.length > 0 &&
        assistantMessage.role === 'assistant' && assistantMessage.content.length > 0 &&
        !assistantMessage.failed && !assistantMessage.cancelled && !assistantMessage.streaming;
      if (!completeTurn) continue;
      history.push({
        role: userMessage.role,
        content: userMessage.content,
        citations: userMessage.citations,
        agentTrace: includeLocalEvidence ? userMessage.agentTrace : undefined,
        thinking: includeLocalEvidence ? userMessage.thinking : undefined
      });
      history.push({
        role: assistantMessage.role,
        content: assistantMessage.content,
        citations: assistantMessage.citations,
        agentTrace: includeLocalEvidence ? assistantMessage.agentTrace : undefined,
        thinking: includeLocalEvidence ? assistantMessage.thinking : undefined,
        action: assistantMessage.action ?? undefined
      });
      index += 1;
    }
    return history.slice(-24);
  }

  private async saveLocalHistory(): Promise<void> {
    if (this.historySaving) {
      this.historySaveQueued = true;
      return;
    }
    const history = this.completeChatHistory(this.messages, true);
    this.historySaving = true;
    try {
      await LocalLearningRepository.saveChatHistory(history);
      this.historySaveFailed = false;
      this.historyMessage = '回答已保存';
    } catch (_) {
      this.historySaveFailed = true;
      this.historyMessage = '回答已完成，保存失败';
    } finally {
      this.historySaving = false;
      if (this.historySaveQueued) {
        this.historySaveQueued = false;
        this.saveLocalHistory();
      }
    }
  }

  private retryLocalHistorySave(): void {
    if (this.loading || this.historyLoading || this.historySaving || this.historyLoadFailed) return;
    this.saveLocalHistory();
  }

  @Builder
  MessageBubble(msg: DisplayMessage) {
    Column() {
      if (msg.role === 'user') {
        // 用户消息右对齐
        Row() {
          Column() {
            Text(msg.content)
              .fontSize(Constants.PAGE_BODY_SIZE)
              .lineHeight(23)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .backgroundColor(Constants.COLOR_CHAT_USER)
              .borderRadius(20)
          }
          .alignItems(HorizontalAlign.End)
          .constraintSize({ maxWidth: '84%' })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else {
        // 学伴正文按阅读流排版，行动与依据留在同一条回复下方。
        Column() {
          Column() {
            Row({ space: 7 }) {
              Image($r('app.media.mascot_xiaohong_avatar'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(10)
              Text('小鸿')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ bottom: 8 })
            if (msg.content.length > 0) {
              Column() {
                this.MarkdownContent(this.readableMarkdown(msg.content), msg.failed)
              }
                .padding({ top: 4, bottom: 6 })
                .width('100%')
            }

            if (msg.action !== null && !msg.streaming && !msg.failed && !msg.cancelled &&
              msg.content.length > 0) {
              this.ActionCard(msg.action)
            }

            if (!msg.streaming && !msg.failed && !msg.cancelled && msg.content.length > 0 &&
              this.messages.indexOf(msg) === this.messages.length - 1) {
              Row() {
                Button(this.speechMessageIndex === this.messages.indexOf(msg) ? '停止朗读' :
                  (this.speechStarting ? '准备朗读' : '朗读回答'))
                  .height(44)
                  .padding({ left: 12, right: 12 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_BRAND_TEXT)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(12)
                  .enabled(!this.speechStarting)
                  .onClick((): void => { void this.readAnswer(msg); })
              }
              .width('100%')
              .justifyContent(FlexAlign.End)
              .margin({ top: 8 })
              if (this.speechError.length > 0) {
                Text(this.speechError)
                  .fontSize(11)
                  .fontColor(Constants.COLOR_ERROR)
              }
              Row({ space: 8 }) {
                Button('再给提示')
                  .height(44)
                  .padding({ left: 12, right: 12 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_BRAND_TEXT)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(12)
                  .enabled(!this.loading && this.cloudAgentReady && !this.historySaving)
                  .onClick((): void => { this.continueTutoring('hint'); })
                Button('换个例子')
                  .height(44)
                  .padding({ left: 12, right: 12 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  .backgroundColor(Constants.COLOR_BG_CARD)
                  .border({ width: 1, color: Constants.COLOR_BORDER })
                  .borderRadius(12)
                  .enabled(!this.loading && this.cloudAgentReady && !this.historySaving)
                  .onClick((): void => { this.continueTutoring('example'); })
              }
              .width('100%')
              .margin({ top: 9 })
            }

            if (msg.failed || msg.cancelled) {
              this.MessageStatus(msg)
            }

            // 引用（折叠式）
            if (msg.citations.length > 0) {
              Row() {
                Text(msg.citations.length.toString() + ' 条参考资料')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
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
              .constraintSize({ minHeight: 48 })
              .margin({ top: 4 })
              .focusable(true)
              .accessibilityText((msg.citationExpanded ? '收起' : '展开') + '参考资料，共 ' +
                msg.citations.length.toString() + ' 条')
              .accessibilityDescription('查看回答引用的课程资料')
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

            if (msg.streaming) {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(16)
                  .height(16)
                  .color(Constants.COLOR_BRAND)
                Text('正在回答')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .margin({ top: 10 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 15, right: 15, top: 14, bottom: 13 })
          .backgroundColor(Constants.COLOR_BG_CARD)
          .border({ width: 1, color: Constants.COLOR_BORDER })
          .borderRadius(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  ActionCard(action: ChatAction) {
    Column({ space: 6 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r(action.kind === 'lesson' ? 'sys.symbol.book_open_fill' :
          'sys.symbol.checkmark_circle_fill'))
          .fontSize(18)
          .fontColor([Constants.COLOR_BRAND])
        Column({ space: 2 }) {
          Text(action.kind === 'lesson' ? '接着学' : action.kind === 'quiz' ? '测一测' : '接着练')
            .fontSize(11)
            .fontColor(Constants.COLOR_BRAND_TEXT)
          Text(action.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button(this.actionButtonLabel(action.kind))
          .height(48)
          .padding({ left: 12, right: 12 })
          .borderRadius(Constants.RADIUS_MD)
          .enabled(!this.actionOpening)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .onClick((): void => { this.openAction(action); })
      }
      .width('100%')
      if (this.actionMessage.length > 0) {
        Text(this.actionMessage)
          .fontSize(11)
          .fontColor(Constants.COLOR_ERROR)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 8, top: 9, bottom: 9 })
    .backgroundColor(Constants.COLOR_BRAND_LIGHT)
    .borderRadius(Constants.RADIUS_LG)
    .margin({ top: 9, bottom: 3 })
  }

  @Builder
  MessageStatus(msg: DisplayMessage) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r(msg.cancelled ? 'sys.symbol.stop_circle_fill' : 'sys.symbol.exclamationmark_triangle_fill'))
          .width(18)
          .height(18)
          .fontSize(18)
          .fontColor([msg.cancelled ? Constants.COLOR_TEXT_SECONDARY : Constants.COLOR_ERROR])
        Column({ space: 2 }) {
          Text(msg.cancelled ? '回答已停止' : '这次回答未完成')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(msg.statusMessage)
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (msg.httpStatus > 0 || msg.errorCode.length > 0) {
        Row({ space: 4 }) {
          Text(msg.statusExpanded ? '收起错误详情' : '查看错误详情')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          SymbolGlyph($r(msg.statusExpanded ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
            .fontSize(11)
            .fontColor([Constants.COLOR_TEXT_SECONDARY])
        }
        .constraintSize({ minHeight: 48 })
        .focusable(true)
        .accessibilityText(msg.statusExpanded ? '收起这次回答的错误详情' : '展开这次回答的错误详情')
        .accessibilityDescription('查看 HTTP 状态和错误代码')
        .onClick((): void => {
          msg.statusExpanded = !msg.statusExpanded;
          this.messages = this.messages.slice();
        })

        if (msg.statusExpanded) {
          Column({ space: 3 }) {
            if (msg.httpStatus > 0) {
              Text('HTTP 状态：' + msg.httpStatus.toString())
                .width('100%')
                .fontSize(10)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)
            }
            if (msg.errorCode.length > 0) {
              Text('错误代码：' + msg.errorCode)
                .width('100%')
                .fontSize(10)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_SM)
        }
      }

      Button(msg.cancelled ? '重新提问' : '重试')
        .fontSize(12)
        .fontColor(Constants.COLOR_BRAND)
        .constraintSize({ minHeight: 48 })
        .padding({ left: 14, right: 14 })
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
        .accessibilityText(msg.cancelled ? '重新提问上一条问题' : '重试上一条问题')
        .accessibilityDescription(msg.statusMessage)
        .onClick((): void => {
          this.retryMessage(msg);
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(msg.cancelled ? Constants.COLOR_SURFACE_TINT : Constants.COLOR_ERROR_LIGHT)
    .borderRadius(Constants.RADIUS_MD)
    .margin({ top: 6 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MarkdownContent(content: string, failed: boolean) {
    Column({ space: 10 }) {
      ForEach(this.markdownBlocks(content), (block: MarkdownBlock): void => {
        if (block.type === 'heading') {
          Text(block.text)
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
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
              .fontSize(14)
              .lineHeight(22)
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
              .fontSize(15)
              .lineHeight(24)
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
              .fontSize(15)
              .lineHeight(24)
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
          Column({ space: 0 }) {
            Row({ space: 8 }) {
              Text(this.codeLanguage(block))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_MAP_SURFACE)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(Constants.COLOR_MAP_CORE)
                .borderRadius(10)
              Text('可横向滚动')
                .fontSize(11)
                .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
                .layoutWeight(1)
              Button('解释这段')
                .fontSize(11)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .constraintSize({ minHeight: 48 })
                .padding({ left: 10, right: 10 })
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .accessibilityText('让学伴解释当前代码片段')
                .accessibilityDescription('把代码片段填入问题输入框')
                .onClick((): void => {
                  this.explainCodeBlock(block);
                })
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(Constants.COLOR_MAP_LINE)

            Scroll() {
              Column({ space: 0 }) {
                ForEach(this.codeLines(block), (line: string, index: number): void => {
                  Row({ space: 12 }) {
                    Text(this.codeLineNumber(index))
                      .width(30)
                      .fontSize(11)
                      .lineHeight(20)
                      .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
                      .textAlign(TextAlign.End)
                    Text(line.length > 0 ? line : ' ')
                      .fontSize(12)
                      .lineHeight(20)
                      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                      .fontFamily('monospace')
                      .maxLines(1)
                  }
                  .constraintSize({ minWidth: 520 })
                  .padding({ top: 2, bottom: 2 })
                  .alignItems(VerticalAlign.Top)
                })
              }
              .padding({ left: 10, right: 12, top: 10, bottom: 10 })
            }
            .width('100%')
            .constraintSize({ maxHeight: 260 })
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Auto)
          }
          .width('100%')
          .backgroundColor(Constants.COLOR_MAP_SURFACE)
          .borderRadius(Constants.RADIUS_SM)
        } else if (block.type === 'table') {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.tableRows(block), (row: string, rowIndex: number): void => {
                Row() {
                  ForEach(this.tableCells(row), (cell: string): void => {
                    Text(cell)
                      .constraintSize({ minWidth: 96 })
                      .fontSize(11)
                      .lineHeight(18)
                      .fontWeight(rowIndex === 0 ? FontWeight.Bold : FontWeight.Regular)
                      .fontColor(rowIndex === 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_TERTIARY)
                      .padding({ left: 8, right: 8, top: 7, bottom: 7 })
                  })
                }
                .width('100%')
                .backgroundColor(rowIndex === 0 ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_SURFACE_TINT)
                .borderRadius(rowIndex === 0 ? Constants.RADIUS_SM : 0)
              })
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Auto)
          .backgroundColor(Constants.COLOR_SURFACE_TINT)
          .borderRadius(Constants.RADIUS_SM)
        } else {
          Text(block.text)
            .width('100%')
            .fontSize(15)
            .lineHeight(25)
            .fontColor(failed ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PRIMARY)
        }
      })
    }
    .width('100%')
  }

}

@Entry
@Component
@InsightIntentPage({
  intentName: 'AskLearningCompanion',
  domain: 'EducationDomain',
  intentVersion: '1.0.1',
  displayName: '询问学伴',
  displayDescription: '打开鸿学伴的 AI 学习辅导对话',
  llmDescription: '打开鸿学伴的学伴对话页，让用户询问课程概念、学习方法和复习问题。',
  keywords: ['问学伴', '学习辅导', '课程答疑', '鸿学伴'],
  uiAbility: 'EntryAbility',
  pagePath: './ets/pages/Chat'
})
struct ChatPage {
  build() {
    Column() {
      ChatContent()
    }
  }
}
