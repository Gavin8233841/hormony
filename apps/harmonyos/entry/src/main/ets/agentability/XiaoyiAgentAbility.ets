import { AgentExtensionAbility, common, Want } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { HttpClient, HttpRequestCancellation, HttpStreamError } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { ProactiveLearningAction, ProactiveLearningService } from '../common/ProactiveLearningService';
import { ChatMessage, StreamEvent } from '../model/DataModels';

interface DevicePart {
  text?: string;
  mediaType?: string;
  data?: DeviceErrorData;
}

interface DeviceErrorData {
  error: DeviceProtocolError;
}

interface DeviceProtocolError {
  code: string;
  message: string;
}

interface DeviceMessage {
  messageId?: string;
  taskId?: string;
  contextId?: string;
  role?: string;
  parts?: DevicePart[];
}

interface DeviceParams {
  id?: string;
  message?: DeviceMessage;
}

interface DeviceRequest {
  jsonrpc?: string;
  id?: string;
  method?: string;
  params?: DeviceParams;
}

interface TutorRequest {
  mode: string;
  message: string;
  history: ChatMessage[];
}

interface DeviceError {
  code: number;
  message: string;
}

interface DeviceErrorResponse {
  jsonrpc: string;
  id: string;
  error: DeviceError;
}

interface DeviceStatus {
  state: string;
  timestamp: string;
  message?: DeviceAgentMessage;
}

interface DeviceAgentMessage {
  role: string;
  messageId: string;
  parts: DevicePart[];
}

interface DeviceArtifact {
  artifactId: string;
  parts: DevicePart[];
}

interface DeviceTask {
  id: string;
  contextId: string;
  status: DeviceStatus;
  artifacts?: DeviceArtifact[];
}

interface DeviceTaskResult {
  task: DeviceTask;
}

interface DeviceTaskResponse {
  jsonrpc: string;
  id: string;
  result: DeviceTaskResult;
}

interface DeviceArtifactUpdate {
  taskId: string;
  contextId: string;
  artifact: DeviceArtifact;
  append: boolean;
  lastChunk: boolean;
}

interface DeviceArtifactResult {
  artifactUpdate: DeviceArtifactUpdate;
}

interface DeviceArtifactResponse {
  jsonrpc: string;
  id: string;
  result: DeviceArtifactResult;
}

interface DeviceStatusUpdate {
  taskId: string;
  contextId: string;
  status: DeviceStatus;
}

interface DeviceStatusResult {
  statusUpdate: DeviceStatusUpdate;
}

interface DeviceStatusResponse {
  jsonrpc: string;
  id: string;
  result: DeviceStatusResult;
}

interface DeviceCancelResult {
  id: string;
  contextId: string;
  status: DeviceStatus;
}

interface DeviceCancelResponse {
  jsonrpc: string;
  id: string;
  result: DeviceCancelResult;
}

interface ActiveTask {
  contextId: string;
  cancellation: HttpRequestCancellation;
  requestId: string;
  answer: string;
  citations: string[];
  failed: boolean;
  completed: boolean;
  terminalSeen: boolean;
}

interface FinishedTask {
  contextId: string;
  state: string;
}

// 小艺端 A2A 仅提供短文本课程讲解。进程内历史只辅助本次连接，
// 不表示跨设备持久会话；学习画像和答题记录不传到此入口。
export default class XiaoyiAgentAbility extends AgentExtensionAbility {
  private activeTasks: Map<common.AgentHostProxy, Map<string, ActiveTask>> = new Map();
  private activeTaskCount: number = 0;
  private histories: Map<common.AgentHostProxy, Map<string, ChatMessage[]>> = new Map();
  private finishedTasks: Map<common.AgentHostProxy, Map<string, FinishedTask>> = new Map();

  private readonly maxActiveTasks: number = 2;
  private readonly maxHistories: number = 16;
  private readonly maxConnections: number = 8;
  private readonly maxFinishedTasks: number = 16;
  private readonly maxRequestChars: number = 16384;

  onCreate(_want: Want): void {}
  onConnect(_want: Want, _proxy: common.AgentHostProxy): void {}

  onData(proxy: common.AgentHostProxy, data: string): void {
    if (typeof data !== 'string' || data.length > this.maxRequestChars) {
      this.sendError(proxy, '', -32600, '请求过长或格式不正确');
      return;
    }
    let request: DeviceRequest;
    try {
      request = JSON.parse(data);
    } catch (_) {
      this.sendError(proxy, '', -32700, '请求格式不正确');
      return;
    }
    if (request === null || typeof request !== 'object' || Array.isArray(request) ||
      request.jsonrpc !== '2.0' || typeof request.id !== 'string' ||
      request.id.length === 0 || request.id.length > 128) {
      this.sendError(proxy, '', -32600, '请求字段不正确');
      return;
    }
    if (request.method === 'TasksCancel') {
      this.cancelTask(proxy, request);
      return;
    }
    if (request.method !== 'MessageStream') {
      this.sendError(proxy, request.id, -32601, '不支持该操作');
      return;
    }
    const message = request.params?.message;
    const part = message?.parts?.[0];
    const question = typeof part?.text === 'string' ? part.text.trim() : '';
    if (!message || message.role !== 'ROLE_USER' || typeof message.messageId !== 'string' ||
      message.messageId.length === 0 || message.messageId.length > 128 ||
      !Array.isArray(message.parts) || message.parts.length !== 1 || !part ||
      part.mediaType !== 'text/plain' || question.length === 0 || question.length > 2000 ||
      (message.contextId !== undefined &&
        (typeof message.contextId !== 'string' || message.contextId.length === 0 ||
          message.contextId.length > 128))) {
      this.sendError(proxy, request.id, -32602, '仅支持 2000 字以内的文本课程问题');
      return;
    }
    if (message.taskId !== undefined) {
      this.sendError(proxy, request.id, -32602, '暂不支持继续待澄清任务');
      return;
    }
    const existingHistories = this.histories.get(proxy);
    if (message.contextId && !existingHistories?.has(message.contextId)) {
      this.sendError(proxy, request.id, 99911222, '会话已失效，请重新提问');
      return;
    }
    // 按端 A2A 规范由 Agent 分配标识；用户消息 ID 不能充当 Task 或 Context ID。
    const taskId = 'task-' + util.generateRandomUUID();
    const contextId = message.contextId ?? 'ctx-' + util.generateRandomUUID();
    let connectionTasks = this.activeTasks.get(proxy);
    if (connectionTasks) {
      for (const active of connectionTasks.values()) {
        if (active.contextId === contextId) {
          this.sendError(proxy, request.id, -32002, '当前会话正在处理其他问题，请稍后重试');
          return;
        }
      }
    }
    if (this.activeTaskCount >= this.maxActiveTasks) {
      this.sendError(proxy, request.id, -32002, '当前正在处理其他问题，请稍后重试');
      return;
    }
    const cancellation = new HttpRequestCancellation();
    const active: ActiveTask = {
      contextId, cancellation, requestId: request.id, answer: '', citations: [],
      failed: false, completed: false, terminalSeen: false,
    };
    if (!connectionTasks) {
      connectionTasks = new Map<string, ActiveTask>();
      this.activeTasks.set(proxy, connectionTasks);
    }
    connectionTasks.set(taskId, active);
    this.activeTaskCount += 1;
    let connectionHistories = this.histories.get(proxy);
    if (!connectionHistories) {
      connectionHistories = new Map<string, ChatMessage[]>();
      if (this.histories.size >= this.maxConnections) {
        for (const oldestProxy of this.histories.keys()) {
          this.histories.delete(oldestProxy);
          this.finishedTasks.delete(oldestProxy);
          break;
        }
      }
      this.histories.set(proxy, connectionHistories);
    }
    const history = connectionHistories.get(contextId) ?? [];
    const body: TutorRequest = { mode: 'xiaoyi_tutor', message: question, history };
    // 首帧公布 Agent 分配的任务标识，小艺才能在生成过程中发出 TasksCancel。
    if (!this.sendSubmittedTask(proxy, request.id, taskId, contextId)) {
      active.completed = true;
      this.removeActiveTask(proxy, taskId);
      return;
    }
    if (active.completed) return;
    if (this.isNextLearningQuestion(question)) {
      this.replyWithLocalNextAction(proxy, active, taskId, contextId);
      return;
    }
    HttpClient.postSSE(Constants.API_XIAOYI_TUTOR, JSON.stringify(body),
      (event: StreamEvent): void => {
        if (active.completed || active.failed) return;
        if (event.type === 'error') {
          active.failed = true;
          active.cancellation.cancel();
          this.removeActiveTask(proxy, taskId);
          this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_FAILED');
          this.sendStatusUpdate(proxy, active.requestId, taskId, contextId,
            'TASK_STATE_FAILED', '课程讲解暂时不可用，请稍后重试');
        } else if (event.type === 'done') {
          active.terminalSeen = true;
        } else if (event.type === 'citation' && typeof event.source?.doc === 'string') {
          const sourceName = event.source.doc.trim().replace(/\s+/g, ' ').slice(0, 80);
          if (sourceName.length > 0 && active.citations.length < 3 &&
            !active.citations.includes(sourceName)) {
            active.citations.push(sourceName);
          }
        } else if (event.type === 'delta' && typeof event.content === 'string') {
          active.answer += event.content;
          if (active.answer.length > 8000) {
            active.failed = true;
            active.cancellation.cancel();
            this.removeActiveTask(proxy, taskId);
            this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_FAILED');
            this.sendStatusUpdate(proxy, active.requestId, taskId, contextId,
              'TASK_STATE_FAILED', '回答过长，请缩小问题范围');
          }
        }
      },
      (): void => {
        if (active.completed || active.failed) return;
        active.completed = true;
        this.removeActiveTask(proxy, taskId);
        if (!active.terminalSeen || active.answer.trim().length === 0) {
          this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_FAILED');
          this.sendStatusUpdate(proxy, active.requestId, taskId, contextId,
            'TASK_STATE_FAILED', '暂时无法生成课程讲解');
          return;
        }
        this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_COMPLETED');
        const sourceLines = active.citations.map((name: string, index: number): string =>
          '[' + (index + 1).toString() + '] ' + name);
        const sourceText = sourceLines.length > 0 ? '\n\n参考资料：\n' + sourceLines.join('\n') : '';
        const finalAnswer = active.answer.length + sourceText.length <= 8000 ?
          active.answer + sourceText : active.answer;
        if (!this.sendArtifactUpdate(proxy, active.requestId, taskId, contextId, finalAnswer)) return;
        const nextHistory: ChatMessage[] = [...history,
          { role: 'user', content: question.slice(0, 1000) },
          { role: 'assistant', content: active.answer.slice(0, 1000) }];
        // Map 按插入顺序保存会话；只保留最近使用的少量短文本上下文。
        const currentHistories = this.histories.get(proxy);
        if (currentHistories) {
          currentHistories.delete(contextId);
          currentHistories.set(contextId, nextHistory.slice(-12));
        }
        if (currentHistories && currentHistories.size > this.maxHistories) {
          for (const oldestContextId of currentHistories.keys()) {
            currentHistories.delete(oldestContextId);
            break;
          }
        }
        this.sendStatusUpdate(proxy, active.requestId, taskId, contextId, 'TASK_STATE_COMPLETED');
      },
      (_error: HttpStreamError): void => {
        if (active.completed || active.failed) return;
        active.failed = true;
        this.removeActiveTask(proxy, taskId);
        this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_FAILED');
        this.sendStatusUpdate(proxy, active.requestId, taskId, contextId,
          'TASK_STATE_FAILED', '网络暂时不可用，请稍后重试');
      }, undefined, cancellation);
  }

  private isNextLearningQuestion(question: string): boolean {
    const normalized = question.replace(/[\s？?。！!，,、]/g, '').replace(/^小鸿/, '');
    return normalized === '今天学什么' || normalized === '下一步学什么' ||
      normalized === '我该学什么' || normalized === '我接下来应该学什么' ||
      normalized === '我现在该复习什么';
  }

  private async replyWithLocalNextAction(proxy: common.AgentHostProxy, active: ActiveTask,
    taskId: string, contextId: string): Promise<void> {
    try {
      await LearningContentRepository.initialize(this.context.resourceManager);
      await LocalLearningRepository.initialize(this.context);
      const action: ProactiveLearningAction = await ProactiveLearningService.resolve();
      if (active.completed) return;
      active.completed = true;
      this.removeActiveTask(proxy, taskId);
      const answer = '根据鸿学伴本机当前学习状态，下一步建议：' + action.title + '。' +
        action.subtitle + '。打开鸿学伴可选择「' + action.cta + '」。';
      if (!this.sendArtifactUpdate(proxy, active.requestId, taskId, contextId, answer)) return;
      this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_COMPLETED');
      // 本机学习状态只用于当前答复，不写入后续云端 Tutor 对话历史。
      const connectionHistories = this.histories.get(proxy);
      if (connectionHistories && !connectionHistories.has(contextId)) {
        connectionHistories.set(contextId, []);
        if (connectionHistories.size > this.maxHistories) {
          for (const oldestContextId of connectionHistories.keys()) {
            connectionHistories.delete(oldestContextId);
            break;
          }
        }
      }
      this.sendStatusUpdate(proxy, active.requestId, taskId, contextId, 'TASK_STATE_COMPLETED');
    } catch (_) {
      if (active.completed) return;
      active.completed = true;
      this.removeActiveTask(proxy, taskId);
      this.rememberFinishedTask(proxy, taskId, contextId, 'TASK_STATE_FAILED');
      this.sendStatusUpdate(proxy, active.requestId, taskId, contextId,
        'TASK_STATE_FAILED', '暂时无法读取本机学习建议，请打开鸿学伴查看');
    }
  }

  private cancelTask(proxy: common.AgentHostProxy, request: DeviceRequest): void {
    const taskId = request.params?.id;
    if (typeof taskId !== 'string' || taskId.length === 0 || taskId.length > 128) {
      this.sendError(proxy, request.id ?? '', -32602, '缺少任务标识');
      return;
    }
    const active = this.activeTasks.get(proxy)?.get(taskId);
    if (!active) {
      const finished = this.finishedTasks.get(proxy)?.get(taskId);
      if (finished) {
        this.sendFinishedCancel(proxy, request.id ?? '', taskId, finished);
        return;
      }
      this.sendError(proxy, request.id ?? '', -32001, '任务不存在或已经结束');
      return;
    }
    active.completed = true;
    active.cancellation.cancel();
    this.removeActiveTask(proxy, taskId);
    this.rememberFinishedTask(proxy, taskId, active.contextId, 'TASK_STATE_CANCELED');
    this.sendCanceled(proxy, request.id ?? '', taskId, active.contextId);
  }

  private sendFinishedCancel(proxy: common.AgentHostProxy, requestId: string,
    taskId: string, finished: FinishedTask): void {
    const status: DeviceStatus = { state: finished.state, timestamp: new Date().toISOString() };
    if (finished.state === 'TASK_STATE_FAILED') {
      const protocolError: DeviceProtocolError = { code: '99911200', message: '任务已结束' };
      const data: DeviceErrorData = { error: protocolError };
      const part: DevicePart = { data };
      status.message = { role: 'ROLE_AGENT', messageId: 'msg-' + util.generateRandomUUID(), parts: [part] };
    }
    const result: DeviceCancelResult = { id: taskId, contextId: finished.contextId, status };
    const response: DeviceCancelResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
    } catch (_) {
      // 连接已结束；不记录用户问题或协议载荷。
    }
  }

  private sendCanceled(proxy: common.AgentHostProxy, requestId: string,
    taskId: string, contextId: string): void {
    const status: DeviceStatus = { state: 'TASK_STATE_CANCELED', timestamp: new Date().toISOString() };
    const result: DeviceCancelResult = { id: taskId, contextId, status };
    const response: DeviceCancelResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
    } catch (_) {
      // 连接已结束；不记录用户问题或协议载荷。
    }
  }

  private sendError(proxy: common.AgentHostProxy, requestId: string,
    code: number, message: string): void {
    const error: DeviceError = { code, message };
    const response: DeviceErrorResponse = { jsonrpc: '2.0', id: requestId, error };
    try {
      proxy.sendData(JSON.stringify(response));
    } catch (_) {
      // 连接已结束；不记录用户问题或协议载荷。
    }
  }

  private sendSubmittedTask(proxy: common.AgentHostProxy, requestId: string, taskId: string,
    contextId: string): boolean {
    const status: DeviceStatus = { state: 'TASK_STATE_SUBMITTED', timestamp: new Date().toISOString() };
    const task: DeviceTask = { id: taskId, contextId, status };
    const result: DeviceTaskResult = { task };
    const response: DeviceTaskResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
      return true;
    } catch (_) {
      // 连接已结束；请求已经取消或无法再交付。
      return false;
    }
  }

  private sendArtifactUpdate(proxy: common.AgentHostProxy, requestId: string, taskId: string,
    contextId: string, content: string): boolean {
    const part: DevicePart = { text: content, mediaType: 'text/plain' };
    const artifact: DeviceArtifact = { artifactId: taskId + '-text', parts: [part] };
    const artifactUpdate: DeviceArtifactUpdate = {
      taskId, contextId, artifact, append: false, lastChunk: true
    };
    const result: DeviceArtifactResult = { artifactUpdate };
    const response: DeviceArtifactResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
      return true;
    } catch (_) {
      return false;
    }
  }

  private sendStatusUpdate(proxy: common.AgentHostProxy, requestId: string, taskId: string,
    contextId: string, state: string, content?: string): boolean {
    const status: DeviceStatus = { state, timestamp: new Date().toISOString() };
    if (content && content.length > 0) {
      const part: DevicePart = { text: content, mediaType: 'text/plain' };
      status.message = { role: 'ROLE_AGENT', messageId: 'msg-' + util.generateRandomUUID(), parts: [part] };
    }
    const statusUpdate: DeviceStatusUpdate = { taskId, contextId, status };
    const result: DeviceStatusResult = { statusUpdate };
    const response: DeviceStatusResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
      return true;
    } catch (_) {
      return false;
    }
  }

  private removeActiveTask(proxy: common.AgentHostProxy, taskId: string): void {
    const connectionTasks = this.activeTasks.get(proxy);
    if (!connectionTasks?.delete(taskId)) return;
    this.activeTaskCount -= 1;
    if (connectionTasks.size === 0) this.activeTasks.delete(proxy);
  }

  private rememberFinishedTask(proxy: common.AgentHostProxy, taskId: string,
    contextId: string, state: string): void {
    let tasks = this.finishedTasks.get(proxy);
    if (!tasks) {
      tasks = new Map<string, FinishedTask>();
      this.finishedTasks.set(proxy, tasks);
    }
    tasks.set(taskId, { contextId, state });
    if (tasks.size > this.maxFinishedTasks) {
      for (const oldestTaskId of tasks.keys()) {
        tasks.delete(oldestTaskId);
        break;
      }
    }
  }

  onDisconnect(_want: Want, proxy: common.AgentHostProxy): void {
    const connectionTasks = this.activeTasks.get(proxy);
    if (connectionTasks) {
      for (const task of connectionTasks.values()) {
        task.completed = true;
        task.cancellation.cancel();
      }
      this.activeTaskCount -= connectionTasks.size;
      this.activeTasks.delete(proxy);
    }
    this.histories.delete(proxy);
    this.finishedTasks.delete(proxy);
  }

  onDestroy(): void {
    for (const connectionTasks of this.activeTasks.values()) {
      for (const task of connectionTasks.values()) {
        task.completed = true;
        task.cancellation.cancel();
      }
    }
    this.activeTasks.clear();
    this.activeTaskCount = 0;
    this.histories.clear();
    this.finishedTasks.clear();
  }
}
