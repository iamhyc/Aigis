import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { promptAction, window } from '@kit.ArkUI';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OTP, OtpSchemaSupport, parseURI } from '../crypto/otpUtils'
import { CodeResponseSchema, OTPItemInfo, SecretSchema,
    AigisContentSchema,
    MasterKeyInfo,
    IconPackStore,
    IconPackSchema,
    AesGcmMaterial} from '../common/schema'
import { arrayRearrange, b32decode, isValidBase32String, stringToUint8Array,
    Uint8ArrayToString } from '../common/utils';
import { AIGIS_PREF_NAME, FAKE_OTP_CODE,
    MAX_ICON_PACK_SIZE,
    PREF_DEC_MASTER_KEY,
    PREF_ICON_PACKS,
    PREF_KEY_SECRETS, PREF_KEY_SETTINGS, PREF_MASTER_KEY,
    PREF_PASSWORD_CHALLENGE_TIME } from '../common/conts';
import { PREF_KEY_ITEMS } from '../common/conts';
import { AppLanguage, AuthTypePriority, DefaultUserPreferences, UserPreferences, ValueType } from '../common/settings';
import { AuthLevelSupport, generateMasterKeyInHUKS, genUserAuthType } from '../crypto/authUtils';
import { AES_KEY_USAGE, generateAesGcmMaterial, HUKSAgent, PARAMS_AES_DECRYPT } from '../crypto/huksUtils';
import {
    BulkyUpdateRequestSchema,
    CodeRequestSchema, EVENT_CODE_REQUEST,
    EVENT_EXPORT_REQUEST,
    EVENT_ICON_PACK_APPLY_REQUEST,
    EVENT_ICON_PACK_IMPORT_REQUEST,
    EVENT_ICON_PACK_REMOVAL_REQUEST,
    EVENT_IMPORT_REQUEST,
    EVENT_INSERT_ITEM_BEFORE,
    EVENT_MOVE_TO_TOP,
    EVENT_REMOVE_ITEM,
    EVENT_UPDATE_ITEM,
    EVENT_UPDATE_ITEMS,
    EVENT_UPDATE_PASSWORD,
    EVENT_UPDATE_PASSWORD_CHALLENGE_TIME,
    EVENT_UPDATE_SETTING,
    FileExportRequestSchema,
    FileImportRequestSchema,
    IconPackApplyRequest,
    IconPackImportRequest,
    IconPackRemovalRequest,
    InsertItemBeforeRequestSchema,
    MoveToTopRequestSchema,
    PasswordUpdateRequestSchema,
    RemovalRequestSchema,
    SettingUpdateRequestSchema,
    UpdatePasswordChallengeTimeSchema,
    UpdateRequestSchema } from '../common/events';
import { AigisImporter } from '../importers/aigis';
import { i18n } from '@kit.LocalizationKit';
import { buffer, util } from '@kit.ArkTS';
import { IconManager } from '../common/icons';

class PreferencesManager {
    private _instances: Map<string, OTP>;
    private _secrets: SecretSchema[];
    private _items: OTPItemInfo[];
    private iconManager: IconManager;
    private _encMasterKeyInfo: MasterKeyInfo | undefined;
    private _decMasterKeyInfo: MasterKeyInfo | undefined;
    private _authLevel: AuthLevelSupport | undefined;
    private _authPriority: AuthTypePriority = 'face';

    constructor(items: OTPItemInfo[], secrets: SecretSchema[], icons: IconPackStore[], encMasterKeyInfo?: MasterKeyInfo, decMasterKeyInfo?: MasterKeyInfo, authLevel?: AuthLevelSupport, authPriority?: AuthTypePriority) {
        this._items = items;
        items.forEach(item => item.code = {timestamp:0,code:FAKE_OTP_CODE});
        this._secrets = secrets;
        //
        this.iconManager = new IconManager(icons);
        this._instances = new Map();
        //
        this._encMasterKeyInfo = encMasterKeyInfo;
        this._decMasterKeyInfo = decMasterKeyInfo;
        this._authLevel = authLevel;
        this._authPriority = authPriority ?? 'face';
    }

    get encrypted_secrets(): SecretSchema[] | undefined {
        // check secrets encryption status
        for (const secret of this._secrets) {
            if (secret.encrypted===undefined) {
                return undefined;
            }
        }
        // return encrypted secrets
        return this._secrets;
    }

    get items() {
        return this._items;
    }

    get icons() {
        return this.iconManager.icons;
    }

    get encMasterKeyInfo() {
        return this._encMasterKeyInfo;
    }

    get decMasterKeyInfo() {
        return this._decMasterKeyInfo;
    }

    get MasterKeyAvailable(): boolean {
        const encKeyAlias = this._encMasterKeyInfo?.keyAlias;
        return encKeyAlias? true : false;
    }

    set authLevel(authLevel: AuthLevelSupport | undefined) {
        this._authLevel = authLevel;
    }

    set authPriority(priority: AuthTypePriority) {
        this._authPriority = priority;
    }

    //------------------ OTP Manager ------------------//

    getOtpInstance(keyAlias: string): OTP {
        let otp = this._instances.get(keyAlias);
        if (otp===undefined) {
            const schema = this._items.find(x => x.keyAlias===keyAlias)?.schema;
            if (schema===undefined) {
                throw Error(`"${keyAlias}" not found in local manager.`);
            }
            otp = OTP.fromSchema(schema);
        }
        return otp;
    }

    async requestCodeUpdate(keyAlias: string, authToken?: Uint8Array): Promise<boolean> {
        const item = this._items.find(x => x.keyAlias===keyAlias);
        const secret = this._secrets.find(x => x.keyAlias===keyAlias);
        if (item && secret) {
            const otp = this.getOtpInstance(keyAlias);
            const rawSecret = await this.requestSecret(item.schema.type, secret, authToken);
            item.code = {
                timestamp: rawSecret.byteLength? Date.now() : 0,
                code: rawSecret.byteLength? await otp.generateOTP(rawSecret) : FAKE_OTP_CODE,
            }
            return true;
        } else {
            return false;
        }
    }

    //------------------ Secret Manager ------------------//

    private async requestSecret(otpType: OtpSchemaSupport, secret: SecretSchema, authToken?: Uint8Array): Promise<Uint8Array> {
        let encodedSecret = secret.secret;
        // decrypt secret
        if (secret.encrypted) {
            encodedSecret = await this.decryptSecret(encodedSecret, secret.encrypted!, authToken);
            if (encodedSecret==='') {
                AppStorage.set('StatusDecKeyRequired', true);
                return new Uint8Array();
            }
        } else if (this.MasterKeyAvailable && this.decMasterKeyInfo?.keyAlias===undefined) {
            AppStorage.set('StatusDecKeyRequired', true);
            return new Uint8Array();
        }
        // return decoded raw secret
        const b64Encoded: boolean = (otpType==='steam' && !isValidBase32String(encodedSecret));
        const rawSecret: Uint8Array = b64Encoded? (new util.Base64Helper()).decodeSync(encodedSecret) : b32decode(encodedSecret);
        return rawSecret;
    }

    private async encryptSecret(secret: string): Promise<[string, AesGcmMaterial|undefined]> {
        if (this.encMasterKeyInfo?.keyAlias) {
            const material = await generateAesGcmMaterial();
            const inData = stringToUint8Array(secret);
            const authType = genUserAuthType(this._authLevel, this._authPriority);
            const result = await HUKSAgent.applyAesGcmEncryption(this.encMasterKeyInfo.keyAlias, material, inData, this._authLevel, authType);
            const _secret = Uint8ArrayToString(result!);
            return [_secret, material];
        } else {
            return [secret, undefined];
        }
    }

    private async decryptSecret(cipher: string, material: AesGcmMaterial, authToken?: Uint8Array): Promise<string> {
        if (this._authPriority && this._decMasterKeyInfo?.keyAlias) {
            if (this._decMasterKeyInfo?.keyAlias) {
                const inData = stringToUint8Array(cipher);
                const result = await HUKSAgent.applyAesGcmDecryption(this._decMasterKeyInfo?.keyAlias, material, inData, this._authLevel, authToken);
                if (result) {
                    return Uint8ArrayToString(result);
                }
            }
        }
        // fail to decrypt the secrets
        return '';
    }

    private async decryptAllSecrets(authToken?: Uint8Array): Promise<boolean> {
        if (!this.MasterKeyAvailable) { return false; }
        for (const secret of this._secrets) {
            if (secret.encrypted) {
                const result = await this.decryptSecret(secret.secret, secret.encrypted, authToken);
                if (result) {
                    secret.secret = result;
                    secret.encrypted = undefined;
                } else {
                    AppStorage.set('StatusDecKeyRequired', true);
                    return false;
                }
            }
        }
        return true;
    }

    async encryptAllSecrets() {
        if (!this.MasterKeyAvailable) { return; }
        for (const secret of this._secrets) {
            if (secret.encrypted===undefined) {
                const result = await this.encryptSecret(secret.secret);
                secret.secret = result[0];
                secret.encrypted = result[1];
            }
        }
    }

    async updateMasterKeyInfo(password: string, newPassword?: boolean, authLevel?: AuthLevelSupport, authToken?: Uint8Array) {
        // update encryption master key
        const encKeyAlias = PREF_MASTER_KEY;
        if (this._encMasterKeyInfo?.keyAlias===undefined) {
            const encMasterKeyInfo = await generateMasterKeyInHUKS(encKeyAlias, password, AES_KEY_USAGE.ENCRYPT);
            this._encMasterKeyInfo = encMasterKeyInfo;
        } else if (newPassword) { // change password procedure
            if (this._decMasterKeyInfo?.keyAlias===undefined) {
                AppStorage.set('StatusDecKeyRequired', true);
                return;
            }
            //
            if (await this.decryptAllSecrets(authToken)) {
                if (this._decMasterKeyInfo?.keyAlias) {
                    await HUKSAgent.deleteKeyItem(this._decMasterKeyInfo.keyAlias, PARAMS_AES_DECRYPT);
                }
                const encMasterKeyInfo = await generateMasterKeyInHUKS(encKeyAlias, password, AES_KEY_USAGE.ENCRYPT);
                this._encMasterKeyInfo = encMasterKeyInfo;
            } else {
                AppStorage.set('StatusDecKeyRequired', true);
                return;
            }
        }
        // update decryption master key
        const decKeyAlias = PREF_DEC_MASTER_KEY;
        const encMasterKeyInfo = this._encMasterKeyInfo!;
        const decMasterKeyInfo = await generateMasterKeyInHUKS(decKeyAlias, password, AES_KEY_USAGE.DECRYPT, authLevel, encMasterKeyInfo.secret, encMasterKeyInfo.params);
        this._decMasterKeyInfo = decMasterKeyInfo;
        // check secrets encryption
        await this.encryptAllSecrets();
    }

    //------------------ Item Manager ------------------//

    importPreferenceItems(dataPreferences: preferences.Preferences, items: OTPItemInfo[], secrets: SecretSchema[]): OTPItemInfo[] {
        const failed: OTPItemInfo[] = [];
        //
        for (let i=0; i<items.length; i++) {
            const keyAlias = items[i].keyAlias;
            if (this._items.find(x => x.keyAlias===keyAlias)) {
                failed.push(items[i]);
            } else {
                this._items.push(items[i]);
                this._secrets.push(secrets[i]);
                this._instances.set(keyAlias, this.getOtpInstance(keyAlias));
            }
        }
        this.persists(dataPreferences);
        //
        return failed;
    }

    async updatePreferenceItem(uri: string, oldKeyAlias?: string, icon?: string) {
        const args = parseURI(uri);
        const otp = OTP.fromArguments(args);
        const secret = args.get('secret');

        const newKeyAlias = oldKeyAlias===undefined ? (otp as OTP).keyAlias : oldKeyAlias;
        const oldItem = this._items.find(x => oldKeyAlias===x.keyAlias);
        const oldSecret = this._secrets.find(x => oldKeyAlias===x.keyAlias);

        if (oldItem!==undefined) {
            const oldKeyAlias = oldItem.keyAlias;
            oldItem.keyAlias = newKeyAlias;
            oldItem.icon = icon ?? await this.iconManager.match( otp.schema.issuer );
            //
            oldItem.schema = otp.schema;
            if (secret && oldSecret) {
                const result = await this.encryptSecret(secret);
                oldSecret.secret = result[0];
                oldSecret.encrypted = result[1];
            }
            // update new instances
            this._instances.delete(oldKeyAlias);
            this.requestCodeUpdate(newKeyAlias);
        } else {
            await this.appendPreferenceItem(otp, secret!, icon);
        }
    }

    private async appendPreferenceItem(otp: OTP, _secret: string, icon?: string) {
        const keyAlias = otp.keyAlias;
        const schema = otp.schema;

        // encrypt secret
        const result = await this.encryptSecret(_secret);
        const secret = result[0];
        const encrypted = result[1];
        // find issuer icon
        icon = icon ?? await this.iconManager.match( otp.schema.issuer );
        const code: CodeResponseSchema = {timestamp:0, code:FAKE_OTP_CODE};
        this._items.push({keyAlias, icon, code, schema});
        this._secrets.push({keyAlias, secret, encrypted});
        this._instances.set(keyAlias, this.getOtpInstance(keyAlias));
    }

    removePreferenceItem(keyAlias: string) {
        //
        const itemIndex = this._items.findIndex(x => x.keyAlias===keyAlias);
        this._items.splice(itemIndex, 1);
        //
        const secretIndex = this._secrets.findIndex(x => x.keyAlias===keyAlias);
        this._secrets.splice(secretIndex, 1);
        //
        this._instances.delete(keyAlias);
    }

    insertPreferenceItem(keyAlias1: string, keyAlias2?: string) {
        //
        const keyItem1 = this._items.findIndex(x => x.keyAlias===keyAlias1);
        const keyItem2 = keyAlias2 ? this._items.findIndex(x => x.keyAlias===keyAlias2) : 0;
        arrayRearrange(this._items, keyItem1, keyItem2);
        //
        const keySecret1 = this._items.findIndex(x => x.keyAlias===keyAlias1);
        const keySecret2 = keyAlias2 ? this._items.findIndex(x => x.keyAlias===keyAlias2) : 0;
        arrayRearrange(this._secrets, keySecret1, keySecret2);
    }

    toggleFavoritePreferenceItem(keyAlias: string) {
        const keyItem = this._items.find(x => x.keyAlias===keyAlias);
        if (keyItem) {
            keyItem.favorite = keyItem?.favorite? false : true;
        }
    }

    //--------------- Icon Pack Manager ---------------//

    async importIconPack(uri: string) {
        const tempDirPath = getContext(this).tempDir;
        const tempArchiveName = tempDirPath + '/temp.zip';
        const tempFolderPath  = tempDirPath + '/temp';
        try {
            const userFileFd = (await fs.open(uri)).fd;
            // check archive size
            if ((await fs.stat(userFileFd)).size > MAX_ICON_PACK_SIZE) {
                throw new Error('import-fail-file-too-large');
            }
            // decompress to tempDir
            await fs.mkdir(tempFolderPath);
            await fs.copyFile(userFileFd, tempArchiveName);
            await zlib.decompressFile(tempArchiveName, tempFolderPath);
            // load `pack.json`
            const arrayBuffer = new ArrayBuffer(1*1024*1024); //1MB
            const tempPackFile = await fs.open(tempFolderPath + '/pack.json');
            const readLen = await fs.read(tempPackFile.fd, arrayBuffer);
            const iconPack: IconPackSchema =JSON.parse( buffer.from(arrayBuffer, 0, readLen).toString() );
            // move to `uuid` folder
            const fileDirPath = getContext(this).filesDir;
            const targetFolderPath: string = fileDirPath + '/' + iconPack.uuid;
            if (await fs.access(targetFolderPath)) {
                throw new Error('import-fail-already-exists');
            }
            await fs.rename(tempFolderPath, targetFolderPath);
            // insert into local preferences
            const isDefault = (this.icons.length==0);
            const pack: IconPackStore = {
                uuid: iconPack.uuid,
                name: iconPack.name,
                version: iconPack.version,
                icons: iconPack.icons.length,
                uri: targetFolderPath,
                isDefault,
            };
            await this.iconManager.appendPack(pack);
            //
            promptAction.showToast({message: $r('app.string.setting_icon_pack_success'), duration: 500});
            if (isDefault) {
                getContext(this).eventHub.emit(EVENT_ICON_PACK_APPLY_REQUEST, {uuid: iconPack.uuid, force: true});
            }
        } catch (e) {
            const errorMsg = (e as Error).message;
            console.error(errorMsg);
            let message = $r('app.string.setting_icon_pack_fail_common');
            if (errorMsg==='import-fail-file-too-large') {
                message = $r('app.string.setting_icon_pack_fail_file_too_large');
            } else if (errorMsg==='import-fail-already-exists') {
                message = $r('app.string.setting_icon_pack_fail_already_exists');
            }
            promptAction.showToast({message, duration: 500});
        } finally {
            fs.unlink(tempArchiveName);
            fs.rmdir(tempFolderPath);
        }
    }

    async removeIconPack(uuid: string) {
        const _icons = this.icons;
        const packIdx = _icons.findIndex(x => x.uuid===uuid);
        if (packIdx>=0) {
            try{
                await fs.rmdir( _icons[packIdx].uri );
            } finally {
                if (_icons[packIdx].isDefault) {
                    if (packIdx > 0) {
                        _icons[packIdx-1].isDefault = true;
                        getContext(this).eventHub.emit(EVENT_ICON_PACK_APPLY_REQUEST, {uuid: _icons[packIdx-1].uuid, force:true});
                    } else if (_icons.length > 1) {
                        _icons[packIdx+1].isDefault = true;
                        getContext(this).eventHub.emit(EVENT_ICON_PACK_APPLY_REQUEST, {uuid: _icons[packIdx+1].uuid, force:true});
                    } else {
                        getContext(this).eventHub.emit(EVENT_ICON_PACK_APPLY_REQUEST, {uuid: '', force: true});
                    }
                }
                this.iconManager.removePack(uuid);
            }
        }
    }

    async applyIconPack(uuid: string, force: boolean = false) {
        if (!this.iconManager.setDefaultIconPack(uuid) && !force) {
            return;
        }
        // reset icon pack
        if (uuid==='') {
            for (const item of this._items) {
                item.icon = '';
            }
            return;
        }
        // apply icon pack to existing items
        for (const item of this._items) {
            item.icon = await this.iconManager.match(item.schema.issuer, uuid);
        }
        // show prompt toast
        if (!force) {
            promptAction.showToast({message: $r('app.string.setting_icon_pack_applied'), duration:500})
        } else {
            promptAction.showToast({message: $r('app.string.setting_icon_pack_changed'), duration:500})
        }
    }

    persists(dataPreferences: preferences.Preferences) {
        dataPreferences!.putSync(PREF_KEY_ITEMS, this._items);
        dataPreferences!.putSync(PREF_KEY_SECRETS, this._secrets);
        dataPreferences!.putSync(PREF_ICON_PACKS, this.icons);
        dataPreferences?.putSync(PREF_MASTER_KEY, this._encMasterKeyInfo);
        dataPreferences.putSync(PREF_DEC_MASTER_KEY, this._decMasterKeyInfo);
        //
        dataPreferences!.flush();
    }
}

export default class EntryAbility extends UIAbility {
    private dataPreferences?: preferences.Preferences;
    private localStorage: LocalStorage = new LocalStorage();
    private instPreferences?: PreferencesManager;
    private localSettings?: UserPreferences;

    onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
        if (want.uri) {
            AppStorage.setAndLink('LaunchURI', want.uri);
        }
    }

    onDestroy(): void {
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    }

    onWindowStageCreate(windowStage: window.WindowStage): void {
        // set main window in privacy mode
        const mainWindow = windowStage.getMainWindowSync();
        mainWindow.setWindowPrivacyMode(true);
        mainWindow.on('avoidAreaChange', (data) => {
            if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
                let topRectHeight = data.area.topRect.height;
                AppStorage.setOrCreate('topRectHeight', topRectHeight);
            } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
                let bottomRectHeight = data.area.bottomRect.height;
                AppStorage.setOrCreate('bottomRectHeight', bottomRectHeight);
            }
        });

        preferences.getPreferences(this.context, AIGIS_PREF_NAME)
            .then(async (pref: preferences.Preferences) => {
                this.dataPreferences = pref;
                // try to load master key
                const encMasterKeyInfo = pref.getSync(PREF_MASTER_KEY, {}) as MasterKeyInfo;
                const decMasterKeyInfo = pref.getSync(PREF_DEC_MASTER_KEY, {}) as MasterKeyInfo;
                AppStorage.setAndProp('EncMasterKey', encMasterKeyInfo);
                AppStorage.setAndProp('MasterKeyAvailable', encMasterKeyInfo.keyAlias!==undefined);
                AppStorage.setAndLink('StatusDecKeyRequired', encMasterKeyInfo.keyAlias!==undefined && decMasterKeyInfo.keyAlias===undefined);
                // load last success password challenge time
                let passwordChallengeTimestamp = pref.getSync(PREF_PASSWORD_CHALLENGE_TIME, 0) as number;
                if (passwordChallengeTimestamp===0 || passwordChallengeTimestamp>Date.now()) {
                    passwordChallengeTimestamp = Date.now();
                    pref.putSync(PREF_PASSWORD_CHALLENGE_TIME, passwordChallengeTimestamp);
                }
                AppStorage.setAndProp(PREF_PASSWORD_CHALLENGE_TIME, passwordChallengeTimestamp);
                // init controller
                this.instPreferences = new PreferencesManager(
                    pref.getSync(PREF_KEY_ITEMS, []) as OTPItemInfo[],
                    pref.getSync(PREF_KEY_SECRETS, []) as SecretSchema[],
                    pref.getSync(PREF_ICON_PACKS, []) as IconPackStore[],
                    encMasterKeyInfo, decMasterKeyInfo,
                );
                this.localStorage.setAndProp(PREF_KEY_ITEMS, this.instPreferences.items);
                AppStorage.setAndProp('IconPacks', this.instPreferences.icons);
                // setup global user settings
                this.initUserPreferences(pref);
                // register event handler
                this.registerEventHubHandlers();
                // init index page
                windowStage.loadContent('pages/Index', this.localStorage);
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

    private applySettings(key: string, value: ValueType, init: boolean=false) {
        const settingKey = `settings${key}`;
        // apply application context configurations
        const context = this.context.getApplicationContext();
        if (key==='AppLanguage') {
            const systemLanguage: string = i18n.System.getSystemLanguage();
            if (value==='default') {
                context.setLanguage(systemLanguage);
            } else {
                context.setLanguage(value as AppLanguage)
            }
        }
        if (key==='DarkMode') {
            if (value==='light') {
                context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
            } else if (value==='dark') {
                context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
            } else {
                context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
            }
        }
        // update local auth preference
        if (key==='EnableBiometricAuth' && this.instPreferences) {
            const authLevel = value===true? 'ATL3' : undefined;
            this.instPreferences.authLevel = authLevel;
        }
        if (key==='EnableBiometricUnlock' && this.instPreferences) {
            if (value===false) {
                this.instPreferences.authLevel = undefined;
            }
        }
        if (key==='AuthTypePriority' && this.instPreferences) {
            this.instPreferences.authPriority = value as AuthTypePriority;
        }
        // propagate settings
        if (init) {
            AppStorage.setAndProp(settingKey, value);
        } else {
            AppStorage.set(settingKey, value);
        }
    }

    private initUserPreferences(pref: preferences.Preferences) {
        // try to load user settings
        const settingString = pref.getSync(PREF_KEY_SETTINGS, '[]') as string;
        const settingItems  = JSON.parse(settingString) as [string, ValueType][];
        this.localSettings = new Map(settingItems);
        for (const obj of DefaultUserPreferences.entries()) {
            const key = obj[0], defaultValue = obj[1];
            const localValue = this.localSettings.get(key);
            if (localValue===undefined) {
                this.applySettings(key, defaultValue, true);
            } else {
                this.applySettings(key, localValue, true);
            }
        }
    }

    private registerEventHubHandlers() {
        this.context.eventHub.on(EVENT_CODE_REQUEST, async (data: CodeRequestSchema) => {
            if (this.instPreferences) {
                const res = await this.instPreferences.requestCodeUpdate(data.keyAlias, data.authToken);
                if (res) {
                    this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
                }
            }
        });
        this.context.eventHub.on(EVENT_UPDATE_ITEM, async (data: UpdateRequestSchema) => {
            if (this.instPreferences) {
                // update local preferences
                await this.instPreferences.updatePreferenceItem(data.uri, data.keyAlias, data.icon);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
            }
        });
        this.context.eventHub.on(EVENT_UPDATE_ITEMS, async (data: BulkyUpdateRequestSchema) => {
            if (this.instPreferences) {
                // update local preferences
                for (const uri of data.uris) {
                    await this.instPreferences.updatePreferenceItem(uri);
                }
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
            }
        });
        this.context.eventHub.on(EVENT_MOVE_TO_TOP, (data: MoveToTopRequestSchema) => {
            if (this.instPreferences) {
                // set favorite in local preferences
                this.instPreferences.toggleFavoritePreferenceItem(data.keyAlias);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
            }
        });
        this.context.eventHub.on(EVENT_INSERT_ITEM_BEFORE, (data: InsertItemBeforeRequestSchema) => {
            if (this.instPreferences) {
                // insert in local preferences
                this.instPreferences.insertPreferenceItem(data.startKeyAlias, data.insertKeyAlias);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
            }
        });
        this.context.eventHub.on(EVENT_REMOVE_ITEM, (data: RemovalRequestSchema) => {
            if (this.instPreferences) {
                // removal in local preferences
                this.instPreferences.removePreferenceItem(data.keyAlias);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
            }
        });
        this.context.eventHub.on(EVENT_UPDATE_SETTING, (data: SettingUpdateRequestSchema) => {
            if (this.localSettings) {
                this.localSettings.set(data.key, data.value);
                this.applySettings(data.key, data.value);
                // persist local settings
                const settingItems = Array.from( this.localSettings.entries() );
                const settingString = JSON.stringify(settingItems);
                this.dataPreferences?.putSync(PREF_KEY_SETTINGS, settingString);
                this.dataPreferences?.flush();
            }
        });
        this.context.eventHub.on(EVENT_UPDATE_PASSWORD, async (data: PasswordUpdateRequestSchema) => {
            if (this.dataPreferences && this.instPreferences) {
                await this.instPreferences.updateMasterKeyInfo(data.password, data.newPassword, data.authLevel);
                this.instPreferences.persists(this.dataPreferences);
                // reset password challenge time
                const _now = Date.now()
                this.dataPreferences.putSync(PREF_PASSWORD_CHALLENGE_TIME, _now);
                AppStorage.set(PREF_PASSWORD_CHALLENGE_TIME, _now);
                // propagate
                AppStorage.set('EncMasterKey', this.instPreferences.encMasterKeyInfo);
                AppStorage.set('MasterKeyAvailable', true);
                AppStorage.set('StatusDecKeyRequired', false);
            }
        });
        this.context.eventHub.on(EVENT_UPDATE_PASSWORD_CHALLENGE_TIME, (data: UpdatePasswordChallengeTimeSchema) => {
            const timestamp = data.timestamp;
            this.dataPreferences?.putSync(PREF_PASSWORD_CHALLENGE_TIME, timestamp);
            AppStorage.set(PREF_PASSWORD_CHALLENGE_TIME, timestamp);
        });
        this.context.eventHub.on(EVENT_EXPORT_REQUEST, async (data: FileExportRequestSchema) => {
            if (!this.instPreferences!.MasterKeyAvailable || this.instPreferences===undefined) {
                return;
            }

            try {
                const settingString = this.localSettings? JSON.stringify(Array.from( this.localSettings.entries() )) : undefined;
                //
                const file = await fs.open(data.uri, fs.OpenMode.CREATE|fs.OpenMode.WRITE_ONLY);
                const masterKey = this.instPreferences.encMasterKeyInfo!;
                const content: AigisContentSchema = {
                    masterKey,
                    items: this.instPreferences.items,
                    secrets: this.instPreferences.encrypted_secrets!,
                    settings: settingString,
                };
                const result = await (new AigisImporter()).save(file.fd, masterKey.keyAlias, content);
                if (result) {
                    promptAction.showToast({message: $r('app.string.setting_export_message_success', data.uri)});
                } else {
                    promptAction.showToast({message: $r('app.string.setting_export_message_failed')});
                    throw Error('Export failed.');
                }
            } catch (err) {
                fs.unlink(data.uri);
            }
        });
        this.context.eventHub.on(EVENT_IMPORT_REQUEST, async (data: FileImportRequestSchema) => {
            const file = await fs.open(data.uri, fs.OpenMode.READ_ONLY);
            try {
                const content = await (new AigisImporter()).load(file.fd, data.password!);
                // import from file;
                const failedItems = this.instPreferences!.importPreferenceItems(this.dataPreferences!, content.items, content.secrets);
                const successNums = content.items.length - failedItems.length;
                promptAction.showToast({message: $r('app.string.setting_import_message_success', successNums)});
                if (failedItems.length > 0) {
                    const failedMsg = failedItems.map(x => '• '+x.keyAlias).join('\n');
                    const showDuration = Math.max(failedItems.length*500, 3000);
                    promptAction.showToast({message: $r('app.string.setting_import_message_bypass_items', failedMsg), duration: showDuration});
                }
                // refresh local storage
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences!.items);
                // import password as master key
                if (!this.instPreferences!.MasterKeyAvailable && data.password!==undefined && data.importPassword) {
                    this.context.eventHub.emit(EVENT_UPDATE_PASSWORD, {password: data.password} as PasswordUpdateRequestSchema);
                }
                // TODO: restore settings
            } catch (error) {
                promptAction.showToast({message: $r('app.string.setting_import_message_failed_decryption'), duration: 1000});
            }
        })
        this.context.eventHub.on(EVENT_ICON_PACK_IMPORT_REQUEST, async (data: IconPackImportRequest) => {
            if (this.instPreferences) {
                // update local preferences
                await this.instPreferences.importIconPack(data.uri);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated icon packs
                AppStorage.set('IconPacks', this.instPreferences.icons);
            }
        });
        this.context.eventHub.on(EVENT_ICON_PACK_REMOVAL_REQUEST, async (data: IconPackRemovalRequest) => {
            if (this.instPreferences) {
                // update local preferences
                await this.instPreferences.removeIconPack(data.uuid);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated icon packs
                AppStorage.set('IconPacks', this.instPreferences.icons);
            }
        });
        this.context.eventHub.on(EVENT_ICON_PACK_APPLY_REQUEST, async (data: IconPackApplyRequest) => {
            if (this.instPreferences) {
                // update local preferences
                await this.instPreferences.applyIconPack(data.uuid, data.force);
                // update persist preferences
                this.instPreferences.persists(this.dataPreferences!);
                // propagate updated items
                this.localStorage.set(PREF_KEY_ITEMS, this.instPreferences.items);
                AppStorage.set('IconPacks', this.instPreferences.icons);
            }
        });
    }
}
