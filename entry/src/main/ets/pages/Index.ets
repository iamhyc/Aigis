import { LengthUnit, Offset, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';

import { FAKE_OTP_CODE, PREF_KEY_ITEMS } from '../common/conts';
import { ScrollEventExtension, ScrollPosition } from '../common/eventExtension';
import { OTP, OTPSchema, parseURI, TimedOTPSchema } from '../crypto/otpUtils';
import { fuzzysearch } from '../common/utils';
import { ItemEditBuilder } from './ItemEditPage';
import { TextInputDialog } from '../components/dialog';
import { SettingsPage } from './SettingsPage';
import { acquireAtl1Auth, ATL1AuthAvailable, ATL3AuthAvailable, validateAtl1Auth } from '../crypto/authUtils';
import { Atl1AuthResult, CodeResponseSchema, OTPItemInfo } from '../common/schema';
import { CodeRequestSchema, EVENT_CODE_REQUEST, EVENT_MOVE_TO_TOP, EVENT_UPDATE_ITEM,
    UpdateRequestSchema } from '../common/events';
import { AppLockPage } from '../components/pages';
import { unifiedDataChannel } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { DigitGroup, ShowAccountName } from '../common/settings';
import { IconManager } from '../common/icons';
import { IssuerIcon } from '../components/icons';

const REFRESH_INTERVAL = 100;//ms
const storage = LocalStorage.getShared();

class EditState {
    public editPageShow: boolean = false;
    public editKeyAlias: string = '';
    public editSchema: OTPSchema | undefined = undefined;
    public editIcon: string = '';
    public editNewItem: boolean = false;

    constructor() {}

    show(editKeyAlias: string, editSchema: OTPSchema, editIcon: string, editNewItem: boolean = false) {
        this.editKeyAlias = editKeyAlias;
        this.editSchema = editSchema;
        this.editNewItem = editNewItem;
        this.editIcon = editIcon;
        this.editPageShow = true;
    }

    hide() {
        this.editPageShow = false;
        this.editKeyAlias = '';
        this.editSchema = undefined;
        this.editIcon = '';
        this.editNewItem = false;
    }
}

@Entry(storage)
@Component
struct Index {
    @StorageLink('settingsEnableBiometricUnlock') EnableBiometricUnlock: boolean = false;
    @Watch('onItemListChanged') @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Provide navStack: NavPathStack = new NavPathStack();
    @Provide ATL1AuthAvailable: boolean = ATL1AuthAvailable();
    @Provide ATL3AuthAvailable: boolean = ATL3AuthAvailable();
    @Provide atl1Auth: Atl1AuthResult = {authToken: new Uint8Array(), timestamp:0};

    @Provide selected: string = '';
    @Provide btnVisibility: Visibility = Visibility.Visible;
    @Provide editState: EditState = new EditState();

    build() {
        RelativeContainer() {
            Navigation(this.navStack) {
                Stack() {
                    // main content
                    if (this.EnableBiometricUnlock && !validateAtl1Auth(this.atl1Auth)) {
                        AppLockPage({atl1Auth: this.atl1Auth})
                    } else if (this.items.length===0) {
                        EmptyPage()
                    } else {
                        OTPList({items: this.items})
                    }
                    // floating add button
                    QrScanButton()
                }
                .height('100%')
                .width('100%')
                .bindSheet($$this.editState.editPageShow,
                    ItemEditBuilder(
                        getContext(this),
                        this.getExKeys(),
                        this.editState.editKeyAlias,
                        this.editState.editSchema!,
                        this.editState.editIcon,
                        this.editState.editNewItem,
                    ),
                    {
                        title: { title: $r('app.string.ItemEditPage_title') },
                        backgroundColor: $r('app.color.color_face'),
                        showClose: false,
                        detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
                        preferType: SheetType.BOTTOM,
                        // onWillDismiss: (action) => {},
                    }
                )
            }
            .title({builder: this.titleBar(), height: $r('sys.float.titlebar_default_height')})
            .titleMode(NavigationTitleMode.Mini)
            .backgroundColor($r('app.color.color_face'))
            .hideBackButton(true)
            .mode(NavigationMode.Stack)
            .navDestination(this.pageJump)
        }
        .height('100%')
        .width('100%')
    }

    @Builder titleBar() {
        Row({space:10}) {
            Button({type: ButtonType.Circle}) {
                SymbolGlyph($r('sys.symbol.open_sidebar'))
                    .fontWeight(FontWeight.Normal)
                    .fontColor([$r('sys.color.font_primary')])
                    .fontSize(24)
            }
            .height(40).width(40)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onClick(() => {
                this.navStack.pushPath({ name: 'settings' })
            })
            //
            Text($r('app.string.app_title'))
                .fontSize($r('sys.float.Title_L'))
                .fontWeight(FontWeight.Bold)
        }
        .height('100%')
        .width('100%')
        .backgroundColor($r('app.color.color_background'))
        .padding({left: 16})
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }

    @Builder pageJump(name: string) {
        if (name==='settings') {
            SettingsPage({pageTitle: getContext().resourceManager.getStringByNameSync('settings_page_title')})
        }
    }

    onPageShow() {
        if (this.EnableBiometricUnlock && !validateAtl1Auth(this.atl1Auth)) {
            acquireAtl1Auth().then(result => { this.atl1Auth = result; })
        }
    }

    onPageHide() {
        if (this.EnableBiometricUnlock) {
            this.editState.hide();
            this.atl1Auth = { authToken: new Uint8Array(), timestamp: 0 };
        }
        this.selected = '';
    }

    private onItemListChanged() {
        this.editState.hide();
    }

    private getExKeys(): string[] {
        if (this.editState.editNewItem) {
            return this.items.map(x => x.keyAlias);
        } else {
            return this.items.flatMap(x => x.keyAlias===this.editState.editKeyAlias ? [] : [x.keyAlias]);
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
    @StorageProp('settingsEnableDoubleClickCopy') EnableDoubleClickCopy: boolean = false;
    @StorageProp('settingsDigitGroup') DigitGroup: DigitGroup = '3';
    @StorageProp('settingsShowAccountName') ShowAccountName: ShowAccountName = 'always';
    @StorageProp('settingsShowIssuerIcons') ShowIssuerIcons: boolean = true;
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Consume editState: EditState;
    @Consume selected: string;
    @Link @Watch('onFilterTextChanged') filterText: string;
    @Prop icon: string;
    @Prop code: CodeResponseSchema;
    @Prop keyAlias: string;
    @Prop schema: OTPSchema;
    @State validatedIcon: string = IconManager.validateUri(this.icon);
    @State passed_time: number = 0;
    @State isVisible: Visibility = Visibility.Visible;
    @State showEditItemOnly: boolean = false;
    @State swipeBackgroundColor: Resource = $r('sys.color.comp_background_secondary');
    @State codeCopied: boolean = false;

    private codeRequested: boolean = false;
    listScroller?: ListScroller;

    build() {
        ListItem() {
            Stack({ alignContent: Alignment.Bottom }) {
                // Main Content
                Row({ space: '16vp' }) {
                    // display issuer icon
                    if (this.ShowIssuerIcons) {
                        if (this.validatedIcon) {
                            Image(this.validatedIcon)
                                .margin({left: $r('app.float.visual_space')})
                                .borderRadius($r('app.float.issuer_icon_radius'))
                                .height($r('app.float.issuer_icon_size'))
                                .width($r('app.float.issuer_icon_size'))
                                .alt(this.schema.issuer)
                        } else {
                            IssuerIcon({
                                issuer: this.schema.issuer,
                                iconSize: $r('app.float.issuer_icon_size'),
                                iconRadius: $r('app.float.issuer_icon_radius'),
                                fontSize: 28,
                            })
                                .margin({left: $r('app.float.visual_space')})
                        }
                    }
                    // display information area
                    Column({ space: '4vp' }) {
                        Text() {
                            Span(this.schema.issuer)
                                .fontSize($r('sys.float.Subtitle_S'))
                                .fontWeight(FontWeight.Bold)
                                .fontColor($r('sys.color.font_primary'))
                            if (this.ShowAccountName==='always' || (this.ShowAccountName==='smart' && this.hasDuplicateIssuers())) {
                                Span(` (${this.schema.name})`)
                                    .fontSize($r('sys.float.Subtitle_S'))
                                    .fontWeight(FontWeight.Normal)
                                    .fontColor($r('sys.color.font_secondary'))
                            }
                        }

                        if (this.selected===this.keyAlias && this.code.code!==FAKE_OTP_CODE) {
                            Text(this.codeDigits())
                                .fontSize(26)
                        } else {
                            Text(this.hiddenDigits())
                                .fontWeight(FontWeight.Medium)
                                .fontSize($r('sys.float.Subtitle_L'))
                                .letterSpacing(5)
                        }
                    }
                    .alignItems(HorizontalAlign.Start)
                    .margin(this.ShowIssuerIcons? {} : {left: $r('app.float.visual_space')})
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
                    if (this.EnableDoubleClickCopy && !this.codeCopied) {
                        this.copyCodeToPateBoard();
                        this.codeCopied = true;
                    } else {
                        this.selected = '';
                    }
                } else {
                    this.requestCodeUpdate();
                    this.selected = this.keyAlias;
                }
            })
        }
        .clickEffect({level: ClickEffectLevel.MIDDLE})
        .swipeAction({
            end: {
                builder: () => { this.itemEnd() },
                actionAreaDistance: 60,//vp
                onEnterActionArea: () => {
                    animateTo({curve: Curve.Smooth, duration: 300}, () => {
                        this.showEditItemOnly = true;
                        this.swipeBackgroundColor = $r('sys.color.brand');
                    });
                },
                onExitActionArea: () => {
                    animateTo({curve: Curve.Smooth, duration: 200}, () => {
                        this.showEditItemOnly = false;
                        this.swipeBackgroundColor = $r('sys.color.comp_background_secondary');
                    });
                },
                onAction: () => {
                    this.selected = '';
                    this.editState.show(this.keyAlias, this.schema, this.icon);
                    this.listScroller!.closeAllSwipeActions();
                },
            },
        })
    }

    @Builder itemEnd() {
        Column() {
            Row({space:8}) {
                //
                if (!this.showEditItemOnly) {
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
                    this.editState.show(this.keyAlias, this.schema, this.icon);
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

    private onPeriodicCodeUpdated() {
        if (this.selected===this.keyAlias) {
            this.requestCodeUpdate();
        }
    }

    private requestCodeUpdate() {
        const _period = (this.schema as TimedOTPSchema).period * 1000;

        // test time-based OTP if refresh needed
        if (_period) {
            const _now = Date.now()
            const passed_time = _now - this.code.timestamp;
            const remain_time = _now % _period;
            this.passed_time = remain_time;
            if (remain_time > REFRESH_INTERVAL && passed_time < _period) {
                return;
            }
            if (remain_time < REFRESH_INTERVAL) {
                this.codeRequested = false;
            }
        }

        // apply code update request
        if (!this.codeRequested) {
            getContext(this).eventHub.emit(EVENT_CODE_REQUEST, {
            keyAlias: this.keyAlias,
        } as CodeRequestSchema);
            this.codeRequested = true;
        }
    }

    private requestMoveToTop() {
        getContext(this).eventHub.emit(EVENT_MOVE_TO_TOP, {keyAlias: this.keyAlias});
        this.listScroller?.closeAllSwipeActions();
    }

    private copyCodeToPateBoard() {
        const textData = new unifiedDataChannel.PlainText();
        textData.textContent = this.code.code;
        const unifiedData = new unifiedDataChannel.UnifiedData(textData);
        unifiedData.properties.shareOptions = unifiedDataChannel.ShareOptions.CROSS_APP;
        pasteboard.getSystemPasteboard().setUnifiedData(unifiedData)
            .then(() => {
                promptAction.showToast({message: $r('app.string.code_copied_prompt'), duration:500});
            });
    }

    private hasDuplicateIssuers(): boolean {
        for (const item of this.items) {
            if (item.schema.issuer===this.schema.issuer && item.keyAlias!==this.keyAlias) {
                return true;
            }
        }
        return false;
    }

    private splitDigits(code: string): string {
        switch(this.DigitGroup) {
            case '2':
                return code.match(/.{1,2}/g)!.join(' ');
            case '3':
                return code.match(/.{1,3}/g)!.join(' ');
            case '4':
                return code.match(/.{1,4}/g)!.join(' ');
            case 'even':
                const num = Math.floor(this.schema.digits / 2);
                const re = new RegExp(`.{1,${num}}`, "g")
                return code.match(re)!.join(' ');
            case 'none':
            default:
                return code;
        }
    }

    private codeDigits(): string {
        this.codeCopied = false;
        this.onPeriodicCodeUpdated();
        //
        const taskId = setInterval(() => {
            this.onPeriodicCodeUpdated();
        }, REFRESH_INTERVAL);
        if (taskId>0) { clearInterval(taskId-1); }
        //
        return this.splitDigits(this.code.code);
    }

    private hiddenDigits(): string {
        const code = '⬤'.repeat(this.schema.digits);
        return this.splitDigits(code);
    }
}

@Component
struct QrScanButton {
    @StorageProp('bottomRectHeight')
    @Watch('onBottomRectHeightChanged') bottomRectHeight: number = 0;
    @StorageProp('settingsEnableManualInput') EnableManualInput: boolean = false;
    @StorageProp('settingsDisableAddConfirm') DisableAddConfirm: boolean = false;
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Consume selected: string;
    @Consume editState: EditState;
    @Consume btnVisibility: Visibility;
    @State _position: Edges = {bottom: 0, right: 0};
    @State addSheetShow: boolean = false;

    private inputDialogId = -1;

    build() {
        Button() {
            if (this.EnableManualInput) {
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
            if (this.EnableManualInput) {
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
            preferType: SheetType.BOTTOM,
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
            .clickEffect({level: ClickEffectLevel.HEAVY})
            //
            Divider().strokeWidth('1px')
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
            .clickEffect({level: ClickEffectLevel.HEAVY})
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
        const keyAlias = otp.keyAlias;
        const exKeys = this.items.map(x => x.keyAlias);
        if (this.DisableAddConfirm && !exKeys.includes(keyAlias)) {
            getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, keyAlias} as UpdateRequestSchema);
        } else {
            this.selected = '';
            this.editState.show(otp.keyAlias, otp.secret_leaked_schema, '', true);
        }
    }

    private getUserUriInput(): Promise<string> {
        this.inputDialogId = -1;
        return new Promise((resolve, _reject) => {
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
