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

export interface LearningFormRefreshResult {
  registered: number;
  updated: number;
  failed: number;
  lookupFailed: boolean;
}

export class LearningFormUpdater {
  private static formUpdateQueue: Promise<void> = Promise.resolve();

  static defaultData(): LearningFormData {
    return LearningFormUpdater.buildData(ProactiveLearningService.fallback());
  }

  static async refreshForm(formId: string): Promise<void> {
    try {
      await LearningFormUpdater.enqueueUpdate(async (): Promise<void> => {
        const action = await ProactiveLearningService.resolve();
        await LearningFormUpdater.updateFormWithAction(formId, action);
      });
    } catch (_) {
      throw new Error('服务卡片更新失败，请稍后重试');
    }
  }

  static async refreshAll(): Promise<void> {
    try {
      await LearningFormUpdater.enqueueUpdate(async (): Promise<void> => {
        const formIds = await LocalLearningRepository.getFormIds();
        if (formIds.length === 0) return;
        const action = await ProactiveLearningService.resolve();
        await LearningFormUpdater.updateFormsWithAction(formIds, action);
      });
    } catch (_) {
    }
  }

  static async refreshAllWithAction(action: ProactiveLearningAction): Promise<LearningFormRefreshResult> {
    let result: LearningFormRefreshResult = LearningFormUpdater.emptyRefreshResult();
    await LearningFormUpdater.enqueueUpdate(async (): Promise<void> => {
      let formIds: string[];
      try {
        formIds = await LocalLearningRepository.getFormIds();
      } catch (_) {
        result = {
          registered: 0,
          updated: 0,
          failed: 0,
          lookupFailed: true
        };
        return;
      }
      result = await LearningFormUpdater.updateFormsWithAction(formIds, action);
    });
    return result;
  }

  private static enqueueUpdate(operation: () => Promise<void>): Promise<void> {
    const queued = LearningFormUpdater.formUpdateQueue.then(operation);
    LearningFormUpdater.formUpdateQueue = queued.catch((): void => {});
    return queued;
  }

  private static async updateFormsWithAction(formIds: string[],
    action: ProactiveLearningAction): Promise<LearningFormRefreshResult> {
    let updated: number = 0;
    let failures: number = 0;
    for (const formId of formIds) {
      try {
        await LearningFormUpdater.updateFormWithAction(formId, action);
        updated += 1;
      } catch (_) {
        failures += 1;
      }
    }
    return {
      registered: formIds.length,
      updated: updated,
      failed: failures,
      lookupFailed: false
    };
  }

  private static async updateFormWithAction(formId: string, action: ProactiveLearningAction): Promise<void> {
    try {
      await formProvider.updateForm(formId,
        formBindingData.createFormBindingData(LearningFormUpdater.buildData(action)));
    } catch (_) {
      throw new Error('服务卡片写入失败');
    }
  }

  private static emptyRefreshResult(): LearningFormRefreshResult {
    return {
      registered: 0,
      updated: 0,
      failed: 0,
      lookupFailed: false
    };
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
