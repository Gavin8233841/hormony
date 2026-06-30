/**
 * EntryAbility — 应用入口 Ability
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { HttpClient } from '../common/HttpClient';
import { HealthResponse } from '../model/DataModels';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('EntryAbility onCreate');
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');
    LocalLearningRepository.initialize(this.context).then((): void => {
      this.loadMainPage(windowStage);
      this.probeCloudAgent();
    }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Local repository initialization failed: %{public}s', error.message);
      this.loadMainPage(windowStage);
    });
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
    console.info('EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('EntryAbility onForeground');
  }

  onBackground(): void {
    console.info('EntryAbility onBackground');
  }
}
