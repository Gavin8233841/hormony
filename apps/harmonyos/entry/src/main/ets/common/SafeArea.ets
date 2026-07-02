/**
 * SafeAreaInsets — 统一读取窗口避让区后暴露给 ArkUI 页面。
 *
 * Window#getWindowAvoidArea 返回 px；页面布局 padding 使用 vp。
 * 因此 Ability 侧按 display.densityPixels 换算后写入 vp，页面侧只消费 vp。
 */

export class SafeAreaInsets {
  static readonly TOP_VP_KEY: string = 'safeAreaTopVp';
  static readonly BOTTOM_VP_KEY: string = 'safeAreaBottomVp';

  static setVp(topVp: number, bottomVp: number): void {
    AppStorage.setOrCreate<number>(SafeAreaInsets.TOP_VP_KEY, Math.max(0, topVp));
    AppStorage.setOrCreate<number>(SafeAreaInsets.BOTTOM_VP_KEY, Math.max(0, bottomVp));
  }

  static topVp(): number {
    return Math.max(0, AppStorage.get<number>(SafeAreaInsets.TOP_VP_KEY) ?? 0);
  }

  static bottomVp(): number {
    return Math.max(0, AppStorage.get<number>(SafeAreaInsets.BOTTOM_VP_KEY) ?? 0);
  }
}
