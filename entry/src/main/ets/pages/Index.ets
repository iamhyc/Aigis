import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';

import { PREF_KEY_ITEMS } from '../common/conts';
import { ScrollEventExtension, ScrollPosition } from '../common/eventExtension';
import { OTPItemInfo, EVENT_CODE_REQUEST, CodeRequestSchema, EVENT_UPDATE_ITEM,
    UpdateRequestSchema,
    CodeResponseSchema} from '../common/schema';
import { OTPSchema, TimedOTPSchema } from '../crypto/otpUtils';
import { Offset, Position } from '@kit.ArkUI';
import { fuzzysearch } from '../common/utils';

const REFRESH_INTERVAL = 250;//ms
const storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];

    build() {
        RelativeContainer() {
            Navigation() {
                Stack() {
                    // main content
                    OTPList({items: this.items})
                    // floating add button
                    QrScanButton()
                }
                .height('100%')
                .width('100%')
            }
            .title($r('app.string.app_title'), {
                backgroundColor: $r('app.color.color_background'),
            })
            .titleMode(NavigationTitleMode.Mini)
            .hideBackButton(true)
            .mode(NavigationMode.Auto)
            .backgroundColor($r('app.color.color_face'))
        }
        .height('100%')
        .width('100%')
    }
}

@Component
struct OTPList {
    @Require @Prop items: OTPItemInfo[];
    @State selected: string = '';
    @State filterText: string = '';
    @State filterItemVisibility: Visibility = Visibility.None;
    @State hasHiddenItems: boolean = false;

    private searchInputHeight = 36;//vp
    private searchInputTopMargin = 8;//vp

    private scrollExtension = new ScrollEventExtension({
        onTopBound: (o) => { this.onTopBound(o) },
        onTopBoundRelease: (o) => { this.onTopBoundRelease(o) },
    });

    private onTopBound(offset: Offset) {
        const _height = this.searchInputHeight + this.searchInputTopMargin;
        if (px2vp(offset.y)>=_height/2 && this.hasHiddenItems) {
            this.filterItemVisibility = Visibility.Visible;
        }
    }

    private onTopBoundRelease(offset: Offset) {
        if (this.filterItemVisibility===Visibility.Visible) {
            this.getUIContext().getFocusController().requestFocus('search_input');
        }
    }

    build() {
        List() {
            // filter entries
            ListItem() {
                Column() {
                    TextInput({text: $$this.filterText, placeholder: $r('app.string.search_hint')})
                        .id('search_input')
                }
            }
            .visibility(this.filterItemVisibility)
            .height(this.searchInputHeight)
            .width('90%')
            .margin({top:this.searchInputTopMargin})
            //
            ForEach(this.items,
                (item: OTPItemInfo) => {
                    ListItem() {
                        OTPItem({
                            icon: item.icon,
                            code: item.code,
                            schema: item.schema,
                            keyAlias: item.keyAlias,
                            selected: this.selected,
                            filterText: this.filterText,
                        })
                    }
                },
                (item: OTPItemInfo) => {
                    return item.keyAlias+'_'+item.code.code+'_'+item.icon;
                }
            )
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, {alwaysEnabled:true})
        .alignListItem(ListItemAlign.Center)
        .onTouch(ev => { this.scrollExtension.onTouch(ev); })
        .onScrollVisibleContentChange(() => { this.hasHiddenItems=true; })
        .onScrollIndex((start, end) => {
            if (start===0) {
                this.scrollExtension.onScrollPostionChanges(ScrollPosition.TopBound);
            } else if (end===this.items.length) {
                this.scrollExtension.onScrollPostionChanges(ScrollPosition.BottomBound);
            } else {
                this.scrollExtension.onScrollPostionChanges(ScrollPosition.None);
                if (start >= 1) {
                    this.filterItemVisibility = Visibility.None;
                }
            }
        })
    }
}

@Component
struct OTPItem {
    @Link selected: string;
    @Link @Watch('onFilterTextChanged') filterText: string;
    @Prop icon: string;
    @Prop @Watch('onCodeUpdated') code: CodeResponseSchema;
    @Prop keyAlias: string;
    @Prop schema: OTPSchema;
    @State passed_time: number = 0;
    @State isVisible: Visibility = Visibility.Visible;

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            // Main Content
            Row({ space: '16vp' }) {
                // display issuer icon
                Image($rawfile(this.icon))
                    .margin({left: $r('app.float.visual_space')})
                    .borderRadius($r('app.float.issuer_icon_radius'))
                    .height($r('app.float.issuer_icon_size'))
                    .width($r('app.float.issuer_icon_size'))
                    .alt(this.schema.issuer)
                // display information area
                Column({ space: '4vp' }) {
                    Text() {
                        Span(this.schema.issuer)
                            .fontSize($r('sys.float.Subtitle_S'))
                            .fontWeight(FontWeight.Bold)
                            .fontColor($r('sys.color.font_primary'))
                        Span(` (${this.schema.name})`)
                            .fontSize($r('sys.float.Subtitle_S'))
                            .fontWeight(FontWeight.Normal)
                            .fontColor($r('sys.color.font_secondary'))
                    }

                    if (this.selected!==this.keyAlias) {
                        Text(this.hiddenDigits())
                            .fontWeight(FontWeight.Medium)
                            .fontSize($r('sys.float.Subtitle_L'))
                            .letterSpacing(5)
                    } else {
                        Text(this.splitDigits())
                            .fontSize(26)
                    }
                }
                .alignItems(HorizontalAlign.Start)
            }
            .align(Alignment.Top)
            .height('100%')
            .width('100%')
            .zIndex(1)
            // show progress bar for time-based OTP
            if (this.selected===this.keyAlias && (this.schema as TimedOTPSchema).period) {
                Progress({value: 0, total:(this.schema as TimedOTPSchema).period*1000})
                    .value((this.schema as TimedOTPSchema).period*1000 - this.passed_time)
                    .color($r('app.color.color_ribbon'))
                    .height('2vp')
                    .width('100%')
                    .zIndex((2))
                    .style({enableSmoothEffect:true})
            }
            // divider bar at the end
            Divider().strokeWidth('1px').zIndex(2)
        }
        .height('64vp')
        .width('100%')
        .visibility(this.isVisible)
        .onClick(ev => {
            if (this.selected===this.keyAlias) {
                this.selected = '';
            } else {
                this.requestCodeUpdate();
                this.selected = this.keyAlias;
            }
        });
    }

    private onFilterTextChanged() {
        const filterText = this.filterText.trim().toLowerCase();
        if (filterText && !fuzzysearch(filterText, this.keyAlias.toLowerCase())) {
            this.isVisible = Visibility.None;
            if (this.selected===this.keyAlias) {
                this.selected = '';
            }
        } else {
            this.isVisible = Visibility.Visible;
        }
    }

    private onCodeUpdated() {
        if (this.selected===this.keyAlias) {
            this.requestCodeUpdate();
            setTimeout(() => {
                this.onCodeUpdated();
            }, REFRESH_INTERVAL);
        }
    }

    private requestCodeUpdate(): boolean {
        const _period = (this.schema as TimedOTPSchema).period * 1000;

        // test time-based OTP if refresh needed
        if (_period) {
            const passed_time = Date.now() - this.code.timestamp;
            const remain_time = Date.now() % _period;
            this.passed_time = remain_time;
            if (remain_time > REFRESH_INTERVAL && passed_time < _period) {
                return false;
            }
        }

        // apply code update request
        getContext(this).eventHub.emit(EVENT_CODE_REQUEST, {
            keyAlias: this.keyAlias,
        } as CodeRequestSchema);

        return true;
    }

    private splitDigits(): string {
        this.onCodeUpdated();
        return this.code.code.match(/.{1,3}/g)!.join(' ');
    }

    private hiddenDigits(): string {
        return '⬤'.repeat(this.schema.digits).match(/.{1,3}/g)!.join(' ');
    }
}

@Component
struct QrScanButton {
    build() {
        Button() {
            Image($r('sys.media.ohos_ic_public_scan'))
                .width($r('app.float.add_icon_size')).height($r('app.float.add_icon_size'))
                .fillColor($r('sys.color.comp_background_primary'))
        }
        .backgroundColor($r('app.color.color_ribbon'))
        .width($r('app.float.add_circle_size'))
        .height($r('app.float.add_circle_size'))
        .position({bottom: '2vp', right: '30vp'}) // bottom safe area
        .shadow({radius: 10})
        .onClick(async () => {
            const uri:string = await this.scanQrCode();
            getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri} as UpdateRequestSchema);
        })
    }

    private async scanQrCode(): Promise<string> {
        let options: scanBarcode.ScanOptions = {
            scanTypes: [scanCore.ScanType.ALL],
            enableMultiMode: true,
            enableAlbum: true
        };

        try {
            const result = await scanBarcode.startScanForResult(getContext(this), options);
            return result.originalValue
        } catch (err) {
            hilog.error(0x0001, '[Scan CPSample]', `Failed to get ScanResult by callback with options. Code: ${err.code}, message: ${err.message}`);
            return '';
        }
    }
}
