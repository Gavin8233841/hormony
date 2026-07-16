import { common, Want, wantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { ProactiveLearningService } from './ProactiveLearningService';

export class LearningReminder {
  static async publishNextTask(context: common.UIAbilityContext): Promise<string> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
      }

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
      return action.title;
    } catch (error) {
      throw new Error('学习提醒创建失败: ' + String(error));
    }
  }
}
