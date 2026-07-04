/**
 * HTTP 客户端
 * 封装 @ohos.net.http 的常用请求方法
 * ArkTS 合规：无 as 断言、无 Object 类型、无 Record 结构化类型
 */

import http from '@ohos.net.http';
import { util } from '@kit.ArkTS';
import { Constants } from './Constants';
import { StreamEvent } from '../model/DataModels';

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
   * 发送 POST 请求
   * body 参数为 JSON 字符串（调用方负责 JSON.stringify）
   */
  static async post<T>(path: string, body: string): Promise<T> {
    let lastNetworkError: Error = new Error('Network request failed');
    for (const baseUrl of Constants.API_BASE_URLS) {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(baseUrl + path, {
          method: http.RequestMethod.POST,
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

    const consumeText = (text: string): boolean => {
      eventBuffer += text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      const frames = eventBuffer.split('\n\n');
      eventBuffer = frames.pop() ?? '';
      let sawDoneEvent: boolean = false;

      for (const frame of frames) {
        const dataLines: string[] = [];
        for (const rawLine of frame.split('\n')) {
          const line = rawLine.trimEnd();
          if (line.startsWith('data:')) {
            dataLines.push(line.slice(5).trimStart());
          }
        }
        if (dataLines.length === 0) {
          continue;
        }
        const jsonStr = dataLines.join('\n').trim();
        if (jsonStr.length === 0) continue;
        try {
          const evt: StreamEvent = JSON.parse(jsonStr);
          onEvent(evt);
          if (evt.type === 'done' && !doneCalled) {
            doneCalled = true;
            onDone();
            sawDoneEvent = true;
          }
        } catch (e) {
          // 完整 SSE 帧无法解析时跳过，避免单条异常数据中断整个对话。
        }
      }
      return sawDoneEvent;
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
          httpRequest.off('dataEnd');
        } catch (e) {
          // 监听器可能已移除，忽略
        }
        try {
          httpRequest.destroy();
        } catch (e) {
          // 请求可能已销毁，忽略
        }
      };

      const finishStream = (): void => {
        if (eventBuffer.trim().length > 0) {
          consumeText('\n\n');
        }
        if (!doneCalled) {
          doneCalled = true;
          onDone();
        }
        cleanup();
      };

      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        receivedData = true;
        const text = decoder.decodeToString(new Uint8Array(data), { stream: true });
        if (consumeText(text)) {
          cleanup();
        }
      });

      httpRequest.on('dataEnd', () => {
        finishStream();
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
          onError(new Error('HTTP ' + responseCode));
          cleanup();
          return;
        }
        if (!receivedData) {
          finishStream();
        }
      }).catch((e: Error) => {
        if (doneCalled) {
          cleanup();
          return;
        }
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
