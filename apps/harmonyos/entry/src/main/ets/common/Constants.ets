/**
 * 常量定义
 * 修改 BASE_URL 指向你的 Web 后端地址
 */

export class Constants {
  private static themed(light: string, dark: string): string {
    return AppStorage.get<boolean>('darkMode') === true ? dark : light;
  }
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
  static get COLOR_TEXT_PRIMARY(): string { return Constants.themed('#18243d', '#ecf1fa'); }
  static get COLOR_TEXT_SECONDARY(): string { return Constants.themed('#627087', '#b0bcd0'); }
  static get COLOR_TEXT_PLACEHOLDER(): string { return Constants.themed('#627087', '#9cabc3'); }
  static get COLOR_TEXT_TERTIARY(): string { return Constants.themed('#627087', '#8f9db4'); }
  // 品牌与功能色
  static get COLOR_BRAND(): string { return Constants.themed('#365ce6', '#496be8'); }
  static get COLOR_BRAND_TEXT(): string { return Constants.themed('#2948bb', '#a9bcff'); }
  static get COLOR_SUCCESS(): string { return Constants.themed('#18794e', '#94dab4'); }
  static get COLOR_WARNING(): string { return Constants.themed('#9a5b00', '#f2c57c'); }
  static get COLOR_ERROR(): string { return Constants.themed('#b42318', '#ffaaa8'); }
  // 背景色
  static get COLOR_BG_CARD(): string { return Constants.themed('#ffffff', '#192332'); }
  static get COLOR_BG_PAGE(): string { return Constants.themed('#f4f6fa', '#101722'); }
  static get COLOR_BG_PROGRESS_TRACK(): string { return Constants.themed('#dfe6f3', '#344158'); }
  static get COLOR_BG_SKELETON(): string { return Constants.themed('#e8edf5', '#293548'); }
  static get COLOR_BG_TAG(): string { return Constants.themed('#eef2f9', '#253246'); }
  static get COLOR_BORDER(): string { return Constants.themed('#e1e6ef', '#344158'); }
  static get COLOR_SURFACE_TINT(): string { return Constants.themed('#f9fbff', '#222e40'); }
  static get COLOR_NAV_SURFACE(): string { return Constants.themed('#f7f9fd', '#222e40'); }
  static get COLOR_NAV_INACTIVE(): string { return Constants.themed('#627087', '#a8b5ca'); }
  // 浅色背景（带透明度，用于标签底色）
  static get COLOR_BRAND_LIGHT(): string { return Constants.themed('#e9efff', '#283b65'); }
  static get COLOR_CHAT_USER(): string { return Constants.themed('#dfe8ff', '#2c4270'); }
  static get COLOR_ERROR_LIGHT(): string { return Constants.themed('#fff0f1', '#442a35'); }
  static get COLOR_SUCCESS_LIGHT(): string { return Constants.themed('#eaf8ef', '#183a2c'); }
  // 三门课程的识别色；状态仍由独立的成功、警告、错误色表达。
  static get COLOR_COURSE_OS_LIGHT(): string { return Constants.themed('#f0ebfa', '#302a43'); }
  static get COLOR_COURSE_OS_INK(): string { return Constants.themed('#68518b', '#d5c4f5'); }
  static get COLOR_COURSE_NETWORK_LIGHT(): string { return Constants.themed('#e4f3f0', '#1d3837'); }
  static get COLOR_COURSE_NETWORK_INK(): string { return Constants.themed('#226c64', '#a3ddd1'); }
  static get COLOR_HERO_SURFACE(): string { return Constants.themed('#192b4d', '#253556'); }
  static get COLOR_HERO_BADGE(): string { return Constants.themed('#304c78', '#38537e'); }
  static get COLOR_HERO_INSET(): string { return Constants.themed('#eaf0fc', '#283b65'); }
  static get COLOR_HERO_ACCENT(): string { return Constants.themed('#a6e8dc', '#a6e8dc'); }
  // 学习图谱：深色星云画布 + 真实状态色，不用装饰线冒充先修关系。
  static get COLOR_MAP_SURFACE(): string { return Constants.themed('#192b4d', '#202f4d'); }
  static readonly COLOR_MAP_LINE: string = '#34415c';
  static readonly COLOR_MAP_LINE_ACTIVE: string = '#6fb6ff';
  static readonly COLOR_MAP_NODE_IDLE: string = '#70809f';
  static readonly COLOR_MAP_TEXT_MUTED: string = '#c7d4ec';
  static readonly COLOR_MAP_CORE: string = '#ffffff';
  static readonly COLOR_MAP_STAR: string = '#dbeafe';

  // 阴影色（带透明度的黑色）
  static get SHADOW_CARD(): string { return Constants.themed('#10182b4d', '#08000000'); }
  static get SHADOW_CARD_LG(): string { return Constants.themed('#1a182b4d', '#11000000'); }
  // 品牌阴影色（用于AI头像等品牌色元素的阴影）
  static readonly SHADOW_BRAND: string = '#35365ce6';

  // 强调背景上的文字色
  static readonly COLOR_TEXT_ON_GRADIENT: string = '#ffffff';

  // 禁用态按钮颜色（避免默认半透明蒙版，提供明确视觉反馈）
  static get COLOR_BUTTON_DISABLED_BG(): string { return Constants.themed('#e8edf5', '#2a3545'); }
  static get COLOR_BUTTON_DISABLED_TEXT(): string { return Constants.themed('#98a3b5', '#8795ad'); }

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
  static readonly NAV_HEIGHT: number = 60;

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
