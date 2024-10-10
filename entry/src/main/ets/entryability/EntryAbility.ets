import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OTP, OTPSchema, parseURI } from '../crypto/otpUtils'
import { EVENT_CODE_REQUEST, CodeRequestSchema, CodeResponseSchema, OTPItemInfo,
    EVENT_UPDATE_ITEM,
    UpdateRequestSchema} from '../common/schema'
import { shallowCopy } from '../common/utils';
import { PREF_KEY_SECRETS } from '../common/conts';
import { PREF_KEY_ITEMS } from '../common/conts';

const AIGIS_PREF_NAME = 'aigis-pref';

interface SecretSchema {
    keyAlias: string,
    secret: string
}

class PreferencesManager {
    private _instances: Map<string, OTP>;
    private _secrets: SecretSchema[];
    private _items: OTPItemInfo[];

    constructor(items: OTPItemInfo[], secrets: SecretSchema[]) {
        this._items = items;
        this._secrets = secrets;
        this._instances = new Map();
    }

    get items() {
        return this._items;
    }

    getOtpInstance(keyAlias: string): OTP {
        let otp = this._instances.get(keyAlias);
        if (otp===undefined) {
            const schema = this._items.find(x => x.keyAlias===keyAlias)?.schema;
            const secret = this._secrets.find(x => x.keyAlias===keyAlias)?.secret;
            if (schema===undefined) {
                throw Error(`"${keyAlias}" not found in local manager.`);
            }

            let schema_tmp = shallowCopy(schema) as OTPSchema;
            schema_tmp.secret = secret;
            otp = OTP.fromSchema(schema_tmp);
        }
        return otp;
    }

    async requestCodeUpdate(keyAlias: string): Promise<boolean> {
        const item = this._items.find(x => x.keyAlias===keyAlias);
        if (item) {
            const otp = this.getOtpInstance(keyAlias);
            item.code = {
                timestamp: Date.now(),
                code: await otp.generateOTP(),
            }
            return true;
        } else {
            return false;
        }
    }

    updatePreferenceItem(uri: string) {
        const args = parseURI(uri);
        const otp = OTP.fromArguments(args);
        const secret = args.get('secret')!;

        const oldItem = this._items.find(x => (otp as OTP).keyAlias===x.keyAlias);
        const oldSecret = this._secrets.find(x => (otp as OTP).keyAlias===x.keyAlias);

        if (oldItem!==undefined && oldSecret!==undefined) {
            oldItem.schema = (otp as OTP).schema;
            oldSecret.secret = secret;
            // update new instances
            const keyAlias = oldItem.keyAlias;
            this._instances.delete(keyAlias);
            this.requestCodeUpdate(keyAlias);
        } else {
            this.appendPreferenceItem(otp as OTP, secret);
        }
    }

    private appendPreferenceItem(otp: OTP, secret: string) {
        const keyAlias = otp.keyAlias;
        const schema = otp.schema;

        // find issuer icon
        const issuerKey = otp.schema.issuer.toLowerCase();
        const icon = `issuer-icons/SVG/${issuerKey}.svg`;

        const code: CodeResponseSchema = {timestamp:0, code:'000000'};
        this._items.push({keyAlias, icon, code, schema});
        this._secrets.push({keyAlias, secret});
        this._instances.set(keyAlias, this.getOtpInstance(keyAlias));
    }

    persists(dataPreferences: preferences.Preferences) {
        dataPreferences!.putSync(PREF_KEY_ITEMS, this._items);
        dataPreferences!.putSync(PREF_KEY_SECRETS, this._secrets);
        dataPreferences!.flush();
    }
}

export default class EntryAbility extends UIAbility {
    private dataPreferences?: preferences.Preferences;
    private localStorage: LocalStorage = new LocalStorage();
    private instPreferences?: PreferencesManager;

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    }

    onDestroy(): void {
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    }

    onWindowStageCreate(windowStage: window.WindowStage): void {
        // Main window is created, set main page for this ability
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
        const mainWindow = windowStage.getMainWindowSync();
        mainWindow.setWindowPrivacyMode(true);

        preferences.getPreferences(this.context, AIGIS_PREF_NAME)
            .then((pref: preferences.Preferences) => {
                this.dataPreferences = pref;
                this.instPreferences = new PreferencesManager(
                  this.dataPreferences.getSync(PREF_KEY_ITEMS, []) as OTPItemInfo[],
                  this.dataPreferences.getSync(PREF_KEY_SECRETS, []) as SecretSchema[],
                );
                this.localStorage.setAndProp(PREF_KEY_ITEMS, this.instPreferences.items);

                // register event handler
                this.context.eventHub.on(EVENT_CODE_REQUEST, async (data: CodeRequestSchema) => {
                    if (this.instPreferences) {
                        const res = await this.instPreferences.requestCodeUpdate(data.keyAlias);
                        if (res) {
                            this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
                        }
                    }
                });
                this.context.eventHub.on(EVENT_UPDATE_ITEM, (data: UpdateRequestSchema) => {
                    if (this.instPreferences) {
                        // update local preferences
                        this.instPreferences.updatePreferenceItem(data.uri);
                        // update persist preferences
                        this.instPreferences.persists(this.dataPreferences!);
                        // propagate updated items
                        this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
                    }
                });

                // init index page
                windowStage.loadContent('pages/Index', this.localStorage)
                    .then(() => {
                        hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
                    })
                    .catch((err: BusinessError) => {
                        if (err.code) {
                            hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
                            return;
                        }
                    });
            })
            .catch((err: BusinessError) => {
                console.error("Failed to get preferences. code =" + err.code + ", message =" + err.message);
            });
    }

    onWindowStageDestroy(): void {
        // Main window is destroyed, release UI related resources
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
        this.context.eventHub.off(EVENT_CODE_REQUEST);
    }

    onForeground(): void {
        // Ability has brought to foreground
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
    }

    onBackground(): void {
        // Ability has back to background
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
    }

}
