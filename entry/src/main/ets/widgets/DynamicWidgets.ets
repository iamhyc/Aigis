import { FormDimension } from ".";
import { OTPItemInfo } from "../common/schema";
import { IssuerIcon } from "../components/icons";
import { TimedOTPSchema } from "../crypto/otpUtils";

@Component
struct ItemWidgetComponent {
    @Require @Prop keyAlias: string;
    @Require @Prop formImages: Record<string,number>;
    @Require @Prop itemInfo: OTPItemInfo;
    @Require @Prop dimension: FormDimension;
    @State showCode: boolean = false;
    @State leftTime: number = 0;

    private textTimerController: TextTimerController = new TextTimerController()
    updateRequestFn?: () => void;

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            // Main Content
            Row({space:8}) {
                // display issuer icon
                // if (this.formImages) {
                //     Column()
                //         .margin({left: 8})
                //         .borderRadius(16)
                //         .height(32)
                //         .width(32)
                //         .backgroundImage('memory://icon')
                //         .backgroundImageSize(ImageSize.Cover)
                // } else {
                    IssuerIcon({
                        issuer: this.itemInfo.schema.issuer,
                        iconSize: '32vp',
                        iconRadius: '16vp',
                        fontSize: 14,
                    })
                        .margin({left: 8})
                // }
                // display information area
                Column({ space: '4vp' }) {
                    Text() {
                        Span(this.itemInfo.schema.issuer)
                            .fontSize(12)
                            .fontWeight(FontWeight.Bold)
                            .fontColor($r('sys.color.font_primary'))
                        Span(` (${this.itemInfo.schema.name})`)
                            .fontSize(10)
                            .fontWeight(FontWeight.Normal)
                            .fontColor($r('sys.color.font_secondary'))
                    }
                    .lineHeight(20)
                    .maxLines(1)
                    .textOverflow({overflow: TextOverflow.Ellipsis})
                    .wordBreak(WordBreak.BREAK_ALL)
                    //
                    Text() {
                        if (this.showCode) {
                            Span(this.itemInfo.code.code)
                                .fontSize(12)
                                .letterSpacing(1)
                        } else {
                            Span('⬤'.repeat(this.itemInfo.schema.digits))
                                .fontWeight(FontWeight.Medium)
                                .fontSize(10)
                                .letterSpacing(1)
                        }
                    }
                }
                .width(`calc(100% - 16vp - 32vp - 4vp)`)
                .alignItems(HorizontalAlign.Start)
            }
            .height('100%')
            .width('100%')
            .align(Alignment.Top)
            .zIndex(1)
            .clip(true)
            // show progress bar for time-based OTP
            if (this.showCode && (this.itemInfo.schema as TimedOTPSchema).period) {
                Progress({value: this.leftTime, total:(this.itemInfo.schema as TimedOTPSchema).period*1000})
                    .color($r('app.color.color_ribbon'))
                    .height('2vp')
                    .width('calc(100% - 20vp)')
                    .zIndex((2))
                    .style({enableSmoothEffect:true})
                TextTimer({ isCountDown: true, count: 30000, controller: this.textTimerController })
                    .format('ss')
                    .width('100%')
                    .fontSize('1px')
                    .onTimer(() => {
                        this.leftTime = Date.now() % ((this.itemInfo.schema as TimedOTPSchema).period*1000);
                    })
                    .onAppear(() => {
                        this.textTimerController.start()
                    })
            }
        }
        .height(this.dimension.height)
        .width(this.dimension.width)
        .borderRadius(this.dimension.radius)
        .backgroundColor($r('app.color.color_background'))
        .onClick(() => {
            if (this.updateRequestFn) {
                this.showCode = !this.showCode;
                this.updateRequestFn();
            }
        })
    }
}

@Builder
export function ItemWidgetBuilder(keyAlias: string, formImages: Record<string,number>, itemInfo: OTPItemInfo, dimension: FormDimension, updateRequestFn?: () => void) {
    ItemWidgetComponent({ keyAlias, formImages, itemInfo, dimension, updateRequestFn })
}

export const ItemWidgetBuilderWrapper: WrappedBuilder<[string, Record<string,number>, OTPItemInfo, FormDimension]> = wrapBuilder(ItemWidgetBuilder);
