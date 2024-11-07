import { unifiedDataChannel } from "@kit.ArkData"
import { pasteboard } from "@kit.BasicServicesKit"
import { promptAction } from "@kit.ArkUI"

function copyToPasterBoard(text: string, callback: () => void) {
    const textData = new unifiedDataChannel.PlainText();
    textData.textContent = text;
    const unifiedData = new unifiedDataChannel.UnifiedData(textData);
    unifiedData.properties.shareOptions = unifiedDataChannel.ShareOptions.CROSS_APP;
    pasteboard.getSystemPasteboard().setUnifiedData(unifiedData)
        .then(() => {callback()});
}

@Component
struct InformationArea {
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop disabled: boolean = false
    @Prop titleFontSize: number = 16;//fp

    build() {
        Column({space:3}) {
            Row() {
                Text(this.title)
                    .fontWeight(FontWeight.Medium)
                    .fontSize(this.titleFontSize)
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
                            copyToPasterBoard(this.clickToCopy, () => {
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
export struct SettingListCollapsableItem {
    @Link collapsed: boolean
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop preview: ResourceStr | undefined
    @Prop disabled: boolean = false
    @Prop collapsable: boolean = false
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
                        .rotate((this.collapsable && !this.collapsed)? {angle:90} : {angle:0})
                        .translate((this.collapsable && !this.collapsed) ? {x:-3} : {})
                }
                .height(48)
                .flexBasis(28)
                .flexShrink(0)
            }
            .height('auto')
            .width('100%')
        }
        .clickEffect(!this.disabled? { level: ClickEffectLevel.MIDDLE } : null)
        .onClick(() => {
            if (this.collapsable) {
                animateTo({ duration: 200, curve: Curve.Sharp }, () => {
                    this.collapsed = !this.collapsed;
                });
            }
        })
    }
}

@Component
export struct SettingListIconItem {
    @Require @Prop title: ResourceStr
    @Require @Prop description: ResourceStr
    @Prop checked: boolean = false
    @State radioSize: number = 20;
    @State iconSize: number = 32;
    @State glyphSize: number = 20;

    onApply?: () => void;
    onRemove?: () => void;

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                Column() {
                    Radio({ value: '', group: 'IconPackItem' })
                        .height(this.radioSize).width(this.radioSize)
                        .checked($$this.checked)
                        .onChange((isChecked) => {
                            if (isChecked && this.onApply) {
                                this.onApply();
                            }
                        })
                }
                .flexBasis(this.radioSize+20)
                //
                InformationArea({ title: this.title, description: this.description, titleFontSize: 14 })
                    .clickEffect({level:ClickEffectLevel.MIDDLE})
                    .onClick(() => {
                        this.checked = true;
                    })
                //
                Column() {
                    Button({ type: ButtonType.Circle }) {
                        SymbolGlyph($r('sys.symbol.trash_fill'))
                            .fontColor([$r('sys.color.warning')])
                            .fontSize(this.glyphSize)
                    }
                    .height(this.iconSize).width(this.iconSize)
                    .backgroundColor($r('sys.color.ohos_id_list_background_color'))
                    .onClick(() => { this.onRemove && this.onRemove(); })
                }
                .flexBasis(this.iconSize+24)
            }
            .height('auto')
            .width('100%')
        }
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
                    Row() {
                        Toggle({type: this.type, isOn: $$this.selected})
                            .enabled(!this.disabled)
                            .onChange((isOn) => { this.onChange && this.onChange(isOn); })
                    }
                    .height('100%')
                    .alignItems(VerticalAlign.Center)
                }
                .height(48)
                .flexBasis(this.toggleWidth)
            }
            .height('auto')
            .width('100%')
        }
    }
}

@Component
export struct NoInternetHyperLink {
    @Require @Prop link: string
    @Prop text: string
    @Prop fontSize: number = 14

    build () {
        Text(this.text ?? this.link)
            .fontColor($r('sys.color.font_emphasize'))
            .fontSize(this.fontSize)
            .decoration({
                type: TextDecorationType.Underline,
                color: $r('sys.color.font_emphasize'),
            })
            .onClick(() => {
                copyToPasterBoard(this.link, () => {
                    const message = $r('app.string.prompt_website_copied');
                    promptAction.showToast({message, duration:500});
                });
            })
            .onDragStart(ev => {
                const textData = new unifiedDataChannel.PlainText
                textData.textContent = this.link;
                const unifiedData = new unifiedDataChannel.UnifiedData(textData);
                (ev as DragEvent).setData(unifiedData);
            })
    }
}
