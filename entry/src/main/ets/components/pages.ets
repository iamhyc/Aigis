import { AtlAuthResult, MasterKeyInfo } from "../common/schema";
import { LengthUnit, promptAction } from "@kit.ArkUI";
import { acquireAtlAuth, AuthLevelSupport, validatePassword } from "../crypto/authUtils";
import { AuthTypePriority, PasswordReminderPeriod } from '../common/settings';
import { EVENT_UPDATE_PASSWORD_CHALLENGE_TIME, UpdatePasswordChallengeTimeSchema } from "../common/events";
import { ONE_DAY_IN_MS, PREF_PASSWORD_CHALLENGE_TIME } from "../common/conts";

@Component
export struct AppLockPage {
    @Link atlAuth: AtlAuthResult;
    @Require @Prop authLevel: AuthLevelSupport;
    @Require @Prop priority: AuthTypePriority;

    build() {
        Flex({
            direction: FlexDirection.Column,
            justifyContent: FlexAlign.Center,
            alignItems: ItemAlign.Center,
            space: { main:{value:12, unit:LengthUnit.VP} }
        }) {
            //
            Text() {
                SymbolSpan($r('sys.symbol.key_shield_fill'))
            }
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontSize(72)
            //
            Text($r('app.string.lock_page_title'))
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .fontWeight(FontWeight.Medium)
                .fontSize(18)
            //
            Text($r('app.string.lock_page_hint'))
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .fontSize(16)
                .textAlign(TextAlign.Center)
        }
        .height('100%')
        .width('80%')
        .onClick(async () => {
            this.atlAuth = await acquireAtlAuth(this.authLevel, this.priority);
        })
    }
}

@Component
export struct PasswordChallengePage {
    @StorageProp('EncMasterKey') EncMasterKey: MasterKeyInfo = {} as MasterKeyInfo;
    @StorageProp(PREF_PASSWORD_CHALLENGE_TIME) PasswordChallengeTime: number = Date.now();
    @StorageProp('settingsPasswordReminderPeriod') PasswordReminderPeriod: PasswordReminderPeriod = 'biweekly';
    @State password: string = '';

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            Flex({
                direction: FlexDirection.Column,
                justifyContent: FlexAlign.Center,
                alignItems: ItemAlign.Center,
                space: { main:{value:16, unit:LengthUnit.VP} }
            }) {
                Text() {
                    SymbolSpan($r('sys.symbol.hand_raised_hexagon_fill'))
                }
                .fontColor($r('sys.color.font_secondary'))
                .fontSize(96)
                //
                Text($r('app.string.password_challenge_page_title'))
                    .fontColor($r('sys.color.font_secondary'))
                    .fontWeight(FontWeight.Medium)
                    .fontSize(24)
                //
                Text($r('app.string.password_challenge_page_hint'))
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .fontSize(16)
                    .textAlign(TextAlign.Center)
                //
                TextInput({ placeholder: $r('app.string.setting_setup_password_placeholder'), text: $$this.password })
                    .width('100%')
                    .defaultFocus(true)
                    .type(InputType.Password)
                    .contentType(ContentType.PASSWORD)
                    .onSubmit(async () => { await this.verifyPassword(); })
                Button($r('app.string.button_text_confirm'))
                    .width('100%')
                    .enabled(this.password.length >= 8)
                    .onClick(async () => { await this.verifyPassword(); })
            }
            .height('100%')
            .width('75%')
            //
            Text($r('app.string.password_challenge_page_bypass_title', ''))
                .fontColor($r('sys.color.brand_font'))
                .fontSize(14)
                .onClick(() => { this.showPrompt(); })
        }
    }

    aboutToAppear() {
        if (this.EncMasterKey.keyAlias===undefined) {
            const timestamp = Date.now();
            getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD_CHALLENGE_TIME, {timestamp} as UpdatePasswordChallengeTimeSchema);
        }
    }

    private async verifyPassword() {
        if (this.password.length >= 8) {
            if ((await validatePassword(this.EncMasterKey, this.password))) {
                const timestamp = Date.now();
                getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD_CHALLENGE_TIME, {timestamp} as UpdatePasswordChallengeTimeSchema);
            } else {
                promptAction.showToast({message:$r('app.string.setting_input_wrong_password'), duration:500});
            }
        }
    }

    private showPrompt() {
        const _now = Date.now();
        let timestamp = this.PasswordChallengeTime + ONE_DAY_IN_MS;
        switch (this.PasswordReminderPeriod) {
            case 'weekly':
                timestamp = _now - (7-1)*ONE_DAY_IN_MS; break;
            case 'biweekly':
                timestamp = _now - (14-1)*ONE_DAY_IN_MS; break;
            case 'monthly':
                timestamp = _now - (30-1)*ONE_DAY_IN_MS; break;
            case 'quarterly':
                timestamp = _now - (90-1)*ONE_DAY_IN_MS; break;
        }
        AlertDialog.show({
            title: $r('app.string.password_challenge_page_bypass_title', '⚠ '),
            message: $r('app.string.password_challenge_page_bypass_hint'),
            primaryButton: {
                value: $r('app.string.button_text_ok'),
                defaultFocus: true,
                style: DialogButtonStyle.DEFAULT,
                action: () => {
                    getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD_CHALLENGE_TIME, {timestamp} as UpdatePasswordChallengeTimeSchema);
                },
            }
        })
    }
}

@Component
export struct QrCodePage {
    @Require @Prop title: ResourceStr;
    @Require @Prop uris: string[];
    @Prop label_main: string[] = [];
    @Prop label_sub: string[] = [];
    @State currentIndex: number = 0;

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            Flex({
                direction: FlexDirection.Column,
                justifyContent: FlexAlign.Center,
                alignItems: ItemAlign.Center,
                space: { main:{value:12, unit:LengthUnit.VP} }
            }) {
                Text(this.title)
                    .fontSize(24)
                    .fontWeight(FontWeight.Medium)
                //
                QRCode(this.uris[this.currentIndex])
                    .color($r('app.color.color_face'))
                    .backgroundColor($r('app.color.color_face_back'))
                    .border({width:'10vp', color:$r('app.color.color_face_back')})
                //
                if (this.label_main.length > 0) {
                    Text(this.label_main[this.currentIndex])
                        .fontSize(16)
                        .fontColor($r('sys.color.font_primary'))
                        .fontWeight(FontWeight.Medium)
                    if (this.label_sub) {
                        Text(this.label_sub[this.currentIndex])
                            .fontSize(14)
                            .fontColor($r('sys.color.font_secondary'))
                            .margin({top:'-6vp'})
                    }
                }
            }
            .height('100%')
            .width('80%')
            //
            RelativeContainer() {
                if (this.currentIndex!==0) {
                    Text($r('app.string.edit_share_stepper_prev'))
                        .fontColor($r('sys.color.brand_font'))
                        .fontSize(16)
                        .onClick(() => { this.currentIndex -= 1; })
                        .alignRules({
                            'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
                            'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start },
                        })
                }
                //
                Text($r('app.string.edit_share_stepper', `${this.currentIndex+1}/${this.uris.length}`))
                    .fontColor($r('sys.color.font_primary'))
                    .fontSize(16)
                    .alignRules({
                        'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
                        'middle': { 'anchor': '__container__', 'align': HorizontalAlign.Center },
                    })
                //
                if (this.currentIndex!==this.uris.length-1) {
                    Text($r('app.string.edit_share_stepper_next'))
                        .fontColor($r('sys.color.brand_font'))
                        .fontSize(16)
                        .onClick(() => { this.currentIndex += 1; })
                        .alignRules({
                            'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
                            'right': { 'anchor': '__container__', 'align': HorizontalAlign.End },
                        })
                }
            }
            .height('auto')
            .width('100%')
        }
    }
}
