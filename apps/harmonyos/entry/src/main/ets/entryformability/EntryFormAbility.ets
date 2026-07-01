import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { LearningFormUpdater } from '../common/LearningFormUpdater';
import { LocalLearningRepository } from '../common/LocalLearningRepository';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formIdValue = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    if (typeof formIdValue === 'string') {
      this.registerAndRefresh(formIdValue).catch((): void => {});
    }
    return formBindingData.createFormBindingData(LearningFormUpdater.defaultData());
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId).catch((): void => {});
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  onRemoveForm(formId: string): void {
    this.removeForm(formId).catch((): void => {});
  }

  private async refreshForm(formId: string): Promise<void> {
    await LocalLearningRepository.initialize(this.context);
    await LearningFormUpdater.refreshForm(formId);
  }

  private async registerAndRefresh(formId: string): Promise<void> {
    await LocalLearningRepository.initialize(this.context);
    await LocalLearningRepository.registerFormId(formId);
    await LearningFormUpdater.refreshForm(formId);
  }

  private async removeForm(formId: string): Promise<void> {
    await LocalLearningRepository.initialize(this.context);
    await LocalLearningRepository.removeFormId(formId);
  }
}
