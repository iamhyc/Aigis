import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { AIGIS_PREF_NAME, AIGIS_PREF_WIDGET,
    PREF_DEC_MASTER_KEY,
    PREF_ICON_PACKS, PREF_KEY_ITEMS, PREF_KEY_SECRETS,
    PREF_MASTER_KEY } from '../common/conts';
import { PreferencesManager } from '../entryability/EntryAbility';
import { IconPackStore, MasterKeyInfo, OTPItemInfo, SecretSchema } from '../common/schema';
import { EVENT_CODE_REQUEST } from '../common/events';
import { TimedOTPSchema } from '../crypto/otpUtils';
import { BusinessError } from '@kit.BasicServicesKit';

export default class EntryFormAbility extends FormExtensionAbility {
    private aigisPref?: preferences.Preferences;
    private widgetPref?: preferences.Preferences;
    private aigisManager?: PreferencesManager;

    private AIGIS_PREF_LISTENER = () => {
        preferences.removePreferencesFromCacheSync(this.context, {name:AIGIS_PREF_NAME});
        this.aigisPref?.off('multiProcessChange');
        this.aigisPref = undefined;
        //
        this.aigisPref = preferences.getPreferencesSync(this.context, {name:AIGIS_PREF_NAME});
        this.aigisPref.on('multiProcessChange', this.AIGIS_PREF_LISTENER);
        this.initAigisManager(this.aigisPref);
    };
    private WIDGET_PREF_LISTENER = () => {
        preferences.removePreferencesFromCacheSync(this.context, {name:AIGIS_PREF_WIDGET});
        this.widgetPref?.off('multiProcessChange', this.WIDGET_PREF_LISTENER);
        this.widgetPref = undefined;
        //
        this.widgetPref = preferences.getPreferencesSync(this.context, {name:AIGIS_PREF_WIDGET});
        this.widgetPref.on('multiProcessChange', this.WIDGET_PREF_LISTENER);
    };

    private initAigisManager(aigisPref: preferences.Preferences) {
        const items = aigisPref.getSync(PREF_KEY_ITEMS, []) as OTPItemInfo[];
        const secrets = aigisPref.getSync(PREF_KEY_SECRETS, []) as SecretSchema[];
        const icons = aigisPref.getSync(PREF_ICON_PACKS, []) as IconPackStore[];
        const encMasterKeyInfo = aigisPref.getSync(PREF_MASTER_KEY, {}) as MasterKeyInfo;
        const decMasterKeyInfo = aigisPref.getSync(PREF_DEC_MASTER_KEY, {}) as MasterKeyInfo;
        this.aigisManager = new PreferencesManager(
            items, secrets, icons, encMasterKeyInfo, decMasterKeyInfo,
        );
    }

    private ensureInitialization() {
        if (this.widgetPref===undefined) { this.WIDGET_PREF_LISTENER(); }
        if (this.aigisPref===undefined) { this.AIGIS_PREF_LISTENER(); }
    }

    private async updateFormBindingData(formId: string): Promise<void> {
        this.ensureInitialization();
        if (this.widgetPref===undefined) { return; }
        //
        const keyAlias = this.widgetPref.getSync(formId, '') as string;
        if (keyAlias && this.aigisManager) {
            const item = this.aigisManager.items.find(x => x.keyAlias===keyAlias);
            if (item) {
                // check code freshness
                if ((item.schema as TimedOTPSchema).period) {
                    const period = (item.schema as TimedOTPSchema).period * 1000;
                    const lastUpdated = item.code.timestamp - item.code.timestamp % period;
                    if (Date.now() - lastUpdated > period) {
                        const newCode = await this.aigisManager.requestCodeUpdate(keyAlias, undefined, false, this.aigisPref);
                        if (newCode) {
                            item.code = newCode;
                        }
                    }
                }
                //
                const bindingData = formBindingData.createFormBindingData({
                    'keyAlias': keyAlias,
                    'itemInfo': item,
                });
                try {
                    await formProvider.updateForm(formId, bindingData);
                    console.log(`Sent: ${item.code.code}, ${formId}, ${keyAlias}`)
                } catch (err) {
                    console.error('updateForm Failed: ', (err as BusinessError).message);
                }
            }
        }
    }

    onStop() {
        this.aigisPref?.off('multiProcessChange', this.AIGIS_PREF_LISTENER);
        this.widgetPref?.off('multiProcessChange', this.WIDGET_PREF_LISTENER);
    }

    onAddForm(want: Want) {
        this.ensureInitialization();
        //
        if (want.parameters && this.widgetPref) {
            const formId = want.parameters[formInfo.FormParam.IDENTITY_KEY].toString();
            const isTempCard = want.parameters[formInfo.FormParam.TEMPORARY_KEY] as boolean;

            if (isTempCard === false) {
                console.log(`onUpdateForm: updateFormBindingData ${formId}`)
                this.updateFormBindingData(formId);
            }
        }
        return formBindingData.createFormBindingData({});
    }

    onRemoveForm(formId: string) {
        this.ensureInitialization();
        if (this.widgetPref===undefined) { return; }
        //
        try {
            this.widgetPref.deleteSync(formId);
            this.widgetPref.flush();
        } catch (e) {
            console.error(`Form does not exist: ${formId}.`)
        }
    }

    onCastToNormalForm(formId: string) {
        this.ensureInitialization();
        if (this.widgetPref===undefined) { return; }
        //
        this.widgetPref.putSync(formId, '');
        this.widgetPref.flush();
    }

    onUpdateForm(formId: string) {
        console.log(`onUpdateForm: updateFormBindingData ${formId}`)
        this.updateFormBindingData(formId);
    }

    onFormEvent(formId: string, message: string) {
        this.ensureInitialization();
        if (this.widgetPref===undefined) { return; }
        //
        message = JSON.parse(message) as string;
        if (message===EVENT_CODE_REQUEST) {
            this.updateFormBindingData(formId);
        } else {
            console.error(`"${message}" not supported.`)
        }
    }

    onAcquireFormState(_want: Want) {
        return formInfo.FormState.READY;
    }
};