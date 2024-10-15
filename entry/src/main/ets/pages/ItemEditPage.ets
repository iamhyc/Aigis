import { promptAction } from "@kit.ArkUI";
import { EVENT_REMOVE_ITEM, EVENT_UPDATE_ITEM, iconMatcher, RemovalRequestSchema,
    UpdateRequestSchema } from "../common/schema";
import { LabeledSelect, LabeledTextInput } from "../components/labeled";
import { OTPSchema, TimedOTPSchema } from "../crypto/otpUtils";

const COLUMN_ITEM_GAP: number = 8;
const FAKE_SECRET: string = '0'.repeat(16);
const typeEntries: string[] = ['TOTP', 'HOTP', 'STEAM'];
const hashEntries: string[] = ['SHA1', 'SHA256', 'SHA512'];

@Builder
export function ItemEditBuilder(
    context: Context,
    keyAlias: string,
    schema: OTPSchema,
) {
    Column() {
        ItemEditComponent({
            context, keyAlias, schema,
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
    @Require @Prop context: Context;
    @Require @Prop keyAlias: string;
    @Require @Prop schema: OTPSchema;
    @Watch('onValueChanged') @Require @Prop issuer: string;
    @Watch('onValueChanged') @Require @Prop name: string;
    @Watch('onValueChanged') @Require @Prop typeIndex: number;
    @Watch('onValueChanged') @Require @Prop hashIndex: number;
    @Watch('onValueChanged') @Require @Prop digits: string;
    @Watch('onValueChanged') @Prop note: string;
    @Watch('onValueChanged') @Prop period: string;
    @Watch('onValueChanged') @Prop counter: string;
    @Prop secret: string;
    @State secretInputEnabled: boolean = !(this.secret===FAKE_SECRET);
    @State icon: Resource = $rawfile(iconMatcher(this.issuer));
    @State saveBtnEnabled: boolean = this.secretInputEnabled;

    private onValueChanged(propName: string) {
        this.saveBtnEnabled = true;
        if (propName==='issuer') {
            this.icon = $rawfile(iconMatcher(this.issuer));
        }
    }

    private requestDeleteItem() {
        // popup for removal confirmation
        AlertDialog.show({
            title: $r('app.string.delete_title'),
            message: $r('app.string.delete_hint', `${this.schema.issuer} (${this.schema.name})`),
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

    private requestUpdateItem() {
        if (this.issuer.length===0 || this.name.length===0 || this.digits.length===0 || this.period.length===0 || this.counter.length===0) {
            promptAction.showToast({
                message: $r('app.string.error_required_missing_check'),
                duration: 1500
            });
        }
        if (this.secretInputEnabled && this.secret.length===0) {
            promptAction.showToast({
                message: $r('app.string.error_required_missing_check'),
                duration: 1500
            });
        }
        //
        const keyAlias = this.keyAlias;
        const type = typeEntries[this.typeIndex].toLowerCase();
        const issuer_name = `${this.issuer}:${this.name}`;
        const algorithm = hashEntries[this.hashIndex];
        const secret = this.secret===FAKE_SECRET? '' : this.secret;
        const counter = Number.parseInt(this.counter).toString();
        const digits = Number.parseInt(this.digits).toString();
        const period = Number.parseInt(this.period).toString();
        const uri = `otpauth://${type}/${issuer_name}?algorithm=${algorithm}&digits=${digits}&counter=${counter}&period=${period}&secret=${secret}&issuer=${this.issuer}`;
        //
        getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri, keyAlias} as UpdateRequestSchema);
        this.saveBtnEnabled = false;
    }

    build() {
        Column({space: COLUMN_ITEM_GAP}) {
            //
            Image(this.icon)
                .height(64).width(64)
                .borderRadius(32)
                .margin({top:COLUMN_ITEM_GAP, bottom:COLUMN_ITEM_GAP})
            Divider().strokeWidth('1px').width('90%')
            //
            Column({space: COLUMN_ITEM_GAP}) {
                LabeledTextInput({label: $r('app.string.edit_label_issuer'), text: this.issuer})
                LabeledTextInput({label: $r('app.string.edit_label_name'), text: this.name})
                // LabeledTextInput({label: $r('app.string.edit_label_note'), text: this.note, required: false})
                LabeledTextInput({label: $r('app.string.edit_label_secret'), text: this.secret,
                    type: InputType.Password, inputEnabled: this.secretInputEnabled})
            }
            //
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
                // GridItem() {
                //     LabeledTextInput({label: $r('app.string.edit_label_usage_count'), text: this.counter, inputEnabled:false})
                // }
            }
            .layoutDirection(GridDirection.Row)
            .columnsTemplate('1fr 1fr')
            .rowsGap(10).columnsGap(COLUMN_ITEM_GAP)
            .maxCount(2)
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
        .padding({ bottom: 28 }) //28vp for safe area
    }
}

@Entry
@Component
struct ItemEditPage {
    build() {
        Column() {
            Navigation() {

            }
            .title($r('app.string.ItemEditPage_title'), {
                // backgroundColor: $r('app.color.color_background'),
            })
            .titleMode(NavigationTitleMode.Mini)
            .mode(NavigationMode.Auto)
            .backgroundColor($r('app.color.color_face'))
        }
        .height('600vp')
        .width('100%')
    }
}
