
@Component
export struct settingToggle {
    @Link selected: boolean
    @Require @Prop title: ResourceStr
    @Prop description: ResourceStr | undefined
    @Prop type: ToggleType = ToggleType.Switch
    @State toggleWidth: number = this.type===ToggleType.Switch ? 48: 56

    build() {
        Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
            Column() {
                Row() {
                    Text(this.title)
                        .fontWeight(FontWeight.Medium)
                        .fontSize(16)
                }
                .padding({left:6})
                .width('100%')
                //
                if (this.description) {
                    Row() {
                        Text(this.description)
                            .fontColor($r('sys.color.font_secondary'))
                            .fontSize(14)
                    }
                    .width('100%')
                }
            }
            .width('100%')
            .flexBasis('auto')
            //
            Column() {
                Toggle({type: this.type, isOn: $$this.selected})
            }
            .flexBasis(this.toggleWidth)
        }
        .height(48)
        .width('100%')
    }
}
