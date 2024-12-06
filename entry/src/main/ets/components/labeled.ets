
const COLUMN_LABEL_GAP: number = 4;
const fontSize: number = 16;

@Component
export struct LabeledTextInput {
    @Link text: string;
    @State type: InputType = InputType.Normal;
    @State label: ResourceStr = '';
    @State inputEnabled: boolean = true;
    @State required: boolean = true;
    @State errorMessage: ResourceStr | undefined = undefined;

    build() {
        Column({space: COLUMN_LABEL_GAP}) {
            Row() {
                Text(this.label)
                    .fontColor($r('sys.color.font_secondary'))
                    .fontSize(fontSize)
                    .textAlign(TextAlign.Start)
                    .offset({left:16})
            }
            .width('100%')
            Row() {
                TextInput({placeholder: this.label, text:$$this.text})
                    .enabled(this.inputEnabled)
                    .fontSize(fontSize)
                    .type(this.type)
                    .showError(this.errorMessage)
                    .onChange(() => {
                        if (this.text.length===0 && this.required) {
                            this.errorMessage = $r('app.string.error_required_missing')
                        } else {
                            this.errorMessage = undefined;
                        }
                    })
            }
            .width('100%')
        }
        .width('100%')
    }

    aboutToAppear(): void {
        if (this.text.length===0 && this.required) {
            this.errorMessage = $r('app.string.error_required_missing')
        }
    }
}

@Component
export struct LabeledUriHolder {
    @Require @Prop label: ResourceStr;
    @Require @Prop uri: string;

    qrCallback?: (uri: string) => void;

    private wHeight: ResourceStr = '42vp';
    private wRadius: ResourceStr = '21vp';

    build() {
        Column({space: COLUMN_LABEL_GAP}) {
            Row() {
                Text(this.label)
                    .fontColor($r('sys.color.font_secondary'))
                    .fontSize(fontSize)
                    .textAlign(TextAlign.Start)
                    .offset({left:16})
            }
            .width('100%')
            Row({space: '3vp'}) {
                Column() {
                    Scroll() {
                        Text(this.uri)
                            .fontColor($r('sys.color.font_tertiary'))
                            .fontSize(fontSize)
                            .maxLines(1)
                            .wordBreak(WordBreak.BREAK_ALL)
                            .copyOption(CopyOptions.LocalDevice)
                    }
                    .offset({left:fontSize})
                    .scrollable(ScrollDirection.Horizontal)
                    .scrollBar(BarState.Off)
                }
                .width(`calc(100% - ${this.wHeight} - 3vp)`)
                .padding({right:fontSize})
                Column() {
                    Text() {
                        SymbolSpan($r('sys.symbol.qrcode'))
                            .fontSize(20)
                            .fontColor([$r('sys.color.font_primary')])
                    }
                    .textAlign(TextAlign.Center)
                    .width(this.wHeight).height(this.wHeight)
                }
                .height(this.wHeight)
                .onClick(() => { this.qrCallback && this.qrCallback(this.uri) })
            }
            .width('100%')
            .height(this.wHeight)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(this.wRadius)
        }
        .width('100%')
    }
}

@Component
export struct LabeledSelect {
    @Link selected: number;
    @Require @Prop label: Resource | string = '';
    @Require @Prop entries: ResourceStr[];
    @Prop values: ResourceStr[] = this.entries;

    onFocused?: () => void;

    build() {
        Column({space: COLUMN_LABEL_GAP}) {
            Row() {
                Text(this.label)
                    .fontColor($r('sys.color.font_secondary'))
                    .fontSize(fontSize)
                    .textAlign(TextAlign.Start)
                    .offset({left:16})
            }.width('100%')
            Row() {
                Select(this.entries.map(x => {return {value:x} as SelectOption}))
                    .selected($$this.selected)
                    .value(this.entries[this.selected])
                    .optionWidth(OptionWidthMode.FIT_TRIGGER)
                    .width('100%')
                    .onClick(() => { this.onFocused && this.onFocused(); })
            }.width('100%')
        }
        .width('100%')
    }
}

