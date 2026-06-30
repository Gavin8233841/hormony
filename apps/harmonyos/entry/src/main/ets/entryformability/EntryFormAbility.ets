import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { PlanTask, StudyPlan } from '../model/DataModels';

interface LearningFormData {
  taskTitle: string;
  taskMeta: string;
  progressText: string;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const data = this.defaultData();
    const formIdValue = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    if (typeof formIdValue === 'string') {
      this.refreshForm(formIdValue).catch((): void => {});
    }
    return formBindingData.createFormBindingData(data);
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId).catch((): void => {});
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private defaultData(): LearningFormData {
    return {
      taskTitle: '打开鸿学伴制定今日计划',
      taskMeta: '计划保存在本机',
      progressText: '今日待开始'
    };
  }

  private async refreshForm(formId: string): Promise<void> {
    try {
      await LocalLearningRepository.initialize(this.context);
      const plan: StudyPlan | null = await LocalLearningRepository.getPlan();
      const data: LearningFormData = this.buildData(plan);
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (error) {
      throw new Error('服务卡片更新失败: ' + String(error));
    }
  }

  private buildData(plan: StudyPlan | null): LearningFormData {
    if (plan === null || plan.tasks.length === 0) return this.defaultData();
    const pending: PlanTask[] = plan.tasks.filter((task: PlanTask): boolean => task.done !== true);
    if (pending.length === 0) {
      return {
        taskTitle: '今天的任务已全部完成',
        taskMeta: plan.goal,
        progressText: plan.tasks.length + '/' + plan.tasks.length + ' 已完成'
      };
    }
    const completed = plan.tasks.length - pending.length;
    return {
      taskTitle: pending[0].title,
      taskMeta: pending[0].estimatedMin + ' 分钟 · ' + plan.goal,
      progressText: completed + '/' + plan.tasks.length + ' 已完成'
    };
  }
}
