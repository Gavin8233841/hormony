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
      await formProvider.updateForm(formId,
        formBindingData.createFormBindingData(LearningFormUpdater.buildData(action)));
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
