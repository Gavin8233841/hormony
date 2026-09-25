/**
 * 常量定义
 * 修改 BASE_URL 指向你的 Web 后端地址
 */

export class Constants {
  // Web 后端地址
  // 发布配置必须指向公网无状态网关，不得依赖开发电脑或本地代理。
  static readonly BASE_URL: string = 'https://hormony-ruddy.vercel.app';
  // 模拟器无法直连 Vercel 时，经宿主机固定目标网关转发；不携带模型密钥。
  static readonly SIMULATOR_GATEWAY_URL: string = 'http://10.0.2.2:3001';
  static readonly API_BASE_URLS: string[] = [Constants.BASE_URL, Constants.SIMULATOR_GATEWAY_URL];

  // API 路径
  static readonly API_CHAT: string = '/api/chat';
  static readonly API_PROFILE: string = '/api/profile';
  static readonly API_COURSES: string = '/api/courses';
  static readonly API_PLAN: string = '/api/plan';
  static readonly API_PLAN_SAVE: string = '/api/plan/save';
  static readonly API_QUIZ: string = '/api/quiz';
  static readonly API_QUIZ_SUBMIT: string = '/api/quiz/submit';
  static readonly API_SAFETY: string = '/api/safety-review';
  static readonly API_KNOWLEDGE_SEARCH: string = '/api/knowledge/search';
  static readonly API_HEALTH: string = '/api/health';

  // 演示用户
  static readonly DEMO_USER_ID: string = 'demo';

  // 请求超时（毫秒）
  static readonly REQUEST_TIMEOUT: number = 30000;
  static readonly CONNECT_TIMEOUT: number = 8000;
  static readonly MODEL_REQUEST_TIMEOUT: number = 120000;
  // SSE 流式请求超时（毫秒）——多 Agent 编排可能需要 30-40s，设 90s 留足余量
  static readonly SSE_TIMEOUT: number = 90000;

  // 颜色常量（统一收口，禁止页面内硬编码颜色）
  // 文字色
  static readonly COLOR_TEXT_PRIMARY: string = '#243d3a';
  static readonly COLOR_TEXT_SECONDARY: string = '#5c6d68';
  static readonly COLOR_TEXT_PLACEHOLDER: string = '#5c6d68';
  static readonly COLOR_TEXT_TERTIARY: string = '#50645e';
  // 品牌与功能色
  static readonly COLOR_BRAND: string = '#2d665b';
  static readonly COLOR_BRAND_TEXT: string = '#23594f';
  static readonly COLOR_SUCCESS: string = '#18794e';
  static readonly COLOR_WARNING: string = '#9a5b00';
  static readonly COLOR_ERROR: string = '#b42318';
  // 背景色
  static readonly COLOR_BG_CARD: string = '#fdfbf5';
  static readonly COLOR_BG_PAGE: string = '#f3f1ea';
  static readonly COLOR_BG_PROGRESS_TRACK: string = '#d8e2da';
  static readonly COLOR_BG_SKELETON: string = '#e8ebe5';
  static readonly COLOR_BG_TAG: string = '#eaf0e9';
  static readonly COLOR_BORDER: string = '#dfe5dc';
  static readonly COLOR_SURFACE_TINT: string = '#faf8f2';
  static readonly COLOR_NAV_SURFACE: string = '#fdfbf5';
  static readonly COLOR_NAV_INACTIVE: string = '#64716b';
  // 浅色背景（带透明度，用于标签底色）
  static readonly COLOR_BRAND_LIGHT: string = '#e3eee7';
  static readonly COLOR_CHAT_USER: string = '#e8f1e9';
  static readonly COLOR_ERROR_LIGHT: string = '#fff0f1';
  static readonly COLOR_SUCCESS_LIGHT: string = '#eaf8ef';
  // 三门课程的识别色；状态仍由独立的成功、警告、错误色表达。
  static readonly COLOR_COURSE_OS_LIGHT: string = '#e5dfec';
  static readonly COLOR_COURSE_OS_INK: string = '#62537c';
  static readonly COLOR_COURSE_NETWORK_LIGHT: string = '#dde7df';
  static readonly COLOR_COURSE_NETWORK_INK: string = '#286b63';
  static readonly COLOR_HERO_SURFACE: string = '#203e39';
  static readonly COLOR_HERO_BADGE: string = '#426257';
  static readonly COLOR_HERO_INSET: string = '#ede7d9';
  static readonly COLOR_HERO_ACCENT: string = '#f1d5bc';
  // 学习图谱：深色星云画布 + 真实状态色，不用装饰线冒充先修关系。
  static readonly COLOR_MAP_SURFACE: string = '#193f3b';
  static readonly COLOR_MAP_LINE: string = '#34415c';
  static readonly COLOR_MAP_LINE_ACTIVE: string = '#6fb6ff';
  static readonly COLOR_MAP_NODE_IDLE: string = '#70809f';
  static readonly COLOR_MAP_TEXT_MUTED: string = '#c2d8ce';
  static readonly COLOR_MAP_CORE: string = '#f8f6ef';
  static readonly COLOR_MAP_STAR: string = '#dbeafe';

  // 阴影色（带透明度的黑色）
  static readonly SHADOW_CARD: string = '#120f2748';
  static readonly SHADOW_CARD_LG: string = '#1a0f2748';
  // 品牌阴影色（用于AI头像等品牌色元素的阴影）
  static readonly SHADOW_BRAND: string = '#352d665b';

  // 强调背景上的文字色
  static readonly COLOR_TEXT_ON_GRADIENT: string = '#ffffff';

  // 禁用态按钮颜色（避免默认半透明蒙版，提供明确视觉反馈）
  static readonly COLOR_BUTTON_DISABLED_BG: string = '#e8edf5';
  static readonly COLOR_BUTTON_DISABLED_TEXT: string = '#98a3b5';

  // 动画时长（毫秒）
  static readonly ANIM_FAST: number = 160;
  static readonly ANIM_NORMAL: number = 220;

  // 圆角
  static readonly RADIUS_SM: number = 8;
  static readonly RADIUS_MD: number = 12;
  static readonly RADIUS_LG: number = 16;
  static readonly RADIUS_XL: number = 20;

  // 主界面排版：四个入口共用一套留白与字号。
  static readonly PAGE_GUTTER: number = 20;
  static readonly PAGE_TITLE_SIZE: number = 26;
  static readonly PAGE_SECTION_SIZE: number = 18;
  static readonly PAGE_BODY_SIZE: number = 15;
  static readonly NAV_HEIGHT: number = 64;

  // hilog 日志
  static readonly HILOG_DOMAIN: number = 0x0001;
  static readonly HILOG_TAG: string = 'HongXueBan';

  static courseTint(courseId: string): string {
    if (courseId === 'cs102') return Constants.COLOR_COURSE_OS_LIGHT;
    if (courseId === 'cs103') return Constants.COLOR_COURSE_NETWORK_LIGHT;
    return Constants.COLOR_BRAND_LIGHT;
  }

  static courseInk(courseId: string): string {
    if (courseId === 'cs102') return Constants.COLOR_COURSE_OS_INK;
    if (courseId === 'cs103') return Constants.COLOR_COURSE_NETWORK_INK;
    return Constants.COLOR_BRAND_TEXT;
  }
}
