import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HOTP, OTP, parseURI, TOTP } from '../crypto/otpUtils'
import { EVENT_CODE_REQUEST, CodeRequestSchema, CodeResponseSchema, OTPItemInfo,
    EVENT_UPDATE_ITEM,
    UpdateRequestSchema} from '../common/schema'
import { name2keyAlias } from '../common/utils';
import { PREF_KEY_SECRETS } from '../common/conts';
import { PREF_KEY_ITEMS } from '../common/conts';

const AIGIS_PREF_NAME = 'aigis-pref';

type SecretsStore = Map<string,string>;

interface PreferencesSchema {
    secrets: SecretsStore,
    items: OTPItemInfo[],
}

export default class EntryAbility extends UIAbility {
    private dataPreferences?: preferences.Preferences;
    private localStorage: LocalStorage = new LocalStorage();
    private InstPreferences?: PreferencesSchema;

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
                this.InstPreferences = {
                    secrets: this.dataPreferences.getSync(PREF_KEY_SECRETS, new Map<string,string>()) as SecretsStore,
                    items:   this.dataPreferences.getSync(PREF_KEY_ITEMS, []) as OTPItemInfo[],
                }
                this.localStorage.set(PREF_KEY_ITEMS, this.InstPreferences.items);

                // register event handler
                this.context.eventHub.on(EVENT_CODE_REQUEST, async (data: CodeRequestSchema) => {
                    const key = name2keyAlias(data);

                });
                this.context.eventHub.on(EVENT_UPDATE_ITEM, (data: UpdateRequestSchema) => {
                    const args = parseURI(data.uri);
                    switch (args.get('type')) {
                        case 'hotp':
                            const hotp = HOTP.fromArguments(args);
                            this.updatePreferenceItem(hotp, args.get('secret')!);
                            break;
                        case 'totp':
                            const totp = TOTP.fromArguments(args);
                            this.updatePreferenceItem(totp, args.get('secret')!);
                            break;
                        default:
                            break;
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

    private updatePreferenceItem(otp: OTP, secret: string) {
        const otp_schema = otp.schema;
        const keyAlias = name2keyAlias({
            issuer: otp_schema.issuer, name: otp_schema.name
        });

        if (this.InstPreferences) {
            // update InstPreferences.items
            const oldItem = this.InstPreferences.items.find(x => otp.keyEquals(x.schema));
            if (oldItem) {
                oldItem.schema = otp.schema;
            } else {
                this.InstPreferences.items.push({
                    icon: '',
                    code: {timestamp:0, code:''},
                    schema: otp_schema,
                })
            }
            // update InstPreferences.secrets
            console.log('??? - 3')
            this.InstPreferences.secrets.set(keyAlias, secret);
            console.log('??? - 4')

            // update persist preferences
            this.dataPreferences!.putSync(PREF_KEY_ITEMS, this.InstPreferences.items);
            console.log('??? - 5-1')
            this.dataPreferences!.putSync(PREF_KEY_SECRETS, this.InstPreferences.secrets);
            console.log('??? - 5-2')

            console.log('keyAlias', keyAlias);
            this.localStorage.set(PREF_KEY_ITEMS, this.InstPreferences.items);
        }
    }
}
