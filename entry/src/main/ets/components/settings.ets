
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
export struct SettingListInfo {
    @Require @Prop title: ResourceStr
    @Require @Prop description: ResourceStr | undefined

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description })
            }
            .height('auto')
            .width('100%')
        }
    }
}

@Component
export struct SettingListItem {
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop preview: ResourceStr | undefined
    @Prop disabled: boolean = false

    build() {
        ListItem() {
            Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
                InformationArea({ title: this.title, description: this.description, disabled: this.disabled })
                //
                if (this.preview) {
                    Column() {
                        Text(this.preview)
                            .fontSize(14)
                            .fontColor($r('sys.color.font_secondary'))
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
    }
}

@Component
export struct SettingListToggle {
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
