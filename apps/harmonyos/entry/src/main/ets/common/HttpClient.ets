/**
 * HTTP 客户端
 * 封装 @ohos.net.http 的常用请求方法
 * ArkTS 合规：无 as 断言、无 Object 类型、无 Record 结构化类型
 */

import http from '@ohos.net.http';
import { util } from '@kit.ArkTS';
import { Constants } from './Constants';
import { HealthResponse, StreamEvent } from '../model/DataModels';

export class HttpClient {
  /**
   * 发送 GET 请求
   */
  static async get<T>(path: string): Promise<T> {
    let lastNetworkError: Error = new Error('Network request failed');
    for (const baseUrl of Constants.API_BASE_URLS) {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(baseUrl + path, {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' },
          connectTimeout: Constants.CONNECT_TIMEOUT,
          readTimeout: Constants.REQUEST_TIMEOUT,
          expectDataType: http.HttpDataType.STRING,
        });
        if (response.responseCode !== 200) {
          throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
        }
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: T = JSON.parse(result);
        return parsed;
      } catch (e) {
        const error = e instanceof Error ? e : new Error('Network request failed');
        if (error.message.startsWith('HTTP ') || error.message === 'Response is not a string' ||
          error.name === 'SyntaxError') {
          throw error;
        }
        lastNetworkError = error;
      } finally {
        httpRequest.destroy();
      }
    }
    throw lastNetworkError;
  }

  /**
   * 健康探测只用于判断云端学伴是否可用，使用更短 readTimeout，避免启动和进入学伴页时长时间等待。
   * 503 degraded 响应包含结构化 JSON；若后续 base URL 不可用，返回最后一次 degraded 状态。
   */
  static async getHealth(): Promise<HealthResponse> {
    let lastNetworkError: Error = new Error('Network request failed');
    let degradedResponse: HealthResponse | null = null;
    for (const baseUrl of Constants.API_BASE_URLS) {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(baseUrl + Constants.API_HEALTH, {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' },
          connectTimeout: Constants.CONNECT_TIMEOUT,
          readTimeout: Constants.HEALTH_REQUEST_TIMEOUT,
          expectDataType: http.HttpDataType.STRING,
        });
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: HealthResponse = JSON.parse(result);
        if (response.responseCode === 200) {
          return parsed;
        }
        if (response.responseCode === 503) {
          degradedResponse = parsed;
          continue;
        }
        throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
      } catch (e) {
        const error = e instanceof Error ? e : new Error('Network request failed');
        if (error.message === 'Response is not a string' || error.name === 'SyntaxError') {
          throw error;
        }
        lastNetworkError = error;
      } finally {
        httpRequest.destroy();
      }
    }
    if (degradedResponse !== null) return degradedResponse;
    throw lastNetworkError;
  }

  /**
   * 发送 POST 请求
   * body 参数为 JSON 字符串（调用方负责 JSON.stringify）
   */
  static async post<T>(path: string, body: string, readTimeout: number = Constants.MODEL_REQUEST_TIMEOUT): Promise<T> {
    let lastNetworkError: Error = new Error('Network request failed');
    for (const baseUrl of Constants.API_BASE_URLS) {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(baseUrl + path, {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: body,
          connectTimeout: Constants.CONNECT_TIMEOUT,
          readTimeout: readTimeout,
          expectDataType: http.HttpDataType.STRING,
        });
        if (response.responseCode !== 200) {
          const httpError = new Error('HTTP ' + response.responseCode + ': ' + response.result);
          if (response.responseCode >= 500) {
            lastNetworkError = httpError;
            continue;
          }
          throw httpError;
        }
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: T = JSON.parse(result);
        return parsed;
      } catch (e) {
        const error = e instanceof Error ? e : new Error('Network request failed');
        if (error.message.startsWith('HTTP ') || error.message === 'Response is not a string' ||
          error.name === 'SyntaxError') {
          throw error;
        }
        lastNetworkError = error;
      } finally {
        httpRequest.destroy();
      }
    }
    throw lastNetworkError;
  }

  /**
   * 发送 PATCH 请求
   */
  static async patch<T>(path: string, body: string): Promise<T> {
    let lastNetworkError: Error = new Error('Network request failed');
    for (const baseUrl of Constants.API_BASE_URLS) {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(baseUrl + path, {
          method: http.RequestMethod.PATCH,
          header: { 'Content-Type': 'application/json' },
          extraData: body,
          connectTimeout: Constants.CONNECT_TIMEOUT,
          readTimeout: Constants.MODEL_REQUEST_TIMEOUT,
          expectDataType: http.HttpDataType.STRING,
        });
        if (response.responseCode !== 200) {
          throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
        }
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: T = JSON.parse(result);
        return parsed;
      } catch (e) {
        const error = e instanceof Error ? e : new Error('Network request failed');
        if (error.message.startsWith('HTTP ') || error.message === 'Response is not a string' ||
          error.name === 'SyntaxError') {
          throw error;
        }
        lastNetworkError = error;
      } finally {
        httpRequest.destroy();
      }
    }
    throw lastNetworkError;
  }

  /**
   * 发送 SSE 流式 POST 请求（对话）
   * onEvent 回调在收到每条 SSE 事件时触发
   * onCreated 回调在 httpRequest 创建后触发，调用方可保存引用用于取消
   */
  static postSSE(
    path: string,
    body: string,
    onEvent: (event: StreamEvent) => void,
    onDone: () => void,
    onError: (err: Error) => void,
    onCreated?: (req: http.HttpRequest) => void
  ): void {
    let doneCalled: boolean = false;
    let eventBuffer: string = '';
    const decoder = util.TextDecoder.create('utf-8');

    const consumeText = (text: string): void => {
      eventBuffer += text;
      const frames = eventBuffer.split('\n\n');
      eventBuffer = frames.pop() ?? '';

      for (const frame of frames) {
        const trimmed = frame.trim();
        if (!trimmed.startsWith('data:')) {
          continue;
        }
        const jsonStr = trimmed.replace(/^data:\s*/, '');
        try {
          const evt: StreamEvent = JSON.parse(jsonStr);
          onEvent(evt);
          if (evt.type === 'done' && !doneCalled) {
            doneCalled = true;
            onDone();
          }
        } catch (e) {
          // 完整 SSE 帧无法解析时跳过，避免单条异常数据中断整个对话。
        }
      }
    };

    const startRequest = (baseIndex: number): void => {
      const httpRequest = http.createHttp();
      let cleanedUp: boolean = false;
      let receivedData: boolean = false;
      if (onCreated) {
        onCreated(httpRequest);
      }

      const cleanup = (): void => {
        if (cleanedUp) return;
        cleanedUp = true;
        try {
          httpRequest.off('dataReceive');
        } catch (e) {
          // 监听器可能已移除，忽略
        }
        try {
          httpRequest.destroy();
        } catch (e) {
          // 请求可能已销毁，忽略
        }
      };

      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        receivedData = true;
        const text = decoder.decodeToString(new Uint8Array(data), { stream: true });
        consumeText(text);
      });

      httpRequest.requestInStream(Constants.API_BASE_URLS[baseIndex] + path, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        extraData: body,
        connectTimeout: Constants.CONNECT_TIMEOUT,
        readTimeout: Constants.SSE_TIMEOUT,
      }).then((responseCode: number) => {
        if (responseCode !== 200) {
          cleanup();
          if (responseCode >= 500 && !receivedData && baseIndex + 1 < Constants.API_BASE_URLS.length) {
            startRequest(baseIndex + 1);
            return;
          }
          onError(new Error('HTTP ' + responseCode));
          return;
        }
        if (!doneCalled) {
          doneCalled = true;
          onDone();
        }
        cleanup();
      }).catch((e: Error) => {
        cleanup();
        if (!receivedData && baseIndex + 1 < Constants.API_BASE_URLS.length) {
          startRequest(baseIndex + 1);
          return;
        }
        onError(e);
      });
    };

    startRequest(0);
  }
}
