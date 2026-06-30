import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { LocalLearningRepository } from './LocalLearningRepository';
import { PlanTask, StudyPlan } from '../model/DataModels';

export class LearningReminder {
  static async publishNextTask(context: common.UIAbilityContext): Promise<string> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
      }

      const plan: StudyPlan | null = await LocalLearningRepository.getPlan();
      const pending: PlanTask[] = plan === null ? [] :
        plan.tasks.filter((task: PlanTask): boolean => task.done !== true);
      const title = pending.length > 0 ? pending[0].title : '制定今天的学习计划';
      const text = pending.length > 0 ?
        pending[0].estimatedMin + ' 分钟 · 完成后会更新本地进度' :
        '打开鸿学伴，让真实 AI 根据你的目标生成计划';
      const request: notificationManager.NotificationRequest = {
        id: 20260701,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '鸿学伴 · 今日学习',
            text: title,
            additionalText: text
          }
        }
      };
      await notificationManager.publish(request);
      return title;
    } catch (error) {
      throw new Error('学习提醒创建失败: ' + String(error));
    }
  }
}
