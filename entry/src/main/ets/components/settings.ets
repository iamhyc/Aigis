import { unifiedDataChannel } from "@kit.ArkData"
import { pasteboard } from "@kit.BasicServicesKit"
import { promptAction } from "@kit.ArkUI"

@Component
struct InformationArea {
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop disabled: boolean = false

    build() {
        Column({space:3}) {
            Row() {
                Text(this.title)
                    .fontWeight(FontWeight.Medium)
                    .fontSize(16)
                    .fontColor(this.disabled ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
            }
            .padding({left:6})
            .width('100%')
            //
            if (this.description) {
                Row() {
                    Text(this.description)
                        .fontColor($r('sys.color.font_secondary'))
                        .fontSize(12)
                }
                .padding({left:6})
                .width('100%')
            }
        }
        .padding({top:6,bottom:6})
        .width('100%')
        .flexBasis('auto')
        .flexShrink(2)
    }
}

@Component
export struct SettingListItemInfo {
    @Require @Prop title: ResourceStr
    @Require @Prop description: ResourceStr | undefined
    @Prop clickToCopy: string
    @Prop copyPrompt: ResourceStr

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description })
            }
            .height('auto')
            .width('100%')
            .clickEffect(this.clickToCopy? { level: ClickEffectLevel.MIDDLE } : null)
            .gesture(
                LongPressGesture({duration: 750})
                    .onAction(() => {
                        if (this.clickToCopy) {
                            const textData = new unifiedDataChannel.PlainText();
                            textData.textContent = this.clickToCopy;
                            const unifiedData = new unifiedDataChannel.UnifiedData(textData);
                            unifiedData.properties.shareOptions = unifiedDataChannel.ShareOptions.CROSS_APP;
                            pasteboard.getSystemPasteboard().setUnifiedData(unifiedData)
                                .then(() => {
                                    const message = this.copyPrompt ?? 'Copied';
                                    promptAction.showToast({message, duration:500});
                                });
                        }
                    })
            )
        }
    }
}

@Component
export struct SettingListItem {
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop preview: ResourceStr | undefined
    @Prop disabled: boolean = false
    @State previewColor: ResourceStr = this.disabled? $r('sys.color.warning') : $r('sys.color.font_secondary')

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description, disabled: this.disabled })
                //
                if (this.preview) {
                    Column() {
                        Text(this.preview)
                            .fontSize(14)
                            .fontColor(this.previewColor)
                            .maxLines(2)
                            .width('100%')
                            .textAlign(TextAlign.End)
                    }
                    .flexBasis('auto')
                    .flexShrink(3)
                }
                //
                Column() {
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontColor([$r('sys.color.font_tertiary')])
                        .fontSize(24)
                        .height(48)
                        .align(Alignment.Center)
                }
                .height(48)
                .flexBasis(28)
                .flexShrink(0)
            }
            .height('auto')
            .width('100%')
        }
        .clickEffect(!this.disabled? { level: ClickEffectLevel.MIDDLE } : null)
    }
}

@Component
export struct SettingListItemSelect {
    @Link selected: string
    @Require @Prop entries: Map<ResourceStr, string>
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop disabled: boolean = false

    _entries: ResourceStr[] = Array.from(this.entries.keys());
    _values: string[] = Array.from(this.entries.values());
    @State _selected: number = this._values.indexOf(this.selected)

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description, disabled: this.disabled })
                //
                Select(this._entries.map(x => {
                    return {value: x} as SelectOption
                }))
                    .onSelect((idx) => { this.selected = this._values[idx]; })
                    .selected($$this._selected)
                    .value( this._entries[this._selected] )
                    .font({size: 14}).optionFont({size:14}).selectedOptionFont({size:14})
                    .fontColor($r('sys.color.font_secondary'))
                    .backgroundColor($r('sys.color.ohos_id_list_background_color'))
                    .optionWidth(OptionWidthMode.FIT_CONTENT)
                    .controlSize(ControlSize.SMALL)
                    .menuAlign(MenuAlignType.END)
                    .width('auto')
                    .height(48)
            }
            .height('auto')
            .width('100%')
        }
    }
}

@Component
export struct SettingListItemToggle {
    @Link selected: boolean
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop disabled: boolean = false
    @Prop type: ToggleType = ToggleType.Switch
    @State toggleWidth: number = this.type===ToggleType.Switch ? 48: 56

    onChange?: (isOn: boolean) => void;

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description })
                //
                Column() {
                    Toggle({type: this.type, isOn: $$this.selected})
                        .enabled(!this.disabled)
                        .onChange((isOn) => { this.onChange && this.onChange(isOn); })
                }
                .flexBasis(this.toggleWidth)
            }
            .height(48)
            .width('100%')
        }
    }
}
