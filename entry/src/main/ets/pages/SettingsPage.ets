import { mediaquery, promptAction, SymbolGlyphModifier } from "@kit.ArkUI";
import { unifiedDataChannel } from "@kit.ArkData";
import { SettingListInfo, SettingListItem, SettingListToggle } from "../components/settings";
import { ValueType } from "../common/settings";
import { CustomSelectDialog, NewPasswordInputDialog, PasswordInputDialog } from "../components/dialog";
import {
    EVENT_EXPORT_REQUEST,
    EVENT_IMPORT_REQUEST,
    EVENT_UPDATE_PASSWORD, EVENT_UPDATE_SETTING,
    FileExportRequestSchema,
    FileImportRequestSchema,
    SettingUpdateRequestSchema } from "../common/events";
import { picker } from "@kit.CoreFileKit";
import { common } from "@kit.AbilityKit";

interface DividerStyle {strokeWidth: Length; color?: ResourceColor; startMargin?: Length; endMargin?: Length;};
const divider_style: DividerStyle = {strokeWidth:'1px', color:$r('sys.color.comp_divider'), startMargin:6, endMargin:6};

@Component
export struct SettingsPage {
    @Consume navStack: NavPathStack;
    @Consume biometricAvailable: boolean;
    @StorageProp('MasterKeyAvailable') MasterKeyAvailable: boolean = false;

    @StorageProp('settingsEnableManualInput')
    @Watch('onItChanged') EnableManualInput: boolean = false;
    @StorageProp('settingsEnableBiometricUnlock')
    @Watch('onItChanged') EnableBiometricUnlock: boolean = false;

    @State ShowIssuerIcons: boolean = true;
    @State ShowAccountName: boolean = true;
    @State BioMetricEnabled: boolean = this.biometricAvailable && this.EnableBiometricUnlock;

    private inputDialogId: number = -1;

    build() {
        NavDestination() {
            RelativeContainer() {
                List({space:10}) {
                    // General
                    ListItemGroupHeader({name: $r('app.string.section_title_general')}).margin({bottom:-6})
                    ListItemGroup({style: ListItemGroupStyle.CARD}) {
                        SettingListToggle({
                            title: $r('app.string.setting_enable_manual_input_title'),
                            selected: this.EnableManualInput
                        })
                    }
                    .divider(divider_style)
                    .backgroundColor($r('sys.color.comp_background_tertiary'))

                    // Outlook
                    ListItemGroupHeader({name: $r('app.string.section_title_outlook')}).margin({bottom:-6})
                    ListItemGroup({style: ListItemGroupStyle.CARD}) {
                        SettingListItem({ title: $r('app.string.setting_language'), preview: $r('app.string.setting_language_system_default') })
                        SettingListToggle({ title: $r('app.string.setting_show_issuer_icons'), selected: this.ShowIssuerIcons, disabled: true })
                        SettingListToggle({ title: $r('app.string.setting_show_account_name'), selected: this.ShowAccountName, disabled: true })
                    }
                    .divider(divider_style)
                    .backgroundColor($r('sys.color.comp_background_tertiary'))

                    // Security
                    ListItemGroupHeader({name: $r('app.string.section_title_security')}).margin({bottom:-6})
                    ListItemGroup({style: ListItemGroupStyle.CARD}) {
                        SettingListItem({
                            title: $r('app.string.setting_setup_password'),
                            description: $r('app.string.setting_setup_password_hint'),
                            preview: this.MasterKeyAvailable ?$r('app.string.setting_password_confirmed') : undefined,
                        }).onClick(() => { this.handleSetupPassword() })
                        // enable biometric only when master password available
                        if (this.MasterKeyAvailable) {
                            SettingListToggle({
                                title: $r('app.string.setting_enable_biometric_unlock'),
                                description: $r('app.string.setting_biometric_unlock_hint'),
                                disabled: true,//!this.biometricAvailable,
                                selected: this.BioMetricEnabled,
                            })
                        }
                    }
                    .divider(divider_style)
                    .backgroundColor($r('sys.color.comp_background_tertiary'))

                    // Import & Export
                    ListItemGroupHeader({name: $r('app.string.section_title_import_export')}).margin({bottom:-6})
                    ListItemGroup({style: ListItemGroupStyle.CARD}) {
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
                        SettingListInfo({
                            title: $r('app.string.setting_about_version'),
                            description: $r('app.string.setting_about_information',
                                $r('app.string.app_version'),
                                $r('app.string.app_icp_string')
                            )
                        })
                        SettingListInfo({
                            title: $r('app.string.setting_official_website'),
                            description: 'https://github.com/iamhyc/Aigis'
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
            }
        }
        .title('Settings', {
            backgroundColor: $r('app.color.color_background')
        })
        .backButtonIcon( new SymbolGlyphModifier($r('sys.symbol.close_sidebar')) )
        .backgroundColor($r('app.color.color_face'))
        .height('100%')
        .width('100%')
    }

    private setDragPlainText(ev: DragEvent, content: string) {
        const textData = new unifiedDataChannel.PlainText
        textData.textContent = content;
        const unifiedData = new unifiedDataChannel.UnifiedData(textData);
        (ev as DragEvent).setData(unifiedData);
    }

    private onItChanged(key: string) {
        let value: ValueType = 0;
        const eventHub = getContext(this).eventHub;

        switch(key) {
            case 'EnableManualInput':
                value = this.EnableManualInput;
                break;
            case 'EnableBiometricUnlock':
                value = this.EnableBiometricUnlock;
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
            promptAction.showToast({ message: 'Password cannot change for now.' });
        }
    }

    @Builder passwordInputDialogBuilder(title: ResourceStr, warning?: ResourceStr, optionText?: ResourceStr, confirm?: (password: string, checked?: boolean) => void, cancel?: () => void) {
        PasswordInputDialog({ title, warning, optionText, confirm, cancel })
    }
    @Builder customSelectDialogBuilder(title: ResourceStr, subtitle: ResourceStr | undefined, entries: ResourceStr[], confirm?: (value: ResourceStr) => void, cancel?: () => void) {
        CustomSelectDialog({ title, subtitle, entries, confirm, cancel })
    }
    private handleImportFromFile() {
        const entries = ['Aigis (.json)'];
        this.showCustomDialog(() => {
            this.customSelectDialogBuilder($r('app.string.setting_import_file_title'), undefined, entries, (value) => {
                let format: string = '';
                switch(value) {
                    case 'Aigis (.json)':
                        format = 'aigis';
                        break;
                    default:
                        return;
                }
                //
                const context = getContext(this) as common.Context;
                const documentViewPicker = new picker.DocumentViewPicker(context);
                const documentSelectOptions = new picker.DocumentSelectOptions();
                documentSelectOptions.maxSelectNumber = 1;
                documentSelectOptions.fileSuffixFilters = ['.json'];
                documentViewPicker.select(documentSelectOptions).then((uris) => {
                    if (uris[0]!==undefined) {
                        const uri = uris[0];
                        this.showCustomDialog(() => {
                            this.passwordInputDialogBuilder(
                                $r('app.string.setting_import_enter_password_title'), undefined,
                                this.MasterKeyAvailable? undefined : $r('app.string.setting_import_enter_password_option_as_master_key'),
                                (password, importPassword) => {
                                    context.eventHub.emit(EVENT_IMPORT_REQUEST, {format, uri, password, importPassword} as FileImportRequestSchema);
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
            }, () => { promptAction.closeCustomDialog(this.inputDialogId); });
        });
    }
    private handleExportToFile() {
        const entries = ['Aigis (.json)'];
        this.showCustomDialog(() => {
            this.customSelectDialogBuilder($r('app.string.setting_export_file_title'), undefined, entries, (value) => {
                let format: string = '';
                const dateStr = new Date().toLocaleString('zh-CN', {hour12: false})
                    .replace(/\/|:/g, '')
                    .split(' ').join('-')
                const documentSaveOptions = new picker.DocumentSaveOptions();
                switch(value) {
                    case 'Aigis (.json)':
                        format = 'aigis';
                        documentSaveOptions.newFileNames = [`aigis-${dateStr}.json`];
                        documentSaveOptions.fileSuffixChoices = ['.json'];
                        break;
                    default:
                        return;
                }
                //
                const context = getContext(this) as common.Context;
                const documentViewPicker = new picker.DocumentViewPicker(context);
                documentViewPicker.save(documentSaveOptions).then((uris) => {
                    if (uris[0]!==undefined) {
                        const uri = uris[0];
                        context.eventHub.emit(EVENT_EXPORT_REQUEST, {format, uri} as FileExportRequestSchema);
                    }
                });
                //
                promptAction.closeCustomDialog(this.inputDialogId);
                this.inputDialogId = -1;
            }, () => { promptAction.closeCustomDialog(this.inputDialogId); })
        });
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