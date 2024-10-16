
const COLUMN_LABEL_GAP: number = 4;
const fontSize: number = 16;

@Component
export struct LabeledTextInput {
    @Link text: string;
    @State type: InputType = InputType.Normal;
    @State label: string | Resource = '';
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
export struct LabeledSelect {
    @Link selected: number;
    @State label: Resource | string = '';
    @State entries: string[] = [];

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
                    .width('100%')
            }.width('100%')
        }
        .width('100%')
    }
}

