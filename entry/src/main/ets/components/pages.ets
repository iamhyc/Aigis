import { AtlAuthResult } from "../common/schema";
import { LengthUnit } from "@kit.ArkUI";
import { acquireAtlAuth, AuthLevelSupport } from "../crypto/authUtils";
import { AuthTypePriority } from '../common/settings';

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
