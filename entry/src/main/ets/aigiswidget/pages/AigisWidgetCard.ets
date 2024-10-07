@Entry
@Component
struct AigisWidgetCard {
    /*
     * The ability name.
     */
    readonly ABILITY_NAME: string = 'EntryAbility';

    build() {
        FormLink({
            action: 'router',
            abilityName: this.ABILITY_NAME,
            params: { message: $r('app.string.entry_card_title') }
        }) {
            Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.app_icon'))
                    .borderRadius($r('app.float.issuer_icon_radius'))
                    .height($r('app.float.issuer_icon_size'))
                Column() {
                    Text($r('app.string.entry_card_title'))
                        .fontSize($r('sys.float.Subtitle_L'))
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.color_face_back'))
                }
                .width('100%')
            }
            .height('100%')
            .backgroundColor($r('app.color.color_background'))
        }
    }
}