/**
 * EntryAbility — 应用入口 Ability
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { HttpClient } from '../common/HttpClient';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { Course } from '../model/DataModels';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('EntryAbility onCreate');
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');
    this.initializeRepositories().then((): void => {
      this.loadMainPage(windowStage);
      this.probeCloudAgent();
    }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'Local repository initialization failed: %{public}s', error.message);
      this.loadMainPage(windowStage);
    });
  }

  private async initializeRepositories(): Promise<void> {
    const contentInit = LearningContentRepository.initialize(this.context.resourceManager);
    const localInit = LocalLearningRepository.initialize(this.context);
    await contentInit;
    await localInit;
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
      const health = await HttpClient.getHealth();
      AppStorage.setOrCreate<boolean>('cloudAgentReady', health.status === 'ready');
      AppStorage.setOrCreate<number>('cloudAgentCheckedAt', Date.now());
    } catch (error) {
      AppStorage.setOrCreate<boolean>('cloudAgentReady', false);
      AppStorage.setOrCreate<number>('cloudAgentCheckedAt', Date.now());
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
