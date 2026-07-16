import { formBindingData, formProvider } from '@kit.FormKit';
import { LocalLearningRepository } from './LocalLearningRepository';
import { ProactiveLearningAction, ProactiveLearningService } from './ProactiveLearningService';

export interface LearningFormData {
  kind: string;
  badge: string;
  title: string;
  subtitle: string;
  cta: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
  taskAction: string;
  targetPage: string;
  evidence: string;
  progressText: string;
}

export class LearningFormUpdater {
  static defaultData(): LearningFormData {
    return LearningFormUpdater.buildData(ProactiveLearningService.fallback());
  }

  static async refreshForm(formId: string): Promise<void> {
    try {
      const action = await ProactiveLearningService.resolve();
      const updated = await LearningFormUpdater.updateFormWithAction(formId, action);
      if (!updated) throw new Error('卡片写入失败');
    } catch (error) {
      throw new Error('服务卡片更新失败: ' + String(error));
    }
  }

  static async refreshAll(): Promise<void> {
    const formIds = await LearningFormUpdater.registeredFormIds();
    if (formIds.length === 0) return;
    let action: ProactiveLearningAction;
    try {
      action = await ProactiveLearningService.resolve();
    } catch (_) {
      return;
    }
    await LearningFormUpdater.updateFormsWithAction(formIds, action);
  }

  static async refreshAllWithAction(action: ProactiveLearningAction): Promise<void> {
    const formIds = await LearningFormUpdater.registeredFormIds();
    await LearningFormUpdater.updateFormsWithAction(formIds, action);
  }

  private static async registeredFormIds(): Promise<string[]> {
    try {
      return await LocalLearningRepository.getFormIds();
    } catch (_) {
      return [];
    }
  }

  private static async updateFormsWithAction(formIds: string[], action: ProactiveLearningAction): Promise<void> {
    for (const formId of formIds) {
      await LearningFormUpdater.updateFormWithAction(formId, action);
    }
  }

  private static async updateFormWithAction(formId: string, action: ProactiveLearningAction): Promise<boolean> {
    try {
      await formProvider.updateForm(formId,
        formBindingData.createFormBindingData(LearningFormUpdater.buildData(action)));
      return true;
    } catch (_) {
      return false;
    }
  }

  private static buildData(action: ProactiveLearningAction): LearningFormData {
    return {
      kind: action.kind,
      badge: action.badge,
      title: action.title,
      subtitle: action.subtitle,
      cta: action.cta,
      courseId: action.courseId,
      courseTitle: action.courseTitle,
      topic: action.topic,
      focusTag: action.focusTag,
      taskAction: action.taskAction,
      targetPage: action.targetPage,
      evidence: action.evidence,
      progressText: action.progressText
    };
  }
}
