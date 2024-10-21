import { LengthUnit, Offset, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';

import { PREF_KEY_ITEMS } from '../common/conts';
import { ScrollEventExtension, ScrollPosition } from '../common/eventExtension';
import { OTPItemInfo, EVENT_CODE_REQUEST, CodeRequestSchema,
    CodeResponseSchema,
    EVENT_MOVE_TO_TOP} from '../common/schema';
import { OTP, OTPSchema, parseURI, TimedOTPSchema } from '../crypto/otpUtils';
import { fuzzysearch } from '../common/utils';
import { ItemEditBuilder } from './ItemEditPage';
import { TextInputDialog } from '../components/dialog';

const REFRESH_INTERVAL = 250;//ms
const storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
    @Watch('onItemListChanged') @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Provide selected: string = '';
    @Provide btnVisibility: Visibility = Visibility.Visible;
    @Provide editPageShow: boolean = false;
    @Provide editKeyAlias: string = ''
    @Provide editSchema: OTPSchema | undefined = undefined;

    build() {
        RelativeContainer() {
            Navigation() {
                Stack() {
                    // main content
                    if (this.items.length > 0) {
                        OTPList({items: this.items})
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
            .mode(NavigationMode.Stack)
            .backgroundColor($r('app.color.color_face'))
            .bindSheet($$this.editPageShow,
                ItemEditBuilder(
                    getContext(this),
                    this.getExKeys(),
                    this.editKeyAlias, this.editSchema!,
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
        .height('100%')
        .width('100%')
    }

    private onItemListChanged() {
        this.editPageShow = false;
    }

    private getExKeys(): string[] {
        if (this.editSchema?.secret) { // add new one
            return this.items.map(x => x.keyAlias);
        } else { // update existing one
            return this.items.flatMap(x => x.keyAlias===this.editKeyAlias ? [] : [x.keyAlias]);
        }
    }
}

@Component
struct OTPList {
    @Consume btnVisibility: Visibility;
    @Consume selected: string;
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
                        filterText: this.filterText,
                        listScroller: this.listScroller,
                    })
                },
                (item: OTPItemInfo) => {
                    return [item.keyAlias, item.code.code, item.icon, JSON.stringify(item.schema)].join('_');
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
        .onDidScroll((offset, state) => {
            if (state===ScrollState.Scroll) {
                animateTo({duration: 500, curve: Curve.ExtremeDeceleration}, () => {
                    if (offset > 0) {
                        this.btnVisibility = Visibility.None;
                    } else {
                        this.btnVisibility = Visibility.Visible;
                    }
                });
            }
        })
    }
}

@Component
struct OTPItem {
    @Consume editPageShow: boolean;
    @Consume editKeyAlias: string;
    @Consume editSchema: OTPSchema | undefined;
    @Consume selected: string;
    @Link @Watch('onFilterTextChanged') filterText: string;
    @Prop icon: string;
    @Prop @Watch('onCodeUpdated') code: CodeResponseSchema;
    @Prop keyAlias: string;
    @Prop schema: OTPSchema;
    @State passed_time: number = 0;
    @State isVisible: Visibility = Visibility.Visible;
    @State editItemOnly: boolean = false;
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
                    this.editKeyAlias = this.keyAlias;
                    this.editSchema = this.schema;
                    this.editPageShow = true;
                    this.listScroller!.closeAllSwipeActions();
                },
            },
        })
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
            const _now = Date.now()
            const passed_time = _now - this.code.timestamp;
            const remain_time = _now % _period;
            this.passed_time = remain_time;
            if (remain_time > REFRESH_INTERVAL && passed_time < 1) {
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
    @StorageProp('bottomRectHeight')
    @Watch('onBottomRectHeightChanged') bottomRectHeight: number = 0;
    @StorageProp('settingsEnableManualInput') enableManualInput: boolean = true;
    @Consume selected: string;
    @Consume editPageShow: boolean;
    @Consume editKeyAlias: string;
    @Consume editSchema: OTPSchema | undefined;
    @Consume btnVisibility: Visibility;
    @State _position: Edges = {bottom: 0, right: 0};
    @State addSheetShow: boolean = false;

    private inputDialogId = -1;

    build() {
        Button() {
            if (this.enableManualInput) {
                Image($r('sys.media.ohos_ic_public_add'))
                    .width($r('app.float.add_icon_size')).height($r('app.float.add_icon_size'))
                    .fillColor($r('sys.color.comp_background_primary'))
            } else {
                Image($r('sys.media.ohos_ic_public_scan'))
                    .width($r('app.float.add_icon_size')).height($r('app.float.add_icon_size'))
                    .fillColor($r('sys.color.comp_background_primary'))
            }
        }
        .backgroundColor($r('app.color.color_ribbon'))
        .width($r('app.float.add_circle_size'))
        .height($r('app.float.add_circle_size'))
        .position(this._position)
        .shadow({radius: 10})
        .visibility(this.btnVisibility)
        .onClick(async () => {
            if (this.enableManualInput) {
                this.addSheetShow = true;
            } else {
                this.uriToEditPage( async () => { return await this.scanQrCode() } );
            }
        })
        .bindSheet($$this.addSheetShow, this.addSheet(), {
            title: {
                title: $r('app.string.add_sheet_title'),
            },
            backgroundColor: $r('app.color.color_face'),
            showClose: false,
            dragBar: true,
            detents: [SheetSize.FIT_CONTENT],
        })
    }

    @Builder addSheet() {
        Column() {
            //
            Row({space:16}) {
                Row() {
                    SymbolGlyph($r('sys.symbol.qrcode'))
                        .fontColor([$r('sys.color.font_primary')])
                        .fontSize(28)
                }
                .height('100%')
                Row() {
                    Text($r('app.string.add_sheet_item_qr_scan'))
                        .fontSize(18)
                }
                .height('100%')
            }
            .height(48)
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(async () => {
                this.uriToEditPage( async () => { return await this.scanQrCode(); } )
            })
            //
            Row({space:16}) {
                Row() {
                    SymbolGlyph($r('sys.symbol.staroflife_rectangle'))
                        .fontColor([$r('sys.color.font_primary')])
                        .fontSize(28)
                }
                .height('100%')
                Row() {
                    Text($r('app.string.add_sheet_item_uri_parse'))
                        .fontSize(18)
                }
                .height('100%')
            }
            .height(48)
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(async () => {
                this.uriToEditPage( async () => { return await this.getUserUriInput() } )
            })
        }
        .width('90%')
        .padding({bottom: 2+px2vp(this.bottomRectHeight)})
        .alignItems(HorizontalAlign.Start)
    }

    aboutToAppear(): void {
        this.onBottomRectHeightChanged();
    }

    private onBottomRectHeightChanged() {
        const bottomHeight = px2vp(this.bottomRectHeight)
        if (bottomHeight===0) {
            this._position = {bottom: 12, right: 12};
        } else {
            this._position = {bottom: 2, right: 2+bottomHeight};
        }
    }

    private async uriToEditPage(callback: () => Promise<string>) {
        this.addSheetShow = false;
        const uri = await callback();
        const args = parseURI(uri);
        const otp = OTP.fromArguments(args);
        //
        this.editKeyAlias = otp.keyAlias;
        this.editSchema = otp.secret_leaked_schema;
        //
        this.selected = '';
        this.editPageShow = true;
    }

    private getUserUriInput(): Promise<string> {
        this.inputDialogId = -1;
        return new Promise((resolve, reject) => {
            promptAction.openCustomDialog({
                builder: () => {
                    this.textInputDialogBuilder($r('app.string.input_parse_uri_title'), $r('app.string.input_parse_uri_placeholder'), (text) => {
                        text = text.trim();
                        if (text==='') {
                            resolve('otpauth://totp/?')
                        } else {
                            resolve(text);
                        }
                        promptAction.closeCustomDialog(this.inputDialogId);
                    }, () => {
                        promptAction.closeCustomDialog(this.inputDialogId);
                    })
                },
                onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
                    if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
                        dismissDialogAction.dismiss()
                    }
                    if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
                        dismissDialogAction.dismiss()
                    }
                }
            }).then((dialogId) => {
                this.inputDialogId = dialogId
            })
        });
    }

    @Builder textInputDialogBuilder(title: ResourceStr, placeholder: ResourceStr, confirm?: (text: string) => void, cancel?: () => void) {
        TextInputDialog({ title, placeholder, confirm, cancel })
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
