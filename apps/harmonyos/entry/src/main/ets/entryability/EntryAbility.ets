/**
 * EntryAbility — 应用入口 Ability
 */

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onCreate(want, launchParam) {
    console.info('EntryAbility onCreate');
  }

  onDestroy() {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('EntryAbility onWindowStageCreate');
    // 默认加载首页（仪表盘）
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error(`Failed to load content. ${JSON.stringify(err)}`);
        return;
      }
      console.info('Loaded content successfully.');
    });
  }

  onWindowStageDestroy() {
    console.info('EntryAbility onWindowStageDestroy');
  }

  onForeground() {
    console.info('EntryAbility onForeground');
  }

  onBackground() {
    console.info('EntryAbility onBackground');
  }
}
