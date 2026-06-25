/**
 * HTTP 客户端
 * 封装 @ohos.net.http 的常用请求方法
 */

import http from '@ohos.net.http';
import { Constants } from './Constants';

export class HttpClient {
  /**
   * 发送 GET 请求
   */
  static async get<T>(path: string): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const url = `${Constants.BASE_URL}${path}`;
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: Constants.REQUEST_TIMEOUT,
        readTimeout: Constants.REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 发送 POST 请求
   * body 参数须为已声明的 interface 实例（ArkTS 严格模式不允许未类型化对象字面量）
   */
  static async post<T>(path: string, body: Object): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const url = `${Constants.BASE_URL}${path}`;
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body),
        connectTimeout: Constants.REQUEST_TIMEOUT,
        readTimeout: Constants.REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 发送 SSE 流式 POST 请求（对话）
   * onEvent 回调在收到每条 SSE 事件时触发
   */
  static async postSSE(
    path: string,
    body: Object,
    onEvent: (event: Record<string, Object>) => void,
    onDone: () => void,
    onError: (err: Error) => void
  ): Promise<void> {
    const httpRequest = http.createHttp();
    try {
      const url = `${Constants.BASE_URL}${path}`;

      // 注册数据接收回调（流式）
      // 注意：使用 HttpClient.decodeArrayBuffer 而非 this.decodeArrayBuffer，
      // 因为 dataReceive 回调中 this 绑定不保证指向 HttpClient 类
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        const text = HttpClient.decodeArrayBuffer(data);
        const lines = text.split('\n\n');
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith('data:')) {
            continue;
          }
          const jsonStr = trimmed.replace(/^data:\s*/, '');
          try {
            const evt = JSON.parse(jsonStr) as Record<string, Object>;
            onEvent(evt);
            if (evt['type'] === 'done') {
              onDone();
            }
          } catch (e) {
            // 忽略不完整的 JSON 分片
          }
        }
      });

      await httpRequest.requestInStream(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        extraData: JSON.stringify(body),
        connectTimeout: Constants.REQUEST_TIMEOUT,
        readTimeout: Constants.REQUEST_TIMEOUT,
      });

      httpRequest.destroy();
    } catch (e) {
      onError(e instanceof Error ? e : new Error(String(e)));
    }
  }

  /**
   * ArrayBuffer 转字符串（UTF-8）
   */
  private static decodeArrayBuffer(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf);
    let result = '';
    for (let i = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i]);
    }
    // 简单解码，完整 UTF-8 应使用 TextDecoder
    try {
      return decodeURIComponent(escape(result));
    } catch (e) {
      return result;
    }
  }
}
