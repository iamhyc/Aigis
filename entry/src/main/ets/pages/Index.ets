import { LengthUnit, Offset } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';

import { PREF_KEY_ITEMS } from '../common/conts';
import { ScrollEventExtension, ScrollPosition } from '../common/eventExtension';
import { OTPItemInfo, EVENT_CODE_REQUEST, CodeRequestSchema,
    CodeResponseSchema,
    EVENT_MOVE_TO_TOP,
    EVENT_UPDATE_ITEM,
    UpdateRequestSchema} from '../common/schema';
import { OTP, OTPSchema, parseURI, TimedOTPSchema } from '../crypto/otpUtils';
import { fuzzysearch } from '../common/utils';
import { ItemEditBuilder } from './ItemEditPage';

const REFRESH_INTERVAL = 250;//ms
const storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @State selected: string = '';

    build() {
        RelativeContainer() {
            Navigation() {
                Stack() {
                    // main content
                    if (this.items.length > 0) {
                        OTPList({items: this.items, selected: this.selected})
                    } else {
                        EmptyPage()
                    }
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
    @Link selected: string;
    @Prop items: OTPItemInfo[];
    @State filterText: string = '';
    @State filterItemVisibility: Visibility = Visibility.None;
    @State hasHiddenItems: boolean = false;

    private searchInputHeight = 40;//vp
    private searchInputTopMargin = 6;//vp
    private searchInputBottomMargin = 10;//vp
    private visibleHeight = 40;//vp

    private listScroller: ListScroller = new ListScroller();
    private scrollExtension = new ScrollEventExtension({
        onTopBound: (o) => { this.onTopBound(o) },
        onTopBoundRelease: (o) => { this.onTopBoundRelease(o) },
    });

    private onTopBound(offset: Offset) {
        if (px2vp(offset.y)>this.visibleHeight && this.hasHiddenItems) {
            animateTo({curve: Curve.Smooth, duration: 300}, () => {
                this.filterItemVisibility = Visibility.Visible;
            });
        }
    }

    private onTopBoundRelease(offset: Offset) {
        if (px2vp(offset.y)>this.visibleHeight && this.filterItemVisibility===Visibility.Visible) {
            this.getUIContext().getFocusController().requestFocus('search_input');
        }
    }

    build() {
        List({scroller: this.listScroller}) {
            // filter entries
            ListItem() {
                Column() {
                    Search({value: $$this.filterText, placeholder: $r('app.string.search_hint')})
                        .id('search_input')
                }
            }
            .height(this.searchInputHeight)
            .width('90%')
            .margin({top:this.searchInputTopMargin, bottom:this.searchInputBottomMargin})
            .visibility(this.filterItemVisibility)
            //
            ForEach(this.items,
                (item: OTPItemInfo) => {
                    OTPItem({
                        icon: item.icon,
                        code: item.code,
                        schema: item.schema,
                        keyAlias: item.keyAlias,
                        selected: this.selected,
                        filterText: this.filterText,
                        listScroller: this.listScroller,
                    })
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .onTouch(ev => { this.scrollExtension.onTouch(ev); })
        .onScrollIndex((start, end) => {
            if (end-start < this.items.length) {
                this.hasHiddenItems = true;
            }
            //
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
    @State editItemOnly: boolean = false;
    @State editPageShow: boolean = false;
    @State swipeBackgroundColor: Resource = $r('sys.color.comp_background_secondary');

    listScroller?: ListScroller;

    build() {
        ListItem() {
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
            .onClick(() => {
                if (this.selected===this.keyAlias) {
                    this.selected = '';
                } else {
                    this.requestCodeUpdate();
                    this.selected = this.keyAlias;
                }
            })
        }
        .swipeAction({
            end: {
                builder: () => { this.itemEnd() },
                actionAreaDistance: 60,//vp
                onEnterActionArea: () => {
                    animateTo({curve: Curve.Smooth, duration: 300}, () => {
                        this.editItemOnly = true;
                        this.swipeBackgroundColor = $r('sys.color.brand');
                    });
                },
                onExitActionArea: () => {
                    animateTo({curve: Curve.Smooth, duration: 200}, () => {
                        this.editItemOnly = false;
                        this.swipeBackgroundColor = $r('sys.color.comp_background_secondary');
                    });
                },
                onAction: () => {
                    this.selected = '';
                    this.editPageShow = true;
                    this.listScroller!.closeAllSwipeActions();
                },
            },
        })
        .bindSheet($$this.editPageShow,
            ItemEditBuilder(
              getContext(this), this.keyAlias, this.schema,
            ),
            {
                title: { title: $r('app.string.ItemEditPage_title') },
                backgroundColor: $r('app.color.color_face'),
                showClose: false,
                detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
                // onWillDismiss: (action) => {},
            }
        )
    }

    @Builder itemEnd() {
        Column() {
            Row({space:8}) {
                //
                if (!this.editItemOnly) {
                    // removal button
                    // Button({ type: ButtonType.Circle }) {
                    //     SymbolGlyph($r('sys.symbol.trash_fill'))
                    //         .fontColor([Color.White])
                    //         .fontSize(24)
                    // }
                    // .height(40).width(40)
                    // .backgroundColor($r('sys.color.ohos_id_closebtn_color_warning'))
                    // .onClick(() => { this.requestItemRemoval(this.keyAlias, this.schema.issuer, this.schema.name); })
                    // Move-To-Top button
                    Button({ type: ButtonType.Circle }) {
                        SymbolGlyph($r('sys.symbol.arrowshape_up_to_line_fill'))
                            .fontColor([Color.White])
                            .fontSize(24)
                    }
                    .height(40).width(40)
                    .backgroundColor($r('sys.color.confirm'))
                    .onClick((() => { this.requestMoveToTop(); }))
                }
                //
                Button({ type: ButtonType.Circle }) {
                    SymbolGlyph($r('sys.symbol.doc_plaintext_and_pencil_fill'))
                        .fontColor([Color.White])
                        .fontSize(24)
                }
                .height(40).width(40)
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => {
                    this.selected = '';
                    this.editPageShow = true;
                    this.listScroller?.closeAllSwipeActions();
                })
            }
            .height('100%')
        }
        .height('100%')
        .padding({left:16,right:16})
        .backgroundColor(this.swipeBackgroundColor)
        .alignItems(HorizontalAlign.Center)
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

    private requestMoveToTop() {
        getContext(this).eventHub.emit(EVENT_MOVE_TO_TOP, {keyAlias: this.keyAlias});
        this.listScroller?.closeAllSwipeActions();
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
    @State editPageShow: boolean = false;
    @State keyAlias: string = ''
    @State schema: OTPSchema | undefined = undefined;

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
            // const args = parseURI(uri);
            // const otp = OTP.fromArguments(args);
            // //
            // this.keyAlias = otp.keyAlias;
            // this.schema = otp.secret_leaked_schema;
            // //
            // this.editPageShow = true;
            getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri} as UpdateRequestSchema);
        })
        .bindSheet($$this.editPageShow,
            ItemEditBuilder(
                getContext(this), this.keyAlias, this.schema!,
            ),
            {
                title: { title: $r('app.string.ItemEditPage_title') },
                backgroundColor: $r('app.color.color_face'),
                showClose: false,
                detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
                // onWillDismiss: (action) => {},
            }
        )
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

@Component
struct EmptyPage {
    build() {
        Flex({
            direction: FlexDirection.Column,
            justifyContent: FlexAlign.Center,
            alignItems: ItemAlign.Center,
            space: { main:{value:12, unit:LengthUnit.VP} }
        }) {
            //
            Text() {
                SymbolSpan($r('sys.symbol.qrcode'))
            }
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontSize(72)
            //
            Text($r('app.string.empty_prompt_title'))
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .fontWeight(FontWeight.Medium)
                .fontSize(18)
            //
            Text($r('app.string.empty_prompt_desc'))
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .fontSize(16)
                .textAlign(TextAlign.Center)
        }
        .height('100%')
        .width('80%')
    }
}
