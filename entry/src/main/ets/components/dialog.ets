
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
                .height(96)
                .width('90%')
            //
            OkCancelButtonGroup({
                cancel: () => { this.cancel && this.cancel(); },
                confirm: () => { this.confirm && this.confirm(this.text); },
                okBtnEnabled: this.text!=='',
            })
        }
        .padding({top: 10, bottom: 10})
        .borderRadius(10)
    }
}

@Component
export struct CustomSelectDialog {
    @Prop selected: number = 0;
    @Require @Prop title: ResourceStr
    @Prop subtitle: ResourceStr
    @Require @Prop entries: string[]
    @Prop descriptions: (ResourceStr|undefined)[]

    confirm?: (value: string) => void
    cancel?: () => void
    toName: (entry: string) => ResourceStr = (x) => x;

    build() {
        Scroll() {
            Column({space:16}) {
                Column({space:6}) {
                    Text(this.title)
                        .textAlign(TextAlign.Center)
                        .fontWeight(FontWeight.Medium)
                        .fontSize(20)
                    if (this.subtitle) {
                        Text(this.subtitle)
                            .textAlign(TextAlign.Center)
                            .fontColor($r('sys.color.font_secondary'))
                            .fontSize(14)
                    }
                }
                .width('90%')
                //
                Select(this.entries.map(x => {
                    return { value: this.toName(x) } as SelectOption
                }))
                    .width('90%')
                    .optionWidth(OptionWidthMode.FIT_TRIGGER)
                    .selected($$this.selected)
                    .value(this.toName(this.entries[this.selected]))
                //
                if (this.descriptions && this.descriptions[this.selected]) {
                    Text(this.descriptions[this.selected])
                        .width('90%')
                        .textAlign(TextAlign.Start)
                        .fontSize(12)
                        .fontColor($r('sys.color.font_secondary'))
                }
                //
                OkCancelButtonGroup({
                    cancel: () => { this.cancel && this.cancel() },
                    confirm: () => {
                        this.confirm && this.confirm( this.entries[this.selected] )
                    },
                })
            }
            .padding({top:16, bottom:16})
            .borderRadius(10)
        }
        .scrollBar(BarState.Off)
    }
}

@Component
export struct PasswordInputDialog {
    @Require @Prop title: ResourceStr
    @Require @Prop usage: ResourceStr
    @Prop optional: boolean | undefined
    @Prop optionText: ResourceStr
    @State password: string = ''
    @State checked: boolean = true

    cancel?: () => void
    confirm?: (password: string, checked?: boolean) => void

    build() {
        Scroll() {
            Column({space:16}) {
                Column({space:6}) {
                    Text(this.title)
                        .fontWeight(FontWeight.Medium)
                        .fontSize(20)
                    Text($r('app.string.password_usage_title', this.usage))
                        .textAlign(TextAlign.Start)
                        .fontColor($r('sys.color.font_secondary'))
                        .fontSize(12)
                }
                .width('90%')
                //
                Column({space:6}) {
                    TextInput({
                        placeholder: this.optional? $r('app.string.setting_setup_password_opt_placeholder') : $r('app.string.setting_setup_password_placeholder'),
                        text: $$this.password })
                        .type(InputType.Password)
                        .contentType(ContentType.PASSWORD)
                        .width('100%')
                    //
                    if (this.optionText) {
                        Row({space:6}) {
                            Checkbox().select($$this.checked)
                            Text(this.optionText)
                                .fontSize(16)
                                .onClick(() => { this.checked = !this.checked; })
                        }.width('100%')
                    }
                }
                .width('90%')
                //
                OkCancelButtonGroup({
                    okBtnEnabled: this.optional || this.password.length >= 8,
                    cancel: () => { this.cancel && this.cancel(); },
                    confirm: () => {
                        if (this.password.length >= 8) {
                            this.confirm && this.confirm(this.password, this.checked);
                        }
                    }
                })
            }
            .padding({top:16, bottom:16})
            .borderRadius(10)
        }
    }
}

@Component
export struct NewPasswordInputDialog {
    @Require @Prop title: ResourceStr
    @Prop warning: ResourceStr
    @State password: string = ''
    @State password_re: string = ''

    cancel?: () => void
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
                OkCancelButtonGroup({
                    okBtnEnabled: this.password===this.password_re && this.checkPasswordStrength(),
                    cancel: () => { this.cancel && this.cancel(); },
                    confirm: () => {
                        if (this.checkPasswordStrength() && this.password===this.password_re) {
                            this.confirm && this.confirm(this.password);
                        }
                    }
                })
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

@Component
export struct ChangePasswordInputDialog {
    @Require @Prop title: ResourceStr
    @Prop warning: ResourceStr
    @State oldPassword: string = ''
    @State newPassword: string = ''
    @State newPasswordRe: string = ''

    cancel?: () => void
    confirm?: (oldPassword: string, newPassword: string) => void

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
                    TextInput({ placeholder: $r('app.string.setting_change_password_old_placeholder'), text: $$this.oldPassword })
                        .type(InputType.Password)
                        .contentType(ContentType.PASSWORD)
                        .width('90%')
                }
                //
                Column({space:6}) {
                    TextInput({ placeholder: $r('app.string.setting_change_password_new_placeholder'), text: $$this.newPassword })
                        .type(InputType.NEW_PASSWORD)
                        .contentType(ContentType.NEW_PASSWORD)
                        .width('90%')
                    if (this.newPassword!=='' && !this.checkPasswordStrength()) {
                        Text($r('app.string.setting_setup_password_security_hint'))
                            .fontColor($r('sys.color.warning'))
                            .fontSize(12)
                    } else if (this.oldPassword!=='' && this.oldPassword===this.newPassword) {
                        Text($r('app.string.setting_input_same_password'))
                            .fontColor($r('sys.color.warning'))
                            .fontSize(12)
                    }
                }
                //
                Column({space:6}) {
                    TextInput({ placeholder: $r('app.string.setting_change_password_new_re_placeholder'), text: $$this.newPasswordRe })
                        .type(InputType.Password)
                        .contentType(ContentType.PASSWORD)
                        .width('90%')
                    if (this.newPassword!=='' && this.newPassword!==this.newPasswordRe) {
                        Text($r('app.string.setting_setup_password_not_match'))
                            .fontColor($r('sys.color.warning'))
                            .fontSize(12)
                    }
                }
                //
                OkCancelButtonGroup({
                    okBtnEnabled: this.oldPassword!==this.newPassword && this.newPassword===this.newPasswordRe && this.checkPasswordStrength(),
                    cancel: () => { this.cancel && this.cancel(); },
                    confirm: () => {
                        if (this.checkPasswordStrength() && this.newPassword===this.newPasswordRe) {
                            this.confirm && this.confirm(this.oldPassword, this.newPassword);
                        }
                    }
                })
            }
            .padding({top:16, bottom:16})
            .borderRadius(10)
        }
        .scrollBar(BarState.Off)
    }

    private checkPasswordStrength(): boolean {
        // check password length
        if (this.newPassword.length < 8 || this.newPassword.length > 32 ) {
            return false;
        }
        return true;
    }
}

@Component
struct OkCancelButtonGroup {
    @Prop okBtnEnabled: boolean = true

    cancel?: () => void
    confirm?: () => void

    build() {
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
                    .enabled( this.okBtnEnabled )
                    .onClick(() => {
                        this.confirm && this.confirm();
                    })
            }
        }
        .height(36)
        .width('90%')
        .layoutDirection(GridDirection.Row)
        .columnsTemplate('2fr 3fr')
        .columnsGap(10)
    }
}
