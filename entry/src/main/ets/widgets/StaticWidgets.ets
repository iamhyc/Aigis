import { FormDimension } from ".";

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

@Builder
export function EntryCardBuilder(dimension: FormDimension) {
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
    .height(dimension.height)
    .width(dimension.width)
    .borderRadius(dimension.radius)
    .backgroundColor($r('app.color.color_background'))
}

export const EntryCardBuilderWrapper: WrappedBuilder<[FormDimension]> = wrapBuilder(EntryCardBuilder);
