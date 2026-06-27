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
    const httpRequest = http.createHttp();
    try {
      const url = Constants.BASE_URL + path;
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: Constants.REQUEST_TIMEOUT,
        readTimeout: Constants.REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
      });
      if (response.responseCode === 200) {
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: T = JSON.parse(result);
        return parsed;
      }
      throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
    } catch (e) {
      throw e instanceof Error ? e : new Error('Network request failed');
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 发送 POST 请求
   * body 参数为 JSON 字符串（调用方负责 JSON.stringify）
   */
  static async post<T>(path: string, body: string): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const url = Constants.BASE_URL + path;
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: body,
        connectTimeout: Constants.REQUEST_TIMEOUT,
        readTimeout: Constants.REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
      });
      if (response.responseCode === 200) {
        const result = response.result;
        if (typeof result !== 'string') {
          throw new Error('Response is not a string');
        }
        const parsed: T = JSON.parse(result);
        return parsed;
      }
      throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
    } catch (e) {
      throw e instanceof Error ? e : new Error('Network request failed');
    } finally {
      httpRequest.destroy();
    }
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
    const httpRequest = http.createHttp();
    if (onCreated) {
      onCreated(httpRequest);
    }

    const url = Constants.BASE_URL + path;
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

    // 注册数据接收回调（流式）
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      const text = decoder.decodeToString(new Uint8Array(data), { stream: true });
      consumeText(text);
    });

    // 流式请求完成
    httpRequest.requestInStream(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      extraData: body,
      connectTimeout: Constants.REQUEST_TIMEOUT,
      readTimeout: Constants.REQUEST_TIMEOUT,
    }).then(() => {
      // 流结束但未收到 done 事件时，确保 onDone 被调用
      if (!doneCalled) {
        doneCalled = true;
        onDone();
      }
      httpRequest.destroy();
    }).catch((e: Error) => {
      onError(e);
      httpRequest.destroy();
    });
  }
}
