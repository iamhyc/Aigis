import { SymbolGlyphModifier } from "@kit.ArkUI";
import { unifiedDataChannel } from "@kit.ArkData";
import { settingToggle } from "../components/settings";
import { EVENT_UPDATE_SETTING, SettingUpdateRequestSchema } from "../common/schema";

@Preview
@Component
export struct SettingsPage {
    @Consume navStack: NavPathStack;
    @StorageProp('settingsEnableManualInput')
    @Watch('onItChanged') EnableManualInput: boolean = false;

    build() {
        NavDestination() {
            RelativeContainer() {
                List({space:10}) {
                    // General
                    ListItem() { this.sectionHeader($r('app.string.section_title_general')) }.margin({bottom:-6})
                    ListItemGroup({style: ListItemGroupStyle.CARD}) {
                        ListItem() {
                            settingToggle({
                                title: $r('app.string.setting_enable_manual_input_title'),
                                selected: this.EnableManualInput
                            })
                        }
                    }
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    // Outlook
                    ListItem() { this.sectionHeader($r('app.string.section_title_outlook')) }.margin({bottom:-6})
                    // ListItemGroup({style: ListItemGroupStyle.CARD}) {}
                    // .backgroundColor($r('sys.color.comp_background_tertiary'))
                    // Security
                    ListItem() { this.sectionHeader($r('app.string.section_title_security')) }.margin({bottom:-6})
                    // ListItemGroup({style: ListItemGroupStyle.CARD}) {}
                    // .backgroundColor($r('sys.color.comp_background_tertiary'))
                    // Import & Export
                    ListItem() { this.sectionHeader($r('app.string.section_title_import_export')) }
                    // ListItemGroup({style: ListItemGroupStyle.CARD}) {}
                    // .backgroundColor($r('sys.color.comp_background_tertiary'))
                }
                .padding({top:10, bottom:10})
                .divider({strokeWidth:'1px'})
                .alignListItem(ListItemAlign.Center)
                // license info
                Column() {
                    Row() {
                        Hyperlink('https://github.com/iamhyc/Aigis', $r('app.string.string_text_repo', 'GitHub'))
                            .height(14)
                            .onClick(() => {})
                            .onDragStart((ev) => {
                                this.setDragPlainText(ev, 'https://github.com/iamhyc/Aigis')
                            })
                        Text('  |  ')
                            .fontSize(14)
                            .fontColor($r('sys.color.font_tertiary'))
                        Hyperlink('https://gitcode.com/iamhyc/Aigis', $r('app.string.string_text_repo', 'GitCode'))
                            .height(14)
                            .onClick(() => {})
                            .onDragStart((ev) => {
                                this.setDragPlainText(ev, 'https://gitcode.com/iamhyc/Aigis')
                            })
                    }
                    Hyperlink('https://beian.miit.gov.cn/#/Integrated/recordQuery', '粤ICP备2024321498号')
                        .height(14)
                        .onClick(() => {})
                        .onDragStart((ev) => {
                            this.setDragPlainText(ev, 'https://beian.miit.gov.cn/#/Integrated/recordQuery')
                        })
                }
                .width('100%')
                .alignRules({
                    bottom: {anchor: "__container__", align: VerticalAlign.Bottom},
                    left: {anchor: "__container__", align: HorizontalAlign.Start},
                })
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

    @Builder sectionHeader(name: ResourceStr) {
        Text(name)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .width('90%')
    }

    private setDragPlainText(ev: DragEvent, content: string) {
        const textData = new unifiedDataChannel.PlainText
        textData.textContent = content;
        const unifiedData = new unifiedDataChannel.UnifiedData(textData);
        (ev as DragEvent).setData(unifiedData);
    }

    private onItChanged(key: string) {
        const eventHub = getContext(this).eventHub;
        switch(key) {
            case 'EnableManualInput':
                eventHub.emit(EVENT_UPDATE_SETTING, {key, value: this.EnableManualInput} as SettingUpdateRequestSchema)
                break;
            default:
                break;
        }
    }
}
