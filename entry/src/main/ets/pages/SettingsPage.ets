import { mediaquery, promptAction, SymbolGlyphModifier } from "@kit.ArkUI";
import { SettingListItemInfo, SettingListItem, SettingListItemToggle,
    SettingListItemSelect,
    SettingListCollapsableItem,
    NoInternetHyperLink,
    SettingListIconItem} from "../components/settings";
import { AppLanguage, AuthTypePriority, DarkMode, DigitGroup,
    PasswordReminderPeriod,
    ShowAccountName, ValueType,
    ViewMode } from "../common/settings";
import {
    ChangePasswordInputDialog,
    CustomSelectDialog, NewPasswordInputDialog, PasswordInputDialog } from "../components/dialog";
import {
    EVENT_EXPORT_REQUEST,
    EVENT_ICON_PACK_APPLY_REQUEST,
    EVENT_ICON_PACK_IMPORT_REQUEST,
    EVENT_ICON_PACK_REMOVAL_REQUEST,
    EVENT_IMPORT_REQUEST,
    EVENT_UPDATE_PASSWORD, EVENT_UPDATE_SETTING,
    FileExportRequestSchema,
    FileImportRequestSchema,
    PasswordUpdateRequestSchema,
    SettingUpdateRequestSchema } from "../common/events";
import { picker } from "@kit.CoreFileKit";
import { common } from "@kit.AbilityKit";
import { AtlAuthResult, IconPackStore, MasterKeyInfo } from "../common/schema";
import { AppLockPage } from "../components/pages";
import { validateAtlAuth, validatePassword } from "../crypto/authUtils";
import { FEEDBACK_WEBSITE, MAX_ICON_PACK_NUM, OFFICIAL_WEBSITE } from "../common/conts";
import { ImporterSelections } from "../importers";

interface DividerStyle {strokeWidth: Length; color?: ResourceColor; startMargin?: Length; endMargin?: Length;};
const divider_style: DividerStyle = {strokeWidth:'1px', color:$r('sys.color.comp_divider'), startMargin:6, endMargin:6};

const DarkModeSelections: Map<ResourceStr, DarkMode> = new Map([
    [$r('app.string.setting_dark_mode_follow_system'), 'default'],
    [$r('app.string.setting_dark_mode_always_dark'), 'dark'],
    [$r('app.string.setting_dark_mode_always_light'), 'light'],
]);

const ViewModeSelections: Map<ResourceStr, ViewMode> = new Map([
    [$r('app.string.setting_view_mode_compact'), 'compact'],
    [$r('app.string.setting_view_mode_normal'),  'normal'],
    [$r('app.string.setting_view_mode_large'),   'large'],
]);

const AppLanguageSelections: Map<ResourceStr, AppLanguage> = new Map<ResourceStr, AppLanguage>([
    [$r('app.string.setting_language_system_default'), 'default'],
    ['简体中文     ', 'zh-Hans'],
    ['English    ', 'en-Latn-US'],
]);

const DigitGroupingSelection: Map<ResourceStr, DigitGroup> = new Map([
    [$r('app.string.setting_digit_group_option_2'),    '2'],
    [$r('app.string.setting_digit_group_option_3'),    '3'],
    [$r('app.string.setting_digit_group_option_4'),    '4'],
    [$r('app.string.setting_digit_group_option_even'), 'even'],
    [$r('app.string.setting_digit_group_option_none'), 'none'],
]);

const AccountNameSelection: Map<ResourceStr, ShowAccountName> = new Map([
    [$r('app.string.setting_show_account_name_option_always'), 'always'],
    [$r('app.string.setting_show_account_name_option_smart'), 'smart'],
    [$r('app.string.setting_show_account_name_option_off'), 'off'],
]);

const PasswordReminderSelection: Map<ResourceStr, PasswordReminderPeriod> = new Map([
    [$r('app.string.setting_password_reminder_period_never'),     'never'],
    [$r('app.string.setting_password_reminder_period_weekly'),    'weekly'],
    [$r('app.string.setting_password_reminder_period_biweekly'),  'biweekly'],
    [$r('app.string.setting_password_reminder_period_monthly'),   'monthly'],
    // [$r('app.string.setting_password_reminder_period_quarterly'), 'quarterly'],
]);

const ATL1AuthTypePrioritySelection: Map<ResourceStr, AuthTypePriority> = new Map([
    [$r('app.string.setting_auth_priority_face_first'),  'face'],
    [$r('app.string.setting_auth_priority_touch_first'), 'touch'],
    [$r('app.string.setting_auth_priority_pin_only'),    'pin'],
]);

const ATL3AuthTypePrioritySelection: Map<ResourceStr, AuthTypePriority> = new Map([
    [$r('app.string.setting_auth_priority_face_first'),  'face'],
    [$r('app.string.setting_auth_priority_touch_first'), 'touch'],
]);

@Component
export struct SettingsPage {
    @Consume navStack: NavPathStack;
    @Consume atlAuth: AtlAuthResult;
    @Consume ATL1AuthAvailable: boolean;
    @Consume ATL3AuthAvailable: boolean;
    @Link pageTranslateX: string;
    @Require @Prop pageTitle: string;

    @StorageProp('EncMasterKey') EncMasterKey: MasterKeyInfo = {} as MasterKeyInfo;
    @StorageProp('MasterKeyAvailable') MasterKeyAvailable: boolean = false;
    @StorageProp('IconPacks') IconPacks: IconPackStore[] = [];
    // general
    @StorageProp('settingsEnableManualInput')
    @Watch('onItChanged') EnableManualInput: boolean = false;
    @StorageProp('settingsEnableDoubleClickCopy')
    @Watch('onItChanged') EnableDoubleClickCopy: boolean = false;
    @StorageProp('settingsDisableAddConfirm')
    @Watch('onItChanged') DisableAddConfirm: boolean = false;
    @StorageProp('settingsPreviewNextToken')
    @Watch('onItChanged') PreviewNextToken: boolean = false;

    // outlook
    @StorageProp('settingsAppLanguage')
    @Watch('onItChanged') AppLanguage: AppLanguage = 'default';
    @StorageProp('settingsDarkMode')
    @Watch('onItChanged') DarkMode: DarkMode = 'default';
    @StorageProp('settingsViewMode')
    @Watch('onItChanged') ViewMode: ViewMode = 'compact';
    @StorageProp('settingsDigitGroup')
    @Watch('onItChanged') DigitGroup: DigitGroup = '3';
    @StorageProp('settingsShowAccountName')
    @Watch('onItChanged') ShowAccountName: ShowAccountName = 'always';
    // icons
    @StorageProp('settingsShowIssuerIcons')
    @Watch('onItChanged') ShowIssuerIcons: boolean = true;
    // security
    @StorageProp('settingsPasswordReminderPeriod')
    @Watch('onItChanged') PasswordReminderPeriod: PasswordReminderPeriod = 'biweekly';
    @StorageProp('settingsEnableScreenSecurity')
    @Watch('onItChanged') EnableScreenSecurity: boolean = true;
    @StorageProp('settingsEnableBiometricUnlock')
    @Watch('onItChanged') EnableBiometricUnlock: boolean = false;
    @StorageProp('settingsAuthTypePriority')
    @Watch('onItChanged') AuthTypePriority: AuthTypePriority = 'face';
    @StorageProp('settingsEnableBiometricAuth')
    @Watch('onItChanged') EnableBiometricAuth: boolean = false;
    @State _EnableBiometricAuth: boolean = this.EnableBiometricAuth;
    // backup
    @StorageProp('settingsEnableBackupReminder')
    @Watch('onItChanged') EnableBackupReminder: boolean = true;

    @State iconPacksCollapsed: boolean = true;

    private inputDialogId: number = -1;

    @LocalBuilder IconPackItem(pack: IconPackStore) {
        SettingListIconItem({
            title: `${pack.name} (v${pack.version})`,
            description: $r('app.string.setting_icon_pack_num_icons', pack.icons),
            checked: pack.isDefault,
            onApply: () => { this.applyIconPack(pack.uuid); },
            onRemove: () => { this.removeIconPack(pack.uuid); },
        })
            .width('100%')
    }

    @LocalBuilder IconPackContainer(_packs: IconPackStore[]) {
        // icon pack download hint
        if (this.IconPacks.length===0) {
            ListItem() {
                Column({space:6}) {
                    Row() {
                        Text($r('app.string.setting_icon_pack_add_text_try')).fontColor($r('sys.color.font_secondary')).fontSize(14)
                        NoInternetHyperLink({
                            link: 'https://github.com/aegis-icons/aegis-icons/releases/latest/download/aegis-icons.zip',
                            text: 'aegis-icons',
                        })
                        Text($r('app.string.setting_icon_pack_add_text_or')).fontColor($r('sys.color.font_secondary')).fontSize(14)
                        NoInternetHyperLink({
                            link: 'https://github.com/Delta-Icons/aegis/releases/latest/download/delta-aegis-icons.zip',
                            text: 'delta-icons',
                        })
                        Text($r('app.string.setting_icon_pack_add_text_dot')).fontColor($r('sys.color.font_secondary')).fontSize(14)
                    }
                    .clip(true)
                    Row() {
                        Text($r('app.string.setting_icon_pack_add_text_hint'))
                            .fontColor($r('sys.color.font_tertiary'))
                            .fontSize(12)
                    }
                }
            }
            .margin({top:6,bottom:6})
            .width('90%')
        }
        // icon pack list
        ForEach(this.IconPacks, (pack: IconPackStore) => {
            ListItem() {
                Divider().strokeWidth('1px').color($r('sys.color.comp_divider')).margin({left:6,right:6})
            }
            .padding({left:32})
            .width('100%')
            this.IconPackItem(pack)
        })
        // add button
        if (this.IconPacks.length < MAX_ICON_PACK_NUM) {
            ListItem() {
                Button($r('app.string.setting_icon_pack_add_button'))
                    .width('100%')
                    .buttonStyle(ButtonStyleMode.TEXTUAL)
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .fontColor($r('sys.color.font_secondary'))
                    .onClick(() => {
                        this.importIconPackFromArchive();
                    })
            }
            .margin({top:6,bottom:6})
            .width('80%')
            .height(32)
        }
    }

    build() {
        NavDestination() {
            if (this.EnableBiometricUnlock && !validateAtlAuth(this.atlAuth)) {
                AppLockPage({atlAuth: this.atlAuth, authLevel: 'ATL1', priority: this.AuthTypePriority})
            } else {
                RelativeContainer() {
                    List({space:10}) {
                        // General
                        ListItemGroupHeader({name: $r('app.string.section_title_general')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItemToggle({
                                title: $r('app.string.setting_enable_manual_input_title'),
                                description: $r('app.string.setting_enable_manual_input_desc'),
                                selected: this.EnableManualInput,
                            })
                            SettingListItemToggle({
                                title: $r('app.string.setting_enable_double_click_copy_title'),
                                description: $r('app.string.setting_enable_double_click_copy_desc'),
                                selected: this.EnableDoubleClickCopy,
                            })
                            SettingListItemToggle({
                                title: $r('app.string.setting_enable_add_token_no_confirmation'),
                                description: $r('app.string.setting_enable_add_token_no_confirmation_desc'),
                                selected: this.DisableAddConfirm,
                            })
                            SettingListItemToggle({
                                title: $r('app.string.setting_preview_next_token_title'),
                                description: $r('app.string.setting_preview_next_token_desc'),
                                selected: this.PreviewNextToken,
                            })
                        }
                        .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))

                        // Outlook
                        ListItemGroupHeader({name: $r('app.string.section_title_outlook')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItemSelect({
                                title: $r('app.string.setting_language'),
                                selected: this.AppLanguage,
                                entries: AppLanguageSelections,
                            })
                            SettingListItemSelect({
                                title: $r('app.string.setting_dark_mode_title'),
                                selected: this.DarkMode,
                                entries: DarkModeSelections
                            })
                            SettingListItemSelect({
                                title: $r('app.string.setting_view_mode_title'),
                                selected: this.ViewMode,
                                entries: ViewModeSelections,
                            })
                            SettingListItemSelect({
                                title: $r('app.string.setting_digit_group_title'),
                                selected: this.DigitGroup,
                                entries: DigitGroupingSelection,
                            })
                            SettingListItemSelect({
                                title: $r('app.string.setting_show_account_name'),
                                selected: this.ShowAccountName,
                                entries: AccountNameSelection,
                            })
                        }
                        .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))

                        // Icons
                        ListItemGroupHeader({name: $r('app.string.section_title_icons')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItemToggle({ title: $r('app.string.setting_show_issuer_icons'), selected: this.ShowIssuerIcons })
                            ListItem() {
                                Divider().strokeWidth('1px').color($r('sys.color.comp_divider')).margin({left:6,right:6})
                            }
                            SettingListCollapsableItem({
                                title: $r('app.string.setting_icon_pack_title'),
                                description: $r('app.string.setting_icon_pack_desc'),
                                preview: $r('app.string.setting_icon_pack_preview', this.IconPacks.length),
                                collapsable: true,
                                collapsed: this.iconPacksCollapsed,
                            })
                            if (!this.iconPacksCollapsed) {
                                this.IconPackContainer(this.IconPacks)
                            }
                        }
                        // .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))

                        // Security
                        ListItemGroupHeader({name: $r('app.string.section_title_security')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItem({
                                title: $r('app.string.setting_setup_password'),
                                description: $r('app.string.setting_setup_password_hint'),
                                preview: this.MasterKeyAvailable ?$r('app.string.setting_password_confirmed') : undefined,
                            }).onClick(() => { this.handleSetupPassword() })
                            if (this.MasterKeyAvailable) {
                                SettingListItemSelect({
                                    title: $r('app.string.setting_password_reminder_title'),
                                    description: $r('app.string.setting_password_reminder_desc'),
                                    selected: this.PasswordReminderPeriod,
                                    entries: PasswordReminderSelection,
                                })
                                SettingListItemToggle({
                                    title: $r('app.string.setting_enable_screen_security_title'),
                                    description: $r('app.string.setting_enable_screen_security_desc'),
                                    disabled: !this.MasterKeyAvailable,
                                    selected: this.EnableScreenSecurity,
                                })
                            }
                            if (true) {
                            // if (!this.EnableBiometricAuth) { //FIXME: Not Support Cause of "External Error"
                                SettingListItemToggle({
                                    title: $r('app.string.setting_enable_biometric_unlock'),
                                    description: $r('app.string.setting_biometric_unlock_hint'),
                                    disabled: !this.ATL1AuthAvailable,
                                    selected: this.EnableBiometricUnlock,
                                })
                            }
                            if (false) { //FIXME: Not Support Cause of "External Error"
                            // if (this.MasterKeyAvailable && this.EnableBiometricUnlock) {
                                SettingListItemToggle({
                                        title: $r('app.string.setting_enable_biometric_auth'),
                                        description: $r('app.string.setting_biometric_auth_hint'),
                                        disabled: !this.ATL3AuthAvailable,
                                        selected: this._EnableBiometricAuth,
                                        onChange: (() => {
                                            if (this._EnableBiometricAuth===this.EnableBiometricAuth) { return; }
                                            this._EnableBiometricAuth = this.EnableBiometricAuth;
                                            // password prompt for dec key re-import
                                            const usage = this.EnableBiometricAuth ? $r('app.string.password_usage_generate_dec_key') : $r('app.string.password_usage_generate_dec_key_atl3');
                                            this.showCustomDialog(() => {
                                                this.passwordInputDialogBuilder(
                                                    $r('app.string.setting_enter_master_password'), usage, false, undefined,
                                                    (password) => {
                                                        validatePassword(this.EncMasterKey, password)
                                                            .then(validated => {
                                                                if (!validated) {
                                                                    promptAction.showToast({message:$r('app.string.setting_input_wrong_password')})
                                                                    return;
                                                                } else {
                                                                    const authLevel = this.EnableBiometricAuth? undefined : 'ATL3';
                                                                    getContext().eventHub.emit(EVENT_UPDATE_PASSWORD, {password, authLevel} as PasswordUpdateRequestSchema);
                                                                    // at last
                                                                    this.EnableBiometricAuth = !this._EnableBiometricAuth;
                                                                    this._EnableBiometricAuth = this.EnableBiometricAuth;
                                                                }
                                                            });
                                                        this.inputDialogId = -1;
                                                        promptAction.closeCustomDialog(this.inputDialogId);
                                                    }, () => { promptAction.closeCustomDialog(this.inputDialogId); });
                                            })

                                        }),
                                    })
                            }
                            if (this.EnableBiometricUnlock) {
                                SettingListItemSelect({
                                    title: $r('app.string.setting_auth_priority'),
                                    selected: this.AuthTypePriority,
                                    entries: this.EnableBiometricAuth? ATL3AuthTypePrioritySelection : ATL1AuthTypePrioritySelection,
                                })
                            }
                        }
                        .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))

                        // Import & Export
                        ListItemGroupHeader({name: $r('app.string.section_title_import_export')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItemToggle({
                                title: $r('app.string.setting_enable_backup_reminder_title'),
                                description: $r('app.string.setting_enable_backup_reminder_desc'),
                                disabled: !this.MasterKeyAvailable,
                                selected: this.EnableBackupReminder,
                            })
                            SettingListItem({ title: $r('app.string.setting_import_from_file') })
                                .onClick(() => { this.handleImportFromFile(); })
                            SettingListItem({
                                title: $r('app.string.setting_export_to_file'),
                                disabled: !this.MasterKeyAvailable,
                                preview: this.MasterKeyAvailable? undefined : $r('app.string.setting_setup_master_key_hint')
                            })
                                .onClick(() => { this.MasterKeyAvailable && this.handleExportToFile(); })
                        }
                        .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))

                        // About
                        ListItemGroupHeader({name: $r('app.string.section_title_about')}).margin({bottom:-6})
                        ListItemGroup({style: ListItemGroupStyle.CARD}) {
                            SettingListItemInfo({
                                title: $r('app.string.setting_about_version'),
                                description: $r('app.string.setting_about_information',
                                    $r('app.string.app_version'),
                                    $r('app.string.app_icp_string')
                                ),
                                clickToCopy: getContext().resourceManager.getStringByNameSync('app_icp_string'),
                                copyPrompt: $r('app.string.prompt_icp_number_copied'),
                            })
                            SettingListItemInfo({
                                title: $r('app.string.setting_official_website'),
                                description: OFFICIAL_WEBSITE,
                                clickToCopy: OFFICIAL_WEBSITE,
                                copyPrompt: $r('app.string.prompt_website_copied'),
                            })
                            SettingListItemInfo({
                                title: $r('app.string.setting_feedback'),
                                description: FEEDBACK_WEBSITE,
                                clickToCopy: FEEDBACK_WEBSITE,
                                copyPrompt: $r('app.string.prompt_website_copied'),
                            })
                        }
                        .divider(divider_style)
                        .backgroundColor($r('sys.color.comp_background_tertiary'))
                    }
                    .height('100%')
                    .width('100%')
                    .padding({top:10, bottom:10})
                    .alignListItem(ListItemAlign.Center)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring, {alwaysEnabled:true})
                    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
                }
            }
        }
        .title(this.pageTitle, {
            backgroundColor: $r('app.color.color_background')
        })
        .backButtonIcon( new SymbolGlyphModifier($r('sys.symbol.open_sidebar')) )
        .backgroundColor($r('app.color.color_face'))
        .height('100%')
        .width('100%')
        .translate({x: this.pageTranslateX})
    }

    private onItChanged(key: string) {
        let value: ValueType = 0;
        const eventHub = getContext(this).eventHub;

        switch(key) {
            // general
            case            'EnableManualInput':
                value = this.EnableManualInput;
                break;
            case            'EnableDoubleClickCopy':
                value = this.EnableDoubleClickCopy;
                break;
            case            'DisableAddConfirm':
                value = this.DisableAddConfirm;
                break;
            case            'PreviewNextToken':
                value = this.PreviewNextToken;
                break;
            // outlook
            case            'AppLanguage':
                value = this.AppLanguage;
                break;
            case            'DarkMode':
                value = this.DarkMode;
                break;
            case            'ViewMode':
                value = this.ViewMode;
                break;
            case            'DigitGroup':
                value = this.DigitGroup;
                break;
            case            'ShowAccountName':
                value = this.ShowAccountName;
                break;
            case            'ShowIssuerIcons':
                value = this.ShowIssuerIcons;
                break;
            // security
            case            'PasswordReminderPeriod':
                value = this.PasswordReminderPeriod;
                break;
            case            'EnableScreenSecurity':
                value = this.EnableScreenSecurity;
                break;
            case            'EnableBiometricUnlock':
                value = this.EnableBiometricUnlock;
                break;
            case            'AuthTypePriority':
                value = this.AuthTypePriority;
                break;
            case            'EnableBiometricAuth':
                value = this.EnableBiometricAuth;
                break;
            // backup
            case            'EnableBackupReminder':
                value = this.EnableBackupReminder;
                break;
            default:
                return;
        }

        eventHub.emit(EVENT_UPDATE_SETTING, {key, value} as SettingUpdateRequestSchema);
    }

    private showCustomDialog(builder: () => CustomBuilder) {
        if (this.inputDialogId > 0) {
            promptAction.closeCustomDialog(this.inputDialogId);
            this.inputDialogId = -1;
        }
        //
        promptAction.openCustomDialog({
            builder,
            onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
                if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
                    dismissDialogAction.dismiss()
                }
                if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
                    dismissDialogAction.dismiss()
                }
            }
        }).then((dialogId) => {
            this.inputDialogId = dialogId;
        });
    }

    @Builder newPasswordInputDialogBuilder(title: ResourceStr, warning: ResourceStr, confirm?: (password: string) => void, cancel?: () => void) {
        NewPasswordInputDialog({ title, warning, confirm, cancel });
    }
    @Builder changePasswordInputDialogBuilder(title: ResourceStr, warning: ResourceStr, confirm?: (oldPass: string, newPass: string) => void, cancel?: () => void) {
        ChangePasswordInputDialog({ title, warning, confirm, cancel });
    }
    private handleSetupPassword() {
        if (!this.MasterKeyAvailable) {
            this.showCustomDialog(() => {
                this.newPasswordInputDialogBuilder(
                    $r('app.string.setting_setup_password_title'),
                    $r('app.string.setting_setup_password_warning'),
                    (password) => {
                        getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD, {password});
                        //
                        promptAction.closeCustomDialog(this.inputDialogId);
                        this.inputDialogId = -1;
                    },
                    () => { promptAction.closeCustomDialog(this.inputDialogId); }
                );
            });
        } else {
            this.showCustomDialog(() => {
                this.changePasswordInputDialogBuilder(
                  $r('app.string.setting_change_password_title'),
                    $r('app.string.setting_setup_password_warning'),
                    async (oldPassword, newPassword) => {
                        if (!(await validatePassword(this.EncMasterKey, oldPassword))) {
                            promptAction.showToast({message: $r('app.string.setting_input_wrong_password')});
                        } else {
                            getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD, {password: newPassword, newPassword: true} as PasswordUpdateRequestSchema);
                            promptAction.showToast({message:$r('app.string.setting_password_changed')})
                        }
                        //
                        promptAction.closeCustomDialog(this.inputDialogId);
                        this.inputDialogId = -1;
                    },
                    () => { promptAction.closeCustomDialog(this.inputDialogId); }
                );
            });
        }
    }

    @Builder passwordInputDialogBuilder(title: ResourceStr, usage: ResourceStr, optional?: boolean, optionText?: ResourceStr, confirm?: (password: string, checked?: boolean) => void, cancel?: () => void) {
        PasswordInputDialog({ title, usage, optional, optionText, confirm, cancel })
    }
    @Builder customSelectDialogBuilder(title: ResourceStr, subtitle: ResourceStr | undefined, entries: string[], descriptions?: (ResourceStr|undefined)[], confirm?: (value: string) => void, cancel?: () => void, toName?: (entry: string) => ResourceStr) {
        CustomSelectDialog({ title, subtitle, entries, descriptions, confirm, cancel, toName })
    }
    private handleImportFromFile() {
        this.showCustomDialog(() => {
            this.customSelectDialogBuilder(
                $r('app.string.setting_import_file_title'), undefined,
                Array.from(ImporterSelections.keys()),
                Array.from(ImporterSelections.values()).map(x => x.description),
                (key) => {
                const schema = ImporterSelections.get(key)!;
                const type   = schema.type;
                //
                const context = getContext(this) as common.Context;
                const documentViewPicker = new picker.DocumentViewPicker(context);
                const documentSelectOptions = new picker.DocumentSelectOptions();
                documentSelectOptions.maxSelectNumber = 1;
                documentSelectOptions.fileSuffixFilters = schema.format;
                documentViewPicker.select(documentSelectOptions).then((uris) => {
                    if (uris[0]!==undefined) {
                        const uri = uris[0];
                        this.showCustomDialog(() => {
                            this.passwordInputDialogBuilder(
                                $r('app.string.setting_setup_password_title'),
                                $r('app.string.password_usage_decrypt_import'),
                                !schema.import_password_required,
                                this.MasterKeyAvailable? undefined : $r('app.string.setting_import_enter_password_option_as_master_key'),
                                (password, importPassword) => {
                                    context.eventHub.emit(EVENT_IMPORT_REQUEST, {type, uri, password, importPassword} as FileImportRequestSchema);
                                    //
                                    this.inputDialogId = -1;
                                    promptAction.closeCustomDialog(this.inputDialogId);
                                }, () => { promptAction.closeCustomDialog(this.inputDialogId); });
                        });
                    }
                });
                //
                this.inputDialogId = -1;
                promptAction.closeCustomDialog(this.inputDialogId);
            },
                () => { promptAction.closeCustomDialog(this.inputDialogId); },
                (entry: string) => { return ImporterSelections.get(entry)?.name ?? entry; }
            );
        });
    }
    private handleExportToFile() {
        this.showCustomDialog(() => {
            this.customSelectDialogBuilder(
                $r('app.string.setting_export_file_title'), undefined,
                Array.from(ImporterSelections.keys()),
                Array.from(ImporterSelections.values()).map(x => x.description),
                (key) => {
                    const schema = ImporterSelections.get(key)!;
                    const type   = schema.type;
                    const documentSaveOptions = new picker.DocumentSaveOptions();
                    documentSaveOptions.newFileNames = [schema.export_filename];
                    documentSaveOptions.fileSuffixChoices = schema.format;
                    //
                    const context = getContext(this) as common.Context;
                    const documentViewPicker = new picker.DocumentViewPicker(context);
                    documentViewPicker.save(documentSaveOptions).then((uris) => {
                        if (uris[0]!==undefined) {
                            const uri = uris[0];
                            if (schema.export_password_required) {
                                this.passwordInputDialogBuilder(
                                    $r('app.string.setting_setup_password_title'), $r('app.string.password_usage_decrypt_import'), false, undefined,
                                    (password) => {
                                        context.eventHub.emit(EVENT_EXPORT_REQUEST, {type, uri, password} as FileExportRequestSchema);
                                        //
                                        this.inputDialogId = -1;
                                        promptAction.closeCustomDialog(this.inputDialogId);
                                    }, () => { promptAction.closeCustomDialog(this.inputDialogId); });
                            } else {
                                context.eventHub.emit(EVENT_EXPORT_REQUEST, {type, uri} as FileExportRequestSchema);
                            }
                        }
                    });
                    //
                    promptAction.closeCustomDialog(this.inputDialogId);
                    this.inputDialogId = -1;
                },
                () => { promptAction.closeCustomDialog(this.inputDialogId); },
                (entry: string) => { return ImporterSelections.get(entry)?.name ?? entry; },
            );
        });
    }

    private importIconPackFromArchive() {
        const context = getContext(this) as common.Context;
        const documentViewPicker = new picker.DocumentViewPicker(context);
        const documentSelectOptions = new picker.DocumentSelectOptions();
        documentSelectOptions.maxSelectNumber = 1;
        documentSelectOptions.fileSuffixFilters = ['.zip'];
        documentSelectOptions.defaultFilePathUri = "file://docs/storage/Users/currentUser/Download";
        documentViewPicker.select(documentSelectOptions).then((uris) => {
           if (uris[0]!=undefined) {
               const uri = uris[0];
               getContext().eventHub.emit(EVENT_ICON_PACK_IMPORT_REQUEST, {uri});
           }
        });
    }
    private removeIconPack(uuid: string) {
        AlertDialog.show({
            title: $r('app.string.setting_icon_pack_delete_title'),
            message: $r('app.string.setting_icon_pack_delete_hint'),
            autoCancel: true,
            primaryButton: {
                value: $r('app.string.button_text_cancel'),
                defaultFocus: true,
                style: DialogButtonStyle.DEFAULT,
                action: () => {},
            },
            secondaryButton: {
                value: $r('app.string.button_text_ok'),
                fontColor: $r('sys.color.warning'),
                style: DialogButtonStyle.DEFAULT,
                action: () => {
                    getContext().eventHub.emit(EVENT_ICON_PACK_REMOVAL_REQUEST, {uuid});
                },
            }
        });
    }
    private applyIconPack(uuid: string) {
        getContext().eventHub.emit(EVENT_ICON_PACK_APPLY_REQUEST, {uuid});
    }
}

@Component
struct ListItemGroupHeader {
    @Require @Prop name: ResourceStr

    listener:mediaquery.MediaQueryListener = this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)');
    @State deviceIsPortrait: boolean = false;

    build() {
        ListItem() {
            Text(this.name)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
                .width('90%')
                .textAlign(this.deviceIsPortrait? TextAlign.Center : TextAlign.Start)
        }
    }

    aboutToAppear() {
        this.deviceIsPortrait = this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)').matches;
        this.listener.on('change', (mediaQueryResult: mediaquery.MediaQueryResult) => {
            this.deviceIsPortrait = mediaQueryResult.matches;
        });
    }

    aboutToDisappear() {
        this.listener.off('change');
    }
}