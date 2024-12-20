import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';

export default class EntryFormAbility extends FormExtensionAbility {
    onAddForm(want: Want) {
        // Called to return a FormBindingData object.
        if (want.parameters) {
            const formId = want.parameters[formInfo.FormParam.IDENTITY_KEY].toString();
            const isTempCard = want.parameters[formInfo.FormParam.TEMPORARY_KEY] as boolean;
            if (isTempCard === false) {

            }
        }
        let formData: Record<string, Object> = {};
        return formBindingData.createFormBindingData(formData);
    }

    onCastToNormalForm(formId: string) {
        // Called when the form provider is notified that a temporary form is successfully
        // converted to a normal form.
    }

    onUpdateForm(formId: string) {
        // Called to notify the form provider to update a specified form.
    }

    onFormEvent(formId: string, message: string) {
        // Called when a specified message event defined by the form provider is triggered.
    }

    onRemoveForm(formId: string) {
        // Called to notify the form provider that a specified form has been destroyed.
    }

    onAcquireFormState(want: Want) {
        // Called to return a {@link FormState} object.
        return formInfo.FormState.READY;
    }
};