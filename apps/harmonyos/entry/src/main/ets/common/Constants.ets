/**
 * 常量定义
 * 修改 BASE_URL 指向你的 Web 后端地址
 */

export class Constants {
  // Web 后端地址
  // 模拟器访问宿主机：http://10.0.2.2:3000
  // 真机调试：http://<电脑局域网IP>:3000
  static readonly BASE_URL: string = 'http://10.0.2.2:3000';

  // API 路径
  static readonly API_CHAT: string = '/api/chat';
  static readonly API_PROFILE: string = '/api/profile';
  static readonly API_COURSES: string = '/api/courses';
  static readonly API_PLAN: string = '/api/plan';
  static readonly API_QUIZ: string = '/api/quiz';
  static readonly API_SAFETY: string = '/api/safety-review';
  static readonly API_KNOWLEDGE_SEARCH: string = '/api/knowledge/search';

  // 演示用户
  static readonly DEMO_USER_ID: string = 'demo';

  // 请求超时（毫秒）
  static readonly REQUEST_TIMEOUT: number = 30000;
}
