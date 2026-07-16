import { common, Want, wantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { ProactiveLearningAction, ProactiveLearningService } from './ProactiveLearningService';

export class LearningReminder {
  static async publishNextTask(context: common.UIAbilityContext): Promise<ProactiveLearningAction> {
    await LearningReminder.ensureNotificationEnabled(context);
    try {
      const action = await ProactiveLearningService.resolve();
      const targetWant: Want = {
        bundleName: 'com.c4ai.hormony',
        abilityName: 'EntryAbility',
        parameters: {
          source: 'proactive_learning_reminder',
          targetPage: action.targetPage,
          courseId: action.courseId,
          courseTitle: action.courseTitle,
          topic: action.topic,
          focusTag: action.focusTag,
          taskAction: action.taskAction
        }
      };
      const info: wantAgent.WantAgentInfo = {
        wants: [targetWant],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 20260701,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const actionAgent = await wantAgent.getWantAgent(info);
      const request: notificationManager.NotificationRequest = {
        id: 20260701,
        notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
        wantAgent: actionAgent,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '鸿学伴 · ' + action.badge,
            text: action.title,
            additionalText: action.progressText + ' · 点击直达'
          }
        }
      };
      await notificationManager.publish(request);
      return action;
    } catch (_) {
      throw new Error('系统学习提醒发布失败，请稍后重试');
    }
  }

  private static async ensureNotificationEnabled(context: common.UIAbilityContext): Promise<void> {
    let enabled: boolean = false;
    try {
      enabled = await notificationManager.isNotificationEnabled();
    } catch (_) {
      throw new Error('暂时无法检查通知权限，请稍后重试');
    }
    if (enabled) return;

    try {
      await notificationManager.requestEnableNotification(context);
    } catch (_) {
    }
    try {
      enabled = await notificationManager.isNotificationEnabled();
    } catch (_) {
      throw new Error('暂时无法检查通知权限，请稍后重试');
    }
    if (!enabled) {
      throw new Error('通知权限未开启，请在系统通知设置中允许后重试');
    }
  }
}
