
// Reference: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-modal-dialog-V5
@Component
export struct TextInputDialog {
    @Require @Prop title: ResourceStr
    @Require @Prop placeholder: ResourceStr
    @State text: string = ''

    cancel?: () => void
    confirm?: (text: string) => void

    build() {
        Column({space:10}) {
            Text(this.title)
                .fontWeight(FontWeight.Medium)
                .fontSize(20)
            //
            TextArea({ placeholder: this.placeholder, text: $$this.text })
                .height(72)
                .width('90%')
            //
            Grid() {
                GridItem() {
                    Button($r('app.string.button_text_cancel'))
                        .height('36vp')
                        .width('100%')
                        .backgroundColor($r('sys.color.comp_background_secondary'))
                        .onClick(() => { this.cancel && this.cancel(); })
                }
                GridItem() {
                    Button($r('app.string.button_text_ok'))
                        .height('36vp')
                        .width('100%')
                        .onClick(() => { this.confirm && this.confirm(this.text); })
                }
            }
            .height(36)
            .width('90%')
            .layoutDirection(GridDirection.Row)
            .columnsTemplate('2fr 3fr')
            .columnsGap(10)
        }
        .padding({top: 10, bottom: 10})
        .borderRadius(10)
    }
}

@Component
export struct PasswordInputDialog {
    @Require @Prop title: ResourceStr
    @State placeholder_new: ResourceStr = ''
    @State placeholder_re: ResourceStr = ''
    @State password: string = ''
    @State password_re: string = ''

    cancel?: () => void
    confirm?: (password: string) => void

    build() {
        Column({space:10}) {
            Text(this.title)
                .fontWeight(FontWeight.Medium)
                .fontSize(20)
            //
            Row() {
                TextInput({ placeholder: this.placeholder_new, text: $$this.password })
                    .type(InputType.NEW_PASSWORD)
                    .contentType(ContentType.NEW_PASSWORD)
            }
            .width('90%')
            if (this.password!=='' && !this.checkPasswordStrength()) {
                Text('')
                    .fontColor($r('sys.color.warning'))
                    .fontSize(14)
            }
            //
            Row() {
                TextInput({ placeholder: this.placeholder_new, text: $$this.password_re })
                    .type(InputType.Password)
                    .contentType(ContentType.PASSWORD)
            }
            .width('90%')
            if (this.password!=='' && this.password!==this.password_re) {
                Text('')
                    .fontColor($r('sys.color.warning'))
                    .fontSize(14)
            }
            //
            Grid() {
                GridItem() {
                    Button($r('app.string.button_text_cancel'))
                        .height('36vp')
                        .width('100%')
                        .backgroundColor($r('sys.color.comp_background_secondary'))
                        .onClick(() => { this.cancel && this.cancel(); })
                }
                GridItem() {
                    Button($r('app.string.button_text_ok'))
                        .height('36vp')
                        .width('100%')
                        .onClick(() => {
                            if (this.checkPasswordStrength() && this.password===this.password_re) {
                                this.confirm && this.confirm(this.password);
                            }
                        })
                }
            }
            .height(36)
            .width('90%')
            .layoutDirection(GridDirection.Row)
            .columnsTemplate('2fr 3fr')
            .columnsGap(10)
        }
        .padding({top: 10, bottom: 10})
        .borderRadius(10)
    }

    private checkPasswordStrength(): boolean {
        return true;
    }
}
