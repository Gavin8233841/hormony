/**
 * EntryAbility — 应用入口 Ability
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { HttpClient } from '../common/HttpClient';
import { HealthResponse } from '../model/DataModels';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { Course } from '../model/DataModels';
import { SafeAreaInsets } from '../common/SafeArea';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private avoidAreaChangeCallback: ((options: window.AvoidAreaOptions) => void) | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('EntryAbility onCreate');
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');
    this.configureSafeArea(windowStage);
    this.initializeRepositories().then((): void => {
      this.loadMainPage(windowStage);
      this.probeCloudAgent();
    }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Local repository initialization failed: %{public}s', error.message);
      this.loadMainPage(windowStage);
    });
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

  private loadMainPage(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err): void => {
      if (err.code) {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'EntryAbility loadContent failed: %{public}s', JSON.stringify(err));
        return;
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
