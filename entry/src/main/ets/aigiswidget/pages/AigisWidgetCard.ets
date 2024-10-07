import { mediaquery } from '@kit.ArkUI';

@Entry
@Component
struct AigisWidgetCard {
    @State isSmall: boolean = true;
    listener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('screen and (height <= 300vp)');

    aboutToAppear(): void {
        this.listener.on('change', (mediaQueryResult: mediaquery.MediaQueryResult) => {
            this.isSmall = mediaQueryResult.matches;
        });
    }

    aboutToDisappear(): void {
        this.listener.off('change');
    }

    build() {
        FormLink({
            action: 'router',
            abilityName: 'EntryAbility',
        }) {
            if (this.isSmall) {
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
            } else {
                RelativeContainer() {
                    APPIcon({icon_size:36})
                        .padding({left:6,top:6})
                        .height('30%')
                        .width('30%')
                        .id('icon')
                        // .backgroundColor('white')
                    //
                    Row() {
                        Text($r('app.string.entry_card_title_split'))
                            .fontSize(40)
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('app.color.color_face_back'))
                    }
                    .alignRules({
                        top: {anchor:'icon', align:VerticalAlign.Bottom},
                        left: {anchor:'icon', align:HorizontalAlign.End},
                    })
                    .offset({x:6,y:-6})
                    .height('70%')
                    .width('70%')
                    // .backgroundColor('white')
                }
                .height('100%')
                .width('100%')
                .backgroundColor($r('app.color.color_background'))
            }

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
