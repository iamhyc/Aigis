
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
    @Prop title: ResourceStr =$r('app.string.setting_setup_password_title')
    @Prop warning: ResourceStr = $r('app.string.setting_setup_password_warning')
    @State password: string = ''
    @State password_re: string = ''

    confirm?: (password: string) => void

    build() {
        Scroll() {
            Column({space:16}) {
                Column({space:6}) {
                    Text(this.title)
                        .fontWeight(FontWeight.Medium)
                        .fontSize(20)
                    Text(this.warning)
                        .fontColor($r('sys.color.warning'))
                        .fontSize(14)
                }
                .width('90%')
                //
                Column({space:6}) {
                    TextInput({ placeholder: $r('app.string.setting_setup_password_placeholder'), text: $$this.password })
                        .type(InputType.NEW_PASSWORD)
                        .contentType(ContentType.NEW_PASSWORD)
                        .width('90%')
                    if (this.password!=='' && !this.checkPasswordStrength()) {
                        Text($r('app.string.setting_setup_password_security_hint'))
                            .fontColor($r('sys.color.warning'))
                            .fontSize(12)
                    }
                }
                //
                Column({space:6}) {
                    TextInput({ placeholder: $r('app.string.setting_setup_password_re_placeholder'), text: $$this.password_re })
                        .type(InputType.Password)
                        .contentType(ContentType.PASSWORD)
                        .width('90%')
                    if (this.password!=='' && this.password!==this.password_re) {
                        Text($r('app.string.setting_setup_password_not_match'))
                            .fontColor($r('sys.color.warning'))
                            .fontSize(12)
                    }
                }
                //
                Button($r('app.string.button_text_ok'))
                    .height('36vp')
                    .width('60%')
                    .onClick(() => {
                        if (this.checkPasswordStrength() && this.password===this.password_re) {
                            this.confirm && this.confirm(this.password);
                        }
                    })
                    .enabled( this.password===this.password_re && this.checkPasswordStrength() )
            }
            .padding({top:16, bottom:16})
            .borderRadius(10)
        }
        .scrollBar(BarState.Off)
    }

    private checkPasswordStrength(): boolean {
        // check password length
        if (this.password.length < 8 || this.password.length > 32) {
            return false;
        }
        return true;
    }
}
