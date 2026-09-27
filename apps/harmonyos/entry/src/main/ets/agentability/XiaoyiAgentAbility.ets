import { AgentExtensionAbility, common, Want } from '@kit.AbilityKit';
import { HttpClient, HttpRequestCancellation, HttpStreamError } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { ChatMessage, StreamEvent } from '../model/DataModels';

interface DevicePart {
  text?: string;
  mediaType?: string;
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
}

interface DeviceArtifact {
  artifactId: string;
  parts: DevicePart[];
}

interface DeviceTask {
  id: string;
  contextId: string;
  status: DeviceStatus;
  artifacts: DeviceArtifact[];
}

interface DeviceTaskResult {
  task: DeviceTask;
}

interface DeviceTaskResponse {
  jsonrpc: string;
  id: string;
  result: DeviceTaskResult;
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
  proxy: common.AgentHostProxy;
  contextId: string;
  cancellation: HttpRequestCancellation;
  requestId: string;
  question: string;
  answer: string;
  failed: boolean;
  completed: boolean;
  terminalSeen: boolean;
}

// 小艺端 A2A 仅提供短文本课程讲解。进程内历史只辅助本次连接，
// 不表示跨设备持久会话；学习画像和答题记录不传到此入口。
export default class XiaoyiAgentAbility extends AgentExtensionAbility {
  private activeTasks: Map<string, ActiveTask> = new Map();
  private histories: Map<common.AgentHostProxy, Map<string, ChatMessage[]>> = new Map();

  private readonly maxActiveTasks: number = 2;
  private readonly maxHistories: number = 16;
  private readonly maxConnections: number = 8;

  onCreate(_want: Want): void {}
  onConnect(_want: Want, _proxy: common.AgentHostProxy): void {}

  onData(proxy: common.AgentHostProxy, data: string): void {
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
        (typeof message.contextId !== 'string' || message.contextId.length > 128))) {
      this.sendError(proxy, request.id, -32602, '仅支持 2000 字以内的文本课程问题');
      return;
    }
    const taskId = message.taskId ?? message.messageId;
    const contextId = message.contextId && message.contextId.length > 0 ?
      message.contextId : message.messageId;
    if (typeof taskId !== 'string' || taskId.length === 0 || taskId.length > 128 ||
      this.activeTasks.has(taskId)) {
      this.sendError(proxy, request.id, -32602, '任务标识不可用');
      return;
    }
    if (this.activeTasks.size >= this.maxActiveTasks) {
      this.sendError(proxy, request.id, -32002, '当前正在处理其他问题，请稍后重试');
      return;
    }
    const cancellation = new HttpRequestCancellation();
    const active: ActiveTask = {
      proxy, contextId, cancellation, requestId: request.id, question, answer: '',
      failed: false, completed: false, terminalSeen: false,
    };
    this.activeTasks.set(taskId, active);
    let connectionHistories = this.histories.get(proxy);
    if (!connectionHistories) {
      connectionHistories = new Map<string, ChatMessage[]>();
      if (this.histories.size >= this.maxConnections) {
        for (const oldestProxy of this.histories.keys()) {
          this.histories.delete(oldestProxy);
          break;
        }
      }
      this.histories.set(proxy, connectionHistories);
    }
    const history = connectionHistories.get(contextId) ?? [];
    const body: TutorRequest = { mode: 'xiaoyi_tutor', message: question, history };
    HttpClient.postSSE(Constants.API_XIAOYI_TUTOR, JSON.stringify(body),
      (event: StreamEvent): void => {
        if (active.completed || active.failed) return;
        if (event.type === 'error') {
          active.failed = true;
          this.activeTasks.delete(taskId);
          this.sendTask(proxy, active.requestId, taskId, contextId,
            'TASK_STATE_FAILED', '课程讲解暂时不可用，请稍后重试');
        } else if (event.type === 'done') {
          active.terminalSeen = true;
        } else if (event.type === 'delta' && typeof event.content === 'string') {
          active.answer += event.content;
          if (active.answer.length > 8000) {
            active.failed = true;
            active.cancellation.cancel();
            this.activeTasks.delete(taskId);
            this.sendTask(proxy, active.requestId, taskId, contextId,
              'TASK_STATE_FAILED', '回答过长，请缩小问题范围');
          }
        }
      },
      (): void => {
        if (active.completed || active.failed) return;
        active.completed = true;
        this.activeTasks.delete(taskId);
        if (!active.terminalSeen || active.answer.trim().length === 0) {
          this.sendTask(proxy, active.requestId, taskId, contextId,
            'TASK_STATE_FAILED', '暂时无法生成课程讲解');
          return;
        }
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
        this.sendTask(proxy, active.requestId, taskId, contextId, 'TASK_STATE_COMPLETED', active.answer);
      },
      (_error: HttpStreamError): void => {
        if (active.completed || active.failed) return;
        active.failed = true;
        this.activeTasks.delete(taskId);
        this.sendTask(proxy, active.requestId, taskId, contextId,
          'TASK_STATE_FAILED', '网络暂时不可用，请稍后重试');
      }, undefined, cancellation);
  }

  private cancelTask(proxy: common.AgentHostProxy, request: DeviceRequest): void {
    const taskId = request.params?.id;
    if (typeof taskId !== 'string' || taskId.length === 0 || taskId.length > 128) {
      this.sendError(proxy, request.id ?? '', -32602, '缺少任务标识');
      return;
    }
    const active = this.activeTasks.get(taskId);
    if (!active || active.proxy !== proxy) {
      this.sendError(proxy, request.id ?? '', -32001, '任务不存在或已经结束');
      return;
    }
    active.completed = true;
    active.cancellation.cancel();
    this.activeTasks.delete(taskId);
    this.sendCanceled(proxy, request.id ?? '', taskId, active.contextId);
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

  private sendTask(proxy: common.AgentHostProxy, requestId: string, taskId: string,
    contextId: string, state: string, content: string): void {
    const status: DeviceStatus = { state, timestamp: new Date().toISOString() };
    const artifacts: DeviceArtifact[] = [];
    if (content.length > 0) {
      const part: DevicePart = { text: content, mediaType: 'text/plain' };
      const artifact: DeviceArtifact = { artifactId: taskId + '-text', parts: [part] };
      artifacts.push(artifact);
    }
    const task: DeviceTask = { id: taskId, contextId, status, artifacts };
    const result: DeviceTaskResult = { task };
    const response: DeviceTaskResponse = { jsonrpc: '2.0', id: requestId, result };
    try {
      proxy.sendData(JSON.stringify(response));
    } catch (_) {
      // 连接已结束；请求已经取消或无法再交付。
    }
  }

  onDisconnect(_want: Want, proxy: common.AgentHostProxy): void {
    for (const taskId of this.activeTasks.keys()) {
      const task = this.activeTasks.get(taskId);
      if (!task) continue;
      if (task.proxy === proxy) {
        task.completed = true;
        task.cancellation.cancel();
        this.activeTasks.delete(taskId);
      }
    }
    this.histories.delete(proxy);
  }

  onDestroy(): void {
    for (const task of this.activeTasks.values()) {
      task.completed = true;
      task.cancellation.cancel();
    }
    this.activeTasks.clear();
    this.histories.clear();
  }
}
