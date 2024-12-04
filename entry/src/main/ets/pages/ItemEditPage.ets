import { promptAction } from "@kit.ArkUI";
import { EVENT_REMOVE_ITEM, EVENT_UPDATE_ITEM, RemovalRequestSchema, UpdateRequestSchema } from "../common/events";
import { IconManager } from "../common/icons";
import { IconPackStore } from "../common/schema";
import { IssuerIcon } from "../components/icons";
import { LabeledSelect, LabeledTextInput } from "../components/labeled";
import { IssuerName, issuerNameToString, OTPSchema, TimedOTPSchema } from "../crypto/otpUtils";

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
    editNewItem: boolean,
) {
    Column() {
        ItemEditComponent({
            context, exIssuerNames, keyAlias, schema, icon, editNewItem,
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
    @Watch('onValueChanged') @Prop note: string;
    @Watch('onValueChanged') @Prop period: string;
    @Watch('onValueChanged') @Prop counter: string;
    @Prop secret: string;
    @State secretInputEnabled: boolean = this.editNewItem;
    @State saveBtnEnabled: boolean = this.editNewItem;
    @State advanceCollapsed: boolean = !this.editNewItem;

    iconManager: IconManager = new IconManager(this.IconPacks);
    IconCandidates: Map<ResourceStr,string> = this.iconManager.matchAllSync(this.issuer);
    IconCandidatesEntry: ResourceStr[] = Array.from(this.IconCandidates.keys());
    IconCandidatesValues: string[] = Array.from(this.IconCandidates.values());
    @State validatedIcon: string = IconManager.validateUri(this.editNewItem? this.IconCandidatesValues[0] : this.icon);
    @Watch('onValueChanged') @State iconIndex: number = this.IconCandidatesValues.findIndex(x => x===this.icon);

    private onValueChanged(propName: string) {
        this.saveBtnEnabled = true;
        if (propName==='iconIndex') {
            this.icon = this.IconCandidatesValues[ this.iconIndex ];
            this.validatedIcon = IconManager.validateUri(this.icon);
        }
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
        const issuerNameCollided = this.exIssuerNames.find(x => x.issuer===this.issuer && x.name===this.name);
        //
        if (issuerNameCollided) {
            const allow_overwrite = this.editNewItem; //overwrite when adding new ones
            const issuerName = issuerNameCollided;
            this.requestOverwriteConfirm(issuerNameToString(issuerName), allow_overwrite, () => {
                getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, issuerName, icon} as UpdateRequestSchema);
            });
        } else {
            const keyAlias = this.editNewItem? undefined : this.keyAlias;
            getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, keyAlias, icon} as UpdateRequestSchema);
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

    build() {
        Column({space: COLUMN_ITEM_GAP}) {
            if (this.validatedIcon) {
                Image(this.validatedIcon)
                    .height(64).width(64)
                    .borderRadius(32)
                    .margin({bottom:COLUMN_ITEM_GAP})
            } else {
                IssuerIcon({
                    issuer: this.issuer,
                    iconSize: '64vp',
                    iconRadius: '32vp',
                    fontSize: 36,
                })
                    .margin({bottom:COLUMN_ITEM_GAP})
            }
            Divider().strokeWidth('1px').width('90%')
            // information fields
            Column({space: COLUMN_ITEM_GAP}) {
                LabeledSelect({
                    label: $r('app.string.edit_label_icon'),
                    entries: Array.from( this.IconCandidates.keys() ),
                    values: Array.from( this.IconCandidates.values() ),
                    selected: this.iconIndex,
                })
                LabeledTextInput({label: $r('app.string.edit_label_issuer'), text: this.issuer})
                LabeledTextInput({label: $r('app.string.edit_label_name'), text: this.name})
                LabeledTextInput({label: $r('app.string.edit_label_note'), text: this.note, required: false})
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
        .width('90%')
        .padding({ bottom: COLUMN_ITEM_GAP+px2vp(this.bottomRectHeight) })
    }
}
