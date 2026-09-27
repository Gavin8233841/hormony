/**
 * EntryAbility — 应用入口 Ability
 */

import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { HttpClient } from '../common/HttpClient';
import { Course, HealthResponse } from '../model/DataModels';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { SafeAreaInsets } from '../common/SafeArea';
import { ProactiveLearningService } from '../common/ProactiveLearningService';
import { ThemeMode, ThemePreference } from '../common/ThemePreference';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private avoidAreaChangeCallback: ((options: window.AvoidAreaOptions) => void) | null = null;
  private pendingProactiveWant: Want | null = null;
  private pendingProactiveWantSequence: number = 0;
  private proactiveWantSequence: number = 0;
  private repositoriesReady: boolean = false;
  private mainPageReady: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.queueProactiveWant(want);
    AppStorage.setOrCreate<string>('themeMode', ThemeMode.SYSTEM);
    AppStorage.setOrCreate<boolean>('darkMode',
      this.context.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK);
    console.info('EntryAbility onCreate');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const mode = AppStorage.get<string>('themeMode') ?? ThemeMode.SYSTEM;
    AppStorage.setOrCreate<boolean>('darkMode', mode === ThemeMode.DARK ||
      (mode === ThemeMode.SYSTEM && newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK));
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'EntryAbility onNewWant received');
    this.queueProactiveWant(want);
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');
    this.configureSafeArea(windowStage);
    this.startMainPage(windowStage);
  }

  private async configureSafeArea(windowStage: window.WindowStage): Promise<void> {
    SafeAreaInsets.setVp(0, 0);
    try {
      this.mainWindow = await windowStage.getMainWindow();
      this.refreshSafeAreaInsets();
      this.avoidAreaChangeCallback = (_options: window.AvoidAreaOptions): void => {
        this.refreshSafeAreaInsets();
      };
      this.mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Safe area initialization failed: %{public}s', message);
      SafeAreaInsets.setVp(0, 0);
    }
  }

  private refreshSafeAreaInsets(): void {
    if (this.mainWindow === null) {
      SafeAreaInsets.setVp(0, 0);
      return;
    }
    try {
      // 普通窗口已经由系统避让状态栏和手势区，只有沉浸式布局才需页面再加内边距。
      if (!this.mainWindow.getWindowProperties().isLayoutFullScreen) {
        SafeAreaInsets.setVp(0, 0);
        return;
      }
      const systemArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const gestureArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
      const navigationArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const topPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height);
      const bottomPx = Math.max(systemArea.bottomRect.height, gestureArea.bottomRect.height,
        navigationArea.bottomRect.height);
      SafeAreaInsets.setVp(this.pxToVp(topPx), this.pxToVp(bottomPx));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Safe area refresh failed: %{public}s', message);
      SafeAreaInsets.setVp(0, 0);
    }
  }

  private pxToVp(px: number): number {
    try {
      const density = display.getDefaultDisplaySync().densityPixels;
      if (density <= 0) {
        return Math.max(0, px);
      }
      return Math.max(0, px / density);
    } catch (error) {
      return Math.max(0, px);
    }
  }

  private async initializeRepositories(): Promise<void> {
    await LearningContentRepository.initialize(this.context.resourceManager);
    await LocalLearningRepository.initialize(this.context);
    const catalog: Course[] = [
      this.buildCourse('cs101', '数据结构'),
      this.buildCourse('cs102', '操作系统'),
      this.buildCourse('cs103', '计算机网络')
    ];
    await LocalLearningRepository.syncCourseCatalog(catalog);
  }

  private async startMainPage(windowStage: window.WindowStage): Promise<void> {
    let themeMode: ThemeMode = ThemeMode.SYSTEM;
    try {
      themeMode = await ThemePreference.load(this.context);
      AppStorage.setOrCreate<string>('themeMode', themeMode);
      if (themeMode !== ThemeMode.SYSTEM) {
        AppStorage.setOrCreate<boolean>('darkMode', themeMode === ThemeMode.DARK);
      }
    } catch (error) {
      hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Appearance preference could not be read');
    }
    try {
      await this.initializeRepositories();
      this.repositoriesReady = true;
      await this.consumeProactiveWant();
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Local repository initialization failed: %{public}s', message);
    }
    this.loadMainPage(windowStage, themeMode);
    this.probeCloudAgent();
  }

  private queueProactiveWant(want: Want): void {
    const source = this.wantString(want, 'source');
    if (source === undefined || !ProactiveLearningService.isLaunchSource(source)) {
      return;
    }
    this.proactiveWantSequence += 1;
    this.pendingProactiveWant = want;
    this.pendingProactiveWantSequence = this.proactiveWantSequence;
    if (this.repositoriesReady) {
      this.consumeProactiveWant().catch((error: Error): void => {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'Proactive Want validation failed: %{public}s', error.message);
      });
    }
  }

  private async consumeProactiveWant(): Promise<void> {
    const want = this.pendingProactiveWant;
    if (want === null) return;
    const sequence = this.pendingProactiveWantSequence;
    const source = this.wantString(want, 'source');
    const targetPage = this.wantString(want, 'targetPage');
    const courseId = this.wantString(want, 'courseId');
    const topic = this.wantString(want, 'topic');
    const focusTag = this.wantString(want, 'focusTag');
    const taskAction = this.wantString(want, 'taskAction');
    if (source === undefined || targetPage === undefined || courseId === undefined || topic === undefined ||
      focusTag === undefined || taskAction === undefined) {
      this.clearPendingProactiveWant(sequence);
      return;
    }
    const courses = await LocalLearningRepository.getCourses() ?? [];
    if (sequence !== this.pendingProactiveWantSequence) return;
    const launch = ProactiveLearningService.validateLaunch(
      courses, source, targetPage, courseId, topic, focusTag, taskAction);
    if (launch === undefined) {
      this.clearPendingProactiveWant(sequence);
      return;
    }
    this.clearPendingProactiveWant(sequence);
    ProactiveLearningService.requestLaunch(launch);
    if (this.mainPageReady && this.mainWindow !== null) {
      this.navigateProactiveWant(launch.targetPage);
    }
  }

  private navigateProactiveWant(targetPage: string): void {
    const mainWindow = this.mainWindow;
    if (mainWindow === null) return;
    try {
      const appRouter = mainWindow.getUIContext().getRouter();
      if (appRouter.getState().path === 'pages/Index') return;
      const launchVersion = AppStorage.get<number>('proactiveLaunchVersion') ?? 0;
      appRouter.replaceUrl({ url: targetPage }).then((): void => {
        if (targetPage !== 'pages/Index' &&
          launchVersion === AppStorage.get<number>('proactiveLaunchVersion') &&
          targetPage === AppStorage.get<string>('proactiveTargetPage')) {
          AppStorage.setOrCreate<string>('proactiveTargetPage', '');
        }
      }).catch((error: Error): void => {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'Proactive Want navigation failed: %{public}s', error.message);
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Proactive Want navigation unavailable: %{public}s', message);
    }
  }

  private clearPendingProactiveWant(sequence: number): void {
    if (sequence !== this.pendingProactiveWantSequence) return;
    this.pendingProactiveWant = null;
  }

  private wantString(want: Want, key: string): string | undefined {
    const value = want.parameters?.[key];
    return typeof value === 'string' ? value : undefined;
  }

  private buildCourse(id: string, title: string): Course {
    return {
      id: id,
      title: title,
      progress: 0,
      docCount: LearningContentRepository.getKnowledge(id).length,
      topics: LearningContentRepository.getTopics(id)
    };
  }

  private async probeCloudAgent(): Promise<void> {
    AppStorage.setOrCreate<boolean>('cloudAgentReady', false);
    try {
      const health = await HttpClient.get<HealthResponse>(Constants.API_HEALTH);
      AppStorage.setOrCreate<boolean>('cloudAgentReady', health.status === 'ready');
    } catch (error) {
      AppStorage.setOrCreate<boolean>('cloudAgentReady', false);
    }
  }

  private loadMainPage(windowStage: window.WindowStage, themeMode: ThemeMode): void {
    windowStage.loadContent('pages/Index', (err): void => {
      if (err.code) {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'EntryAbility loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      this.mainPageReady = true;
      try {
        ThemePreference.apply(this.context, themeMode);
      } catch (error) {
        hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'Appearance preference could not be applied');
      }
      console.info('Loaded content successfully.');
    });
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== null && this.avoidAreaChangeCallback !== null) {
      try {
        this.mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      } catch (error) {
        const message = error instanceof Error ? error.message : JSON.stringify(error);
        hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'Safe area listener cleanup failed: %{public}s', message);
      }
    }
    this.mainWindow = null;
    this.avoidAreaChangeCallback = null;
    console.info('EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('EntryAbility onForeground');
  }

  onBackground(): void {
    console.info('EntryAbility onBackground');
  }
}
