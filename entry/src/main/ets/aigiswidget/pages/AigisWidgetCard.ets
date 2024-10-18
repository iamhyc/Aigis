import { mediaquery } from '@kit.ArkUI';

@Entry
@Component
struct AigisWidgetCard {
    listener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('screen and (height <= 100vp)');

    build() {
        FormLink({
            action: 'router',
            abilityName: 'EntryAbility',
        }) {
            Row() {
                Column() {
                    APPIcon({icon_size:32})
                }
                .width('25%')
                .padding({left:20})
                //
                Column() {
                    Text($r('app.string.entry_card_title'))
                        .fontSize($r('sys.float.Subtitle_L'))
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.color_face_back'))
                }.width('75%')
            }
            .height('100%')
            .width('100%')
            .backgroundColor($r('app.color.color_background'))
        }
    }
}

@Component
struct APPIcon {
    @State icon_size: number = 32;

    build() {
        Image($r('app.media.app_icon'))
            .height(this.icon_size)
            .width(this.icon_size)
            .borderRadius(this.icon_size / 2)
    }
}
