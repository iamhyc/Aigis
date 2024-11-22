import { LengthUnit, Offset, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';

import { FAKE_OTP_CODE, ONE_DAY_IN_MS, PREF_KEY_ITEMS, PREF_PASSWORD_CHALLENGE_TIME } from '../common/conts';
import { ScrollEventExtension, ScrollPosition } from '../common/eventExtension';
import { OTP, OTPSchema, parseURI, TimedOTPSchema } from '../crypto/otpUtils';
import { fuzzysearch } from '../common/utils';
import { ItemEditBuilder } from './ItemEditPage';
import { PasswordInputDialog, TextInputDialog } from '../components/dialog';
import { SettingsPage } from './SettingsPage';
import { acquireAtlAuth, ATL1AuthAvailable, ATL3AuthAvailable, validateAtlAuth,
    validatePassword } from '../crypto/authUtils';
import { AtlAuthResult, CodeResponseSchema, MasterKeyInfo, OTPItemInfo } from '../common/schema';
import {
    BulkyUpdateRequestSchema,
    CodeRequestSchema, EVENT_CODE_REQUEST,
    EVENT_INSERT_ITEM_BEFORE,
    EVENT_MOVE_TO_TOP, EVENT_UPDATE_ITEM,
    EVENT_UPDATE_ITEMS,
    EVENT_UPDATE_PASSWORD,
    EVENT_UPDATE_SETTING,
    InsertItemBeforeRequestSchema,
    PasswordUpdateRequestSchema,
    SettingUpdateRequestSchema,
    UpdateRequestSchema } from '../common/events';
import { AppLockPage, PasswordChallengePage } from '../components/pages';
import { unifiedDataChannel } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { AuthTypePriority, DigitGroup, ItemSortOrder,
    PasswordReminderPeriod,
    ShowAccountName } from '../common/settings';
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

class DragState<T> {
    private equalEl: (el1:T, el2:T) => boolean;
    @Track list: T[] = [];
    @Track startIndex: number = -1;
    private insertIndex: number = -1;
    private startEl: T | undefined;
    private insertEl: T | undefined;

    constructor(list: T[], equalEl: (el1:T, el2:T) => boolean) {
        this.list = list;
        this.equalEl = equalEl;
    }

    onStart(el: T) {
        this.startEl = el;
        this.startIndex = this.list.findIndex(x => this.equalEl(x, el));
        this.insertIndex = this.startIndex;
    }

    onMove(el:T) {
        if (this.startIndex!==-1) {
            const nextIndex = this.list.findIndex(x => this.equalEl(x, el))
            const ele = this.list.splice(this.insertIndex, 1)[0];
            this.list.splice(nextIndex, 0, ele);
            //
            this.insertEl = el;
            this.insertIndex = nextIndex;
        }
    }

    onEnd(callback?: (startEl:T, insertEl: T)=>void) {
        if (callback && this.startEl && this.insertEl) {
            // bypass wandering
            if (this.startIndex!==this.insertIndex) {
                callback(this.startEl, this.insertEl);
            }
        }
        this.startIndex = -1;
        this.insertIndex = -1;
        this.startEl = undefined;
        this.insertEl = undefined;
    }
}

@Entry(storage)
@Component
struct Index {
    @StorageProp(PREF_PASSWORD_CHALLENGE_TIME) PasswordChallengeTime: number = Date.now();
    @StorageProp('settingsPasswordReminderPeriod') PasswordReminderPeriod: PasswordReminderPeriod = 'biweekly';
    @StorageProp('EncMasterKey') EncMasterKey: MasterKeyInfo = {} as MasterKeyInfo;
    @Watch('onDecKeyRequired') @StorageLink('StatusDecKeyRequired') StatusDecKeyRequired: boolean = false;
    @Watch('onAuthLevelChanged') @StorageProp('settingsEnableBiometricUnlock') EnableBiometricUnlock: boolean = false;
    @Watch('onAuthLevelChanged') @StorageProp('settingsEnableBiometricAuth') EnableBiometricAuth: boolean = false;
    @StorageProp('settingsAuthTypePriority') AuthTypePriority: AuthTypePriority = 'face';
    @Watch('onItemListChanged') @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Provide navStack: NavPathStack = new NavPathStack();
    @Provide ATL1AuthAvailable: boolean = ATL1AuthAvailable();
    @Provide ATL3AuthAvailable: boolean = ATL3AuthAvailable();
    @Provide atlAuth: AtlAuthResult = {authLevel: 'ATL1', authToken: new Uint8Array(), timestamp:0};

    @Provide selected: string = '';
    @Provide btnVisibility: Visibility = Visibility.Visible;
    @Provide editState: EditState = new EditState();
    @State addSheetShow: boolean = false;

    @State settingPageTranslateX: string = '0%';

    private inputDialogId: number = -1;

    build() {
        RelativeContainer() {
            Navigation(this.navStack) {
                Stack() {
                    // main content
                    if (this.EnableBiometricUnlock && !validateAtlAuth(this.atlAuth)) {
                        AppLockPage({atlAuth: this.atlAuth, authLevel:this.EnableBiometricAuth?'ATL3':'ATL1', priority: this.AuthTypePriority})
                    } else if (this.shouldShowPasswordChallenge()) {
                        PasswordChallengePage()
                    } else {
                        if (this.items.length===0) {
                            EmptyPage()
                        } else {
                            OTPList({items: this.items})
                        }
                        // floating add button
                        QrScanButton({addSheetShow: this.addSheetShow})
                    }
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
                        mode: SheetMode.OVERLAY,
                        height: SheetSize.FIT_CONTENT,
                        width: '100%',
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
            .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) => {
                if (from.mode == NavDestinationMode.DIALOG || to.mode == NavDestinationMode.DIALOG) {
                    return undefined;
                }
                // return settings page transition
                if (from.name==='settings' || to.name==='settings') {
                    return {transition: (transitionProxy: NavigationTransitionProxy) => {
                        // prepare start/end position
                        let startPos: string, endPos: string;
                        if (operation===NavigationOperation.PUSH) {
                            startPos = '-100%'; endPos = '0%';
                        } else {
                            startPos = '0%'; endPos = '-100%';
                        }
                        this.settingPageTranslateX = startPos;
                        // animate from start to end
                        animateTo({
                            duration: 250,
                            onFinish: () => {
                                transitionProxy.finishTransition();
                            },
                        }, () => {
                            this.settingPageTranslateX = endPos;
                        });
                    }};
                }
                // return default page transition
                return undefined;
            })
        }
        .height('100%')
        .width('100%')
    }

    @Builder titleBar() {
        Row({space:10}) {
            Button({type: ButtonType.Circle}) {
                SymbolGlyph($r('sys.symbol.close_sidebar'))
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
            SettingsPage({
                pageTitle: getContext().resourceManager.getStringByNameSync('settings_page_title'),
                pageTranslateX: this.settingPageTranslateX,
            })
        }
    }

    onPageShow() {
        if (this.EnableBiometricUnlock && !validateAtlAuth(this.atlAuth)) {
            const authLevel = this.EnableBiometricAuth? 'ATL3' : 'ATL1';
            acquireAtlAuth(authLevel, this.AuthTypePriority).then(result => { this.atlAuth = result; })
        }
    }

    onPageHide() {
        if (this.EnableBiometricUnlock) {
            this.addSheetShow = false;
            this.editState.hide();
            this.atlAuth = { authLevel: 'ATL1', authToken: new Uint8Array(), timestamp: 0 };
        }
        this.selected = '';
    }

    aboutToAppear() {
        this.onDecKeyRequired();
    }

    private showCustomDialog(builder: () => CustomBuilder) {
        if (this.inputDialogId > 0) {
            promptAction.closeCustomDialog(this.inputDialogId);
            this.inputDialogId = -1;
        }
        //
        promptAction.openCustomDialog({
            builder,
            onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
                if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
                    dismissDialogAction.dismiss()
                }
                if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
                    dismissDialogAction.dismiss()
                }
            }
        }).then((dialogId) => {
            this.inputDialogId = dialogId;
        });
    }

    @Builder passwordInputDialogBuilder(title: ResourceStr, usage: ResourceStr, confirm?: (password: string, checked?: boolean) => void, cancel?: () => void) {
        PasswordInputDialog({ title, usage, confirm, cancel })
    }

    private onDecKeyRequired() {
        if (!this.StatusDecKeyRequired) { return; }
        // password prompt for dec key update
        this.showCustomDialog(() => {
            this.passwordInputDialogBuilder(
                $r('app.string.setting_enter_master_password'), $r('app.string.password_usage_generate_dec_key'),
                async (password) => {
                    if (!(await validatePassword(this.EncMasterKey, password))) {
                        promptAction.showToast({message:$r('app.string.setting_input_wrong_password')});
                    } else {
                        getContext(this).eventHub.emit(EVENT_UPDATE_PASSWORD, {password} as PasswordUpdateRequestSchema);
                    }
                    this.StatusDecKeyRequired = false;
                    //
                    this.inputDialogId = -1;
                    promptAction.closeCustomDialog(this.inputDialogId);
                }, () => {
                    this.StatusDecKeyRequired = false;
                    promptAction.closeCustomDialog(this.inputDialogId);
                });
        });
    }

    private onAuthLevelChanged() {
        const newAuthLevel = this.EnableBiometricUnlock? (this.EnableBiometricAuth ? 'ATL3' : 'ATL1') : undefined;
        if (newAuthLevel!==this.atlAuth.authLevel) {
            if (newAuthLevel) {
                this.atlAuth = {authLevel: newAuthLevel, authToken: new Uint8Array(), timestamp:0};
            }
        }
    }

    private onItemListChanged() {
        this.editState.hide();
    }

    private shouldShowPasswordChallenge(): boolean {
        if (this.EncMasterKey.keyAlias===undefined) {
            return false;
        }
        //
        const delta_time = Date.now() - this.PasswordChallengeTime;
        switch (this.PasswordReminderPeriod) {
            case 'never':
                return false;
            case 'weekly':
                return delta_time > 7*ONE_DAY_IN_MS;
            case 'biweekly':
                return delta_time > 14*ONE_DAY_IN_MS;
            case 'monthly':
                return delta_time > 30*ONE_DAY_IN_MS;
            case 'quarterly':
                return delta_time > 90*ONE_DAY_IN_MS;
            default:
                return false;
        }
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
    @StorageProp('settingsItemSortOrder')
    @Watch('onItChanged') ItemSortOrder: ItemSortOrder = 'custom';
    @Consume btnVisibility: Visibility;
    @Consume selected: string;
    @Prop items: OTPItemInfo[];
    @State _sortedItems: OTPItemInfo[] = [];
    @State filterText: string = '';
    @State filterItemVisibility: Visibility = Visibility.None;
    @State hasHiddenItems: boolean = false;

    @State dragState: DragState<OTPItemInfo> = new DragState(this._sortedItems, (el1, el2) => {
        return el1.keyAlias === el2.keyAlias;
    });

    private searchInputHeight = 40;//vp
    private searchInputTopMargin = 6;//vp
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

    private onItChanged(key: string) {
        if (key==='ItemSortOrder') {
            const value = this.ItemSortOrder;
            getContext(this).eventHub.emit(EVENT_UPDATE_SETTING, {key, value} as SettingUpdateRequestSchema);
        }
    }

    private sortedItems(): OTPItemInfo[] {
        if (this.dragState.startIndex!==-1) {
            return this.dragState.list;
        } else {
            const favorites: OTPItemInfo[] = [];
            const normals: OTPItemInfo[] = [];
            // filter favorite/normal items
            for (const item of this.items) {
                if (item.favorite) {
                    favorites.push(item);
                } else {
                    normals.push(item);
                }
            }
            // sort normal items
            switch (this.ItemSortOrder) {
                case 'issuer_asc':
                    normals.sort((x, y) => x.schema.issuer > y.schema.issuer ? 1 : -1);
                    break;
                case 'issuer_dsc':
                    normals.sort((x, y) => x.schema.issuer < y.schema.issuer ? 1 : -1);
                    break;
                case 'account_asc':
                    normals.sort((x, y) => x.schema.name > y.schema.name ? 1 : -1);
                    break;
                case 'account_dsc':
                    normals.sort((x, y) => x.schema.name < y.schema.name ? 1 : -1);
                    break;
                case 'custom':
                default:
                    break;
            }
            // return
            this._sortedItems.splice(0, this._sortedItems.length, ...favorites.concat(normals));
            return this._sortedItems;
        }
    }

    @LocalBuilder sortMenu() {
        Menu() {
            ForEach(['custom', 'issuer_asc', 'issuer_dsc', 'account_asc', 'account_dsc'] as ItemSortOrder[],
                (option: ItemSortOrder) => {
                    MenuItem({
                        content: (() => {
                            switch (option) {
                                case 'issuer_asc': return $r('app.string.item_sort_issuer_name_ascending');
                                case 'issuer_dsc': return $r('app.string.item_sort_issuer_name_descending');
                                case 'account_asc': return $r('app.string.item_sort_account_name_ascending');
                                case 'account_dsc': return $r('app.string.item_sort_account_name_descending');
                                case 'custom': return $r('app.string.item_sort_custom');
                                default: return option;
                            }
                        })(),
                        symbolEndIcon: option===this.ItemSortOrder?
                            new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontSize(20) :
                            new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontSize(20).visibility(Visibility.Hidden),
                    })
                    .backgroundColor(option===this.ItemSortOrder? $r('sys.color.comp_background_emphasize') : undefined)
                    .onChange((selected) => {
                        if (selected) {
                            this.ItemSortOrder = option;
                        }
                    })
                },
                (option: ItemSortOrder) => {
                    return option + '_' + this.ItemSortOrder;
                }
            )
        }
        .menuItemDivider({strokeWidth:{value:1,unit:0}, color:$r('sys.color.comp_divider')})
}

    build() {
        List({scroller: this.listScroller}) {
            // filter entries
            ListItem() {
                Row({space:6}) {
                    Search({value: $$this.filterText, placeholder: $r('app.string.search_hint')})
                        .id('search_input')
                        .height(this.searchInputHeight)
                        .width('calc(100% - 32vp - 40vp - 6vp)')
                    //
                    Button({type: ButtonType.Circle}) {
                        SymbolGlyph($r('sys.symbol.sort'))
                            .fontWeight(FontWeight.Medium)
                            .fontColor([$r('sys.color.font_secondary')])
                            .fontSize(22)
                    }
                    .height(this.searchInputHeight).width(this.searchInputHeight)
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                    .bindMenu(this.sortMenu)
                }
                .width('100%')
                .margin({left:16,right:16})
                .alignItems(VerticalAlign.Center)
            }
            .height(this.searchInputHeight)
            .margin({top:this.searchInputTopMargin})
            .visibility(this.filterItemVisibility)
            // main content
            ForEach(this.sortedItems(),
                (item: OTPItemInfo) => {
                    OTPItem({
                        item,
                        icon: item.icon,
                        code: item.code,
                        schema: item.schema,
                        favorite: item.favorite,
                        keyAlias: item.keyAlias,
                        filterText: this.filterText,
                        listScroller: this.listScroller,
                        dragState: this.dragState,
                    })
                },
                (item: OTPItemInfo) => {
                    return [item.keyAlias, item.code.code, item.icon, item.favorite, JSON.stringify(item.schema)].join('_');
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
    @StorageProp('settingsItemSortOrder') ItemSortOrder: ItemSortOrder = 'custom';
    @StorageProp('settingsEnableDoubleClickCopy') EnableDoubleClickCopy: boolean = false;
    @StorageProp('settingsDigitGroup') DigitGroup: DigitGroup = '3';
    @StorageProp('settingsShowAccountName') ShowAccountName: ShowAccountName = 'always';
    @StorageProp('settingsShowIssuerIcons') ShowIssuerIcons: boolean = true;
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Consume editState: EditState;
    @Consume selected: string;
    @Consume atlAuth: AtlAuthResult;
    @Link @Watch('onFilterTextChanged') filterText: string;
    @Link dragState: DragState<OTPItemInfo>;
    @Prop item: OTPItemInfo;
    @Prop icon: string;
    @Prop code: CodeResponseSchema;
    @Prop keyAlias: string;
    @Prop schema: OTPSchema;
    @Prop favorite: boolean | undefined;
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
            this.itemContent()
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
        .visibility(this.isVisible)
        .draggable(this._draggable())
        .dragPreview(this.itemContent(true))
        .dragPreviewOptions({
            mode: [DragPreviewMode.DISABLE_SCALE, DragPreviewMode.ENABLE_DEFAULT_SHADOW, DragPreviewMode.ENABLE_DEFAULT_RADIUS],
        })
        .onDragStart(() => {
            this.isVisible = Visibility.Hidden;
            this.dragState.onStart(this.item);
            return this.itemContent(true);
        })
        .onDragEnter(() => {
            if (this.favorite!==true) {
                this.dragState.onMove(this.item);
            }
        })
        .onDrop(() => {})
        .onDragEnd(() => {
            this.dragState.onEnd((startEl, insertEl) => {
                const startKeyAlias = startEl.keyAlias;
                const insertKeyAlias = insertEl.keyAlias;
                if (startKeyAlias!==insertKeyAlias) {
                    getContext(this).eventHub.emit(EVENT_INSERT_ITEM_BEFORE, {startKeyAlias,insertKeyAlias} as InsertItemBeforeRequestSchema);
                }
            });
            this.isVisible = Visibility.Visible;
        })
    }

    @Builder itemContent(dragged: boolean = false) {
        Stack({ alignContent: Alignment.Bottom }) {
            // Main Content
            Row({ space: '16vp' }) {
                // Favorite Bar
                if (this.favorite) {
                    Rect({height:'80%', width:10})
                        .radius(6)
                        .offset({left:-6})
                        .fill($r('app.color.color_ribbon'))
                        .margin({right:-26})
                }
                // Drag Bar
                else if (this.ItemSortOrder==='custom' && dragged) {
                    Text() {
                        SymbolSpan($r('sys.symbol.text_alignright'))
                            .fontWeight(FontWeight.Medium)
                            .fontColor([$r('sys.color.font_secondary')])
                            .fontSize(28)
                    }
                    .height('80%')
                    .backgroundColor($r('sys.color.ohos_id_list_background_color'))
                    .offset({left:-20}).margin({right:-44})
                }
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
                    .maxLines(1)
                    .textOverflow({overflow: TextOverflow.Ellipsis})
                    .wordBreak(WordBreak.BREAK_ALL)

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
                .width(`calc(100% - ${this.ShowIssuerIcons?'80vp':'16vp'})`)
                .alignItems(HorizontalAlign.Start)
                .margin(this.ShowIssuerIcons? {} : {left: $r('app.float.visual_space')})
            }
            .align(Alignment.Top)
            .height(dragged? '90%' : '100%')
            .width(dragged? '90%' : '100%')
            .zIndex(1)
            .clip(true)
            // show progress bar for time-based OTP
            if (this.selected===this.keyAlias && this.code.code!==FAKE_OTP_CODE && (this.schema as TimedOTPSchema).period) {
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
        .backgroundColor($r('app.color.color_face'))
        .onClick(() => {
            if (this.selected===this.keyAlias) {
                if (this.EnableDoubleClickCopy && !this.codeCopied) {
                    this.copyCodeToPateBoard();
                    this.codeCopied = true;
                } else if (this.code.code===FAKE_OTP_CODE) {
                    this.codeRequested = false;
                    this.requestCodeUpdate();
                } else {
                    this.selected = '';
                }
            } else {
                this.requestCodeUpdate();
                this.selected = this.keyAlias;
            }
        })
    }

    @Builder itemEnd() {
        Column() {
            Row({space:8}) {
                //
                if (!this.showEditItemOnly) {
                    // Move-To-Top button
                    Button({ type: ButtonType.Circle }) {
                        SymbolGlyph(this.favorite? $r('sys.symbol.heart_slash') : $r('sys.symbol.heart'))
                            .fontColor([Color.White])
                            .fontSize(24)
                    }
                    .height(40).width(40)
                    .backgroundColor($r('sys.color.warning'))
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

    private _draggable(): boolean {
        return this.favorite!==true && this.selected!==this.keyAlias && this.ItemSortOrder==='custom' && this.filterText==='';
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
            const passed_iter = Math.floor(_now/_period) - Math.floor(this.code.timestamp/_period);
            const remain_time = _now % _period;
            this.passed_time = remain_time;
            if (remain_time > REFRESH_INTERVAL && passed_iter < 1) {
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
                authToken: this.atlAuth.authToken,
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
    @StorageLink('LaunchURI') LaunchURI: string = '';
    @StorageProp('bottomRectHeight')
    @Watch('onBottomRectHeightChanged') bottomRectHeight: number = 0;
    @StorageProp('settingsEnableManualInput') EnableManualInput: boolean = false;
    @StorageProp('settingsDisableAddConfirm') DisableAddConfirm: boolean = false;
    @LocalStorageProp(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @Consume selected: string;
    @Consume editState: EditState;
    @Consume btnVisibility: Visibility;
    @Link addSheetShow: boolean;
    @State _position: Edges = {bottom: 0, right: 0};

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
            detents: [SheetSize.FIT_CONTENT],
            preferType: SheetType.BOTTOM,
            mode: SheetMode.OVERLAY,
            height: SheetSize.FIT_CONTENT,
            width: '100%',
        })
    }

    @Builder addSheet() {
        Column() {
            // scan qr code
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
            // parse from URI
            Divider().strokeWidth('1px')
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
            // manual input
            Divider().strokeWidth('1px')
            Row({space:16}) {
                Row() {
                    SymbolGlyph($r('sys.symbol.rename'))
                        .fontColor([$r('sys.color.font_primary')])
                        .fontSize(28)
                }
                .height('100%')
                Row() {
                    Text($r('app.string.add_sheet_item_manual_input'))
                        .fontSize(18)
                }
                .height('100%')
            }
            .height(48)
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(async () => {
                this.uriToEditPage( async () => { return 'otpauth://totp/?'; } )
            })
            .clickEffect({level: ClickEffectLevel.HEAVY})
        }
        .width('90%')
        .padding({bottom: 2+px2vp(this.bottomRectHeight)})
        .alignItems(HorizontalAlign.Start)
    }

    aboutToAppear(): void {
        this.onBottomRectHeightChanged();
        if (this.LaunchURI.startsWith('otpauth://')) {
            this.uriToEditPage(async () => {
                const uri = this.LaunchURI;
                this.LaunchURI = '';
                return uri;
            });
        }
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
                        const uris = text.trim().split('\n').filter(x => x.startsWith('otpauth://'));
                        if (uris.length===0) {
                            return;
                        } else if (uris.length===1) {
                            resolve(uris[0]);
                        } else {
                            getContext(this).eventHub.emit(EVENT_UPDATE_ITEMS, {uris} as BulkyUpdateRequestSchema);
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
