import { formBindingData, formProvider } from '@kit.FormKit';
import { LocalLearningRepository } from './LocalLearningRepository';
import { PlanTask, StudyPlan } from '../model/DataModels';

export interface LearningFormData {
  taskTitle: string;
  taskMeta: string;
  progressText: string;
}

export class LearningFormUpdater {
  static defaultData(): LearningFormData {
    return {
      taskTitle: '打开鸿学伴制定今日计划',
      taskMeta: '计划保存在本机',
      progressText: '今日待开始'
    };
  }

  static async refreshForm(formId: string): Promise<void> {
    try {
      const plan = await LocalLearningRepository.getPlan();
      await formProvider.updateForm(formId,
        formBindingData.createFormBindingData(LearningFormUpdater.buildData(plan)));
    } catch (error) {
      throw new Error('服务卡片更新失败: ' + String(error));
    }
  }

  static async refreshAll(): Promise<void> {
    let formIds: string[] = [];
    try {
      formIds = await LocalLearningRepository.getFormIds();
    } catch (_) {
      return;
    }
    for (const formId of formIds) {
      try {
        await LearningFormUpdater.refreshForm(formId);
      } catch (_) {
      }
    }
  }

  private static buildData(plan: StudyPlan | null): LearningFormData {
    if (plan === null || plan.tasks.length === 0) return LearningFormUpdater.defaultData();
    const now = new Date();
    const month = (now.getMonth() + 1).toString();
    const day = now.getDate().toString();
    const today = now.getFullYear().toString() + '-' + (month.length === 1 ? '0' + month : month) + '-' +
      (day.length === 1 ? '0' + day : day);
    const todayTasks = plan.tasks.filter((task: PlanTask): boolean => task.date === today);
    if (todayTasks.length === 0) {
      return { taskTitle: '今天没有安排', taskMeta: plan.goal, progressText: '查看完整计划' };
    }
    const pending = todayTasks.filter((task: PlanTask): boolean => task.done !== true);
    if (pending.length === 0) {
      return {
        taskTitle: '今天的任务已全部完成',
        taskMeta: plan.goal,
        progressText: todayTasks.length.toString() + '/' + todayTasks.length.toString() + ' 已完成'
      };
    }
    return {
      taskTitle: pending[0].title,
      taskMeta: pending[0].estimatedMin.toString() + ' 分钟 · ' + plan.goal,
      progressText: (todayTasks.length - pending.length).toString() + '/' + todayTasks.length.toString() + ' 已完成'
    };
  }
}
