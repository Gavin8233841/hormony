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

  // 调试开关：true 时网络失败回退演示数据；false 时显示真实错误不回退
  static readonly __DEBUG__: boolean = true;

  // 请求超时（毫秒）
  static readonly REQUEST_TIMEOUT: number = 30000;

  // 颜色常量（统一收口，禁止页面内硬编码颜色）
  // 文字色
  static readonly COLOR_TEXT_PRIMARY: string = '#1a1a1a';
  static readonly COLOR_TEXT_SECONDARY: string = '#929292';
  static readonly COLOR_TEXT_PLACEHOLDER: string = '#cccccc';
  static readonly COLOR_TEXT_TERTIARY: string = '#666666';
  // 品牌与功能色
  static readonly COLOR_BRAND: string = '#0a59f7';
  static readonly COLOR_SUCCESS: string = '#4caf50';
  static readonly COLOR_WARNING: string = '#ff9800';
  static readonly COLOR_ERROR: string = '#e53935';
  // 强调色（功能入口左边框）
  static readonly COLOR_ACCENT_PURPLE: string = '#9c27b0';
  static readonly COLOR_ACCENT_CYAN: string = '#00bcd4';
  // 背景色
  static readonly COLOR_BG_CARD: string = '#ffffff';
  static readonly COLOR_BG_PAGE: string = '#f5f6f8';
  static readonly COLOR_BG_PROGRESS_TRACK: string = '#e8e8e8';
  static readonly COLOR_BG_TAG: string = '#f0f0f2';
  static readonly COLOR_BG_TASK_TAG: string = '#f0f1f3';
  // 浅色背景（带透明度，用于标签底色）
  static readonly COLOR_BRAND_LIGHT: string = '#0a59f720';
  static readonly COLOR_ERROR_LIGHT: string = '#e5393520';
  static readonly COLOR_SUCCESS_LIGHT: string = '#4caf5020';

  // 阴影色（带透明度的黑色）
  static readonly SHADOW_CARD: string = '#0a000014';
  static readonly SHADOW_CARD_LG: string = '#1200001a';

  // 渐变色组（用于头部背景）
  static readonly GRADIENT_HEADER_COLORS: [ResourceColor, ResourceColor] = ['#0a59f7', '#3d7fef'];

  // 动画时长（毫秒）
  static readonly ANIM_FAST: number = 200;
  static readonly ANIM_NORMAL: number = 350;
  static readonly ANIM_SLOW: number = 500;

  // 圆角
  static readonly RADIUS_SM: number = 8;
  static readonly RADIUS_MD: number = 12;
  static readonly RADIUS_LG: number = 16;
  static readonly RADIUS_XL: number = 20;

  // hilog 日志
  static readonly HILOG_DOMAIN: number = 0x0001;
  static readonly HILOG_TAG: string = 'HongXueBan';
}
