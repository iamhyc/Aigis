import { promptAction } from "@kit.ArkUI";
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from "@kit.MediaLibraryKit";

import { EVENT_REMOVE_ITEM, EVENT_UPDATE_ITEM, RemovalRequestSchema, UpdateRequestSchema } from "../common/events";
import { IconManager } from "../common/icons";
import { IconPackStore, ImageMimeType } from "../common/schema";
import { IssuerIcon } from "../components/icons";
import { LabeledSelect, LabeledTextInput, LabeledUriHolder } from "../components/labeled";
import { QrCodePage } from "../components/pages";
import { IssuerName, issuerNameToString, OTPSchema, TimedOTPSchema } from "../crypto/otpUtils";
import { util } from "@kit.ArkTS";
import { Uint8ArrayToString } from "../common/utils";

const COLUMN_ITEM_GAP: number = 8;
const FAKE_SECRET: string = '0'.repeat(16);
const typeEntries: string[] = ['TOTP', 'HOTP', 'STEAM'];
const hashEntries: string[] = ['SHA1', 'SHA256', 'SHA512'];

@Builder
export function ItemEditBuilder(
    context: Context,
    exIssuerNames: IssuerName[],
    keyAlias: string,
    schema: OTPSchema,
    icon: string,
    icon_mime: ImageMimeType | undefined,
    editNewItem: boolean,
) {
    Column() {
        ItemEditComponent({
            context, exIssuerNames, keyAlias, schema, editNewItem,
            icon, icon_mime,
            issuer: schema.issuer,
            name: schema.name,
            typeIndex: typeEntries.indexOf(schema.type.toUpperCase()),
            hashIndex: hashEntries.indexOf(schema.algorithm),
            digits: schema.digits.toString(),
            note: schema.note || '',
            secret: schema.secret || FAKE_SECRET,
            counter: schema.counter.toString(),
            period: ((schema as TimedOTPSchema).period ?? 0).toString(),
        })
    }
}

@Component
struct ItemEditComponent {
    @StorageProp('bottomRectHeight') bottomRectHeight: number = 0;
    @StorageProp('IconPacks') IconPacks: IconPackStore[] = [];
    @Require @Prop context: Context;
    @Require @Prop exIssuerNames: IssuerName[];
    @Require @Prop keyAlias: string;
    @Require @Prop schema: OTPSchema;
    @Require @Prop editNewItem: boolean;
    @Watch('onValueChanged') @Require @Prop issuer: string;
    @Watch('onValueChanged') @Require @Prop name: string;
    @Watch('onValueChanged') @Require @Prop typeIndex: number;
    @Watch('onValueChanged') @Require @Prop hashIndex: number;
    @Watch('onValueChanged') @Require @Prop digits: string;
    @Watch('onValueChanged') @Require @Prop icon: string;
    @Prop icon_mime: ImageMimeType | undefined;
    @Watch('onValueChanged') @Prop note: string;
    @Watch('onValueChanged') @Prop period: string;
    @Watch('onValueChanged') @Prop counter: string;
    @Prop secret: string;
    @State navStack: NavPathStack = new NavPathStack();
    @State shareLink: string = this.fieldsToUri();
    @State secretInputEnabled: boolean = this.editNewItem;
    @State saveBtnEnabled: boolean = this.editNewItem;
    @State advanceCollapsed: boolean = !this.editNewItem;

    iconManager: IconManager = new IconManager(this.IconPacks);
    @State IconCandidates: Map<ResourceStr,string> = this.iconManager.matchAllSync(this.issuer);
    @State IconCandidatesEntries: ResourceStr[] = Array.from(this.IconCandidates.keys());
    @State IconCandidatesValues: string[] = Array.from(this.IconCandidates.values());
    @State validatedIcon: string = IconManager.validateUri(this.editNewItem? this.IconCandidatesValues[0] : this.icon, this.icon_mime);
    @Watch('onValueChanged') @State iconIndex: number = this.IconCandidatesValues.findIndex(x => x===this.icon);

    private onValueChanged(propName: string) {
        this.saveBtnEnabled = true;
        if (propName==='iconIndex' && this.iconIndex >= 0) {
            this.icon = this.IconCandidatesValues[ this.iconIndex ];
            this.icon_mime = undefined;
            this.validatedIcon = IconManager.validateUri(this.icon);
        }
        this.shareLink = this.fieldsToUri();
    }

    private requestDeleteItem() {
        // popup for removal confirmation
        AlertDialog.show({
            title: $r('app.string.delete_title'),
            message: $r('app.string.delete_hint', issuerNameToString({issuer:this.schema.issuer,name:this.schema.name})),
            autoCancel: true,
            primaryButton: {
                value: $r('app.string.button_text_cancel'),
                defaultFocus: true,
                style: DialogButtonStyle.DEFAULT,
                action: () => {},
            },
            secondaryButton: {
                value: $r('app.string.button_text_ok'),
                fontColor: $r('sys.color.warning'),
                style: DialogButtonStyle.DEFAULT,
                action: () => {
                    getContext(this).eventHub.emit(EVENT_REMOVE_ITEM, {keyAlias: this.keyAlias} as RemovalRequestSchema);
                },
            }
        })
    }

    private requestOverwriteConfirm(issuer_name: string, allow_overwrite: boolean, callback: () => void) {
        // popup for overwrite confirmation
        AlertDialog.show({
            title: $r('app.string.overwrite_title'),
            message: allow_overwrite ? $r('app.string.overwrite_hint', issuer_name) : $r('app.string.overwrite_fail_hint', issuer_name),
            autoCancel: true,
            primaryButton: {
                value: $r('app.string.button_text_cancel'),
                defaultFocus: true,
                style: DialogButtonStyle.DEFAULT,
                action: () => {},
            },
            secondaryButton: (!allow_overwrite)? undefined : {
                value: $r('app.string.button_text_ok'),
                fontColor: $r('sys.color.warning'),
                style: DialogButtonStyle.DEFAULT,
                action: () => { callback(); },
            }
        })
    }

    private requestUpdateItem() {
        const secret = this.secret===FAKE_SECRET? '' : encodeURIComponent(this.secret);
        if (this.issuer.length===0 || this.name.length===0 || this.digits.length===0 || this.period.length===0 || this.counter.length===0) {
            promptAction.showToast({
                message: $r('app.string.error_required_missing_check'),
                duration: 1500
            });
            return;
        }
        if (this.editNewItem && secret.length===0) {
            promptAction.showToast({
                message: $r('app.string.error_required_missing_check'),
                duration: 1500
            });
            return;
        }

        const uri = this.fieldsToUri();
        const icon = this.icon;
        const icon_mime = this.icon_mime;
        const issuerNameCollided = this.exIssuerNames.find(x => x.issuer===this.issuer && x.name===this.name);
        //
        if (issuerNameCollided) {
            const allow_overwrite = this.editNewItem; //overwrite when adding new ones
            const issuerName = issuerNameCollided;
            this.requestOverwriteConfirm(issuerNameToString(issuerName), allow_overwrite, () => {
                getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, issuerName, icon, icon_mime} as UpdateRequestSchema);
            });
        } else {
            const keyAlias = this.editNewItem? undefined : this.keyAlias;
            getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, keyAlias, icon, icon_mime} as UpdateRequestSchema);
        }
    }

    private fieldsToUri(): string {
        const secret = this.secret===FAKE_SECRET? '' : encodeURIComponent(this.secret);
        const type = typeEntries[this.typeIndex].toLowerCase();
        const issuer_name = encodeURIComponent(issuerNameToString({issuer:this.issuer,name:this.name}));
        const algorithm = hashEntries[this.hashIndex];
        const counter = Number.parseInt(this.counter).toString();
        const digits = Number.parseInt(this.digits).toString();
        const period = Number.parseInt(this.period).toString();
        const note = encodeURIComponent(this.note.trim());
        const uri = `otpauth://${type}/${issuer_name}?algorithm=${algorithm}&digits=${digits}&counter=${counter}&period=${period}&secret=${secret}&issuer=${this.issuer}&note=${note}`;
        return uri;
    }

    private async uploadIcon() {
        const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
        const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
        photoSelectOptions.isPhotoTakingSupported = false;
        photoSelectOptions.isPreviewForSingleSelectionSupported = true;
        photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
        photoSelectOptions.maxSelectNumber = 1;
        // open selected image file
        const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
        const imageUri = photoSelectResult.photoUris[0];
        const imageFile = await fs.open(imageUri);
        // check file type
        let icon_mime: ImageMimeType;
        const lastDotIndex = imageUri.lastIndexOf('.');
        const suffix = lastDotIndex !== -1 ? imageUri.substring(lastDotIndex) : '';
        switch (suffix) {
            // case '.svg': // FIXME: not supported in base64
            //     icon_mime = 'image/svg+xml';
            //     break;
            case '.jpg':
            case '.jpeg':
                icon_mime = 'image/jpeg';
                break;
            case '.png':
                icon_mime = 'image/png';
                break;
            case '.webp':
                icon_mime = 'image/webp';
                break;
            default:
                promptAction.showToast({message: $r('app.string.edit_icon_file_not_supported'), duration: 500});
                return;
        }
        // check file size
        const stat = await fs.stat(imageFile.fd);
        if (stat.size >= 5*1024) { //5KB
            promptAction.showToast({message:$r('app.string.edit_icon_file_too_large'), duration:500});
            return;
        }
        //
        const b64 = new util.Base64Helper();
        const arrayBuffer = new ArrayBuffer(5*1024); //5KB
        const readLen = await fs.read(imageFile.fd, arrayBuffer);
        const content = Uint8ArrayToString(await b64.encode( new Uint8Array(arrayBuffer, 0, readLen) ));
        this.icon_mime = icon_mime;
        this.icon = content;
        this.validatedIcon = IconManager.validateUri(content, this.icon_mime);
    }

    @Builder pageJump(name: string, params: string[]) {
        NavDestination() {
            if (name==='qrcode') {
                QrCodePage({
                    title: $r('app.string.edit_share_title'),
                    uris: params,
                    label_main: [this.issuer],
                    label_sub: [this.name],
                })
            }
        }
        .backgroundColor($r('app.color.color_face'))
        .height('100%').width('100%')
        .hideTitleBar(true)
    }

    build() {
        Navigation(this.navStack) {
            Column({space: COLUMN_ITEM_GAP}) {
                if (this.validatedIcon) {
                    Image(this.validatedIcon)
                        .height(64).width(64)
                        .borderRadius(32)
                        .margin({bottom:COLUMN_ITEM_GAP})
                } else {
                    Stack({alignContent: Alignment.Bottom}) {
                        IssuerIcon({
                            issuer: this.issuer,
                            iconSize: '64vp',
                            iconRadius: '32vp',
                            fontSize: 36,
                        })
                        Button({type:ButtonType.Normal}) {
                            SymbolGlyph($r('sys.symbol.chevron_up_2'))
                                .fontWeight(FontWeight.Bolder)
                                .fontColor([$r('sys.color.font_primary')])
                                .fontSize(12)
                        }
                        .backgroundColor($r('sys.color.ohos_id_color_component_normal_transparent'))
                        .width(64).height(16)
                        .onClick(async () => {
                            await this.uploadIcon();
                        })
                    }
                    .width(64).height(64)
                    .borderRadius(32)
                    .clip(true)
                    .margin({bottom:COLUMN_ITEM_GAP})
                }
                Divider().strokeWidth('1px').width('90%')
                // information fields
                Column({space: COLUMN_ITEM_GAP}) {
                    LabeledSelect({
                        label: $r('app.string.edit_label_icon'),
                        entries: this.IconCandidatesEntries,
                        values: this.IconCandidatesValues,
                        selected: this.iconIndex,
                        onFocused: () => {
                            this.IconCandidates = this.iconManager.matchAllSync(this.issuer);
                            this.IconCandidatesEntries = Array.from(this.IconCandidates.keys());
                            this.IconCandidatesValues = Array.from(this.IconCandidates.values());
                            this.iconIndex = this.IconCandidatesValues.findIndex(x => x===this.icon);
                        }
                    })
                    LabeledTextInput({label: $r('app.string.edit_label_issuer'), text: this.issuer})
                    LabeledTextInput({label: $r('app.string.edit_label_name'), text: this.name})
                    LabeledTextInput({label: $r('app.string.edit_label_note'), text: this.note, required: false})
                    if (this.secret && this.secret!==FAKE_SECRET) {
                        LabeledUriHolder({
                            label: $r('app.string.edit_label_share'), uri: this.shareLink,
                            qrCallback: (uri) => {
                                this.navStack.pushPath({ name: 'qrcode',  param: [uri] });
                            }
                        })
                    }
                }
                // advance fields
                if (!this.editNewItem) {
                    Text() {
                        SymbolSpan(this.advanceCollapsed? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down'))
                            .fontColor([$r('sys.color.font_primary')])
                            .fontSize(16)
                        Span(this.advanceCollapsed? '  ' : ' ')
                        Span($r('app.string.edit_advanced_title'))
                    }
                    .width('100%')
                    .height(24)
                    .fontSize(16)
                    .onClick(() => {
                        animateTo({duration: 200}, () => {
                            this.advanceCollapsed = !this.advanceCollapsed;
                        });
                    })
                }
                if (!this.advanceCollapsed) {
                    Column({space: COLUMN_ITEM_GAP}) {
                        LabeledTextInput({label: $r('app.string.edit_label_secret'), text: this.secret,
                            type: InputType.Password, inputEnabled: this.secretInputEnabled})
                    }
                    Grid() {
                        GridItem() {
                            LabeledSelect({label: $r('app.string.edit_label_type'), entries: typeEntries, selected: this.typeIndex})
                        }
                        GridItem() {
                            LabeledSelect({label: $r('app.string.edit_label_hash_function'), entries: hashEntries, selected: this.hashIndex})
                        }
                        if (['TOTP', 'STEAM'].includes(typeEntries[this.typeIndex])) {
                            GridItem() {
                                LabeledTextInput({label: $r('app.string.edit_label_period'), text: this.period, type:InputType.Number})
                            }
                        }
                        if (typeEntries[this.typeIndex]==='HOTP') {
                            GridItem() {
                                LabeledTextInput({label: $r('app.string.edit_label_counter'), text: this.counter, type:InputType.Number})
                            }
                        }
                        GridItem() {
                            LabeledTextInput({label: $r('app.string.edit_label_digits'), text: this.digits, type:InputType.Number})
                        }
                        GridItem() {
                            LabeledTextInput({label: $r('app.string.edit_label_usage_count'), text: this.counter, inputEnabled:false})
                        }
                    }
                    .layoutDirection(GridDirection.Row)
                    .columnsTemplate('1fr 1fr')
                    .rowsGap(10).columnsGap(COLUMN_ITEM_GAP)
                    .maxCount(2)
                }
                //
                Button($r('app.string.button_text_save'))
                    .height('36vp')
                    .width('100%')
                    .enabled(this.saveBtnEnabled)
                    .onClick(() => { this.requestUpdateItem(); })
                if (!this.secretInputEnabled) {
                    Button($r('app.string.button_text_delete'))
                        .height('36vp')
                        .width('100%')
                        .backgroundColor($r('sys.color.warning'))
                        .onClick(() => { this.requestDeleteItem(); })
                }
            }
            .width('100%')
        }
        .height('auto')
        .width('90%')
        .padding({ bottom: COLUMN_ITEM_GAP+px2vp(this.bottomRectHeight) })
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .navDestination(this.pageJump)
    }
}
