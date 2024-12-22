import { AddFormMenuItem } from "@ohos.arkui.advanced.FormMenu";
import { formBindingData, formProvider } from "@kit.FormKit";
import { StaticCardWidgetInfos, FormConfigInfo, ItemEntryWidgetInfos } from "../widgets";
import { LengthUnit, promptAction } from "@kit.ArkUI";
import { fileIo as fs } from '@kit.CoreFileKit';
import { AddCardRequest, EVENT_ADD_CARD, EVENT_MINIMIZE_WINDOW_REQUEST } from "../common/events";
import { OTPItemInfo } from "../common/schema";
import { IconManager } from "../common/icons";

const COLUMN_ITEM_GAP: number = 8;

@Builder
export function CardSwiperBuilder(keyAlias: string, itemInfo: OTPItemInfo, closeCallback: () => void) {
    CardSwiperComponent({
        keyAlias, itemInfo, closeCallback,
    })
}

@Builder
function CardMenu(componentId: string, formConfigInfo: FormConfigInfo, keyAlias: string, _formBindingData?: formBindingData.FormBindingData, closeCallback?: () => void) {
    Menu() {
        AddFormMenuItem({
            bundleName: 'com.atomicservice.5765880207855519999',
            abilityName: formConfigInfo.abilityName,
            parameters: {
                'ohos.extra.param.key.form_dimension': formConfigInfo.dimension,
                'ohos.extra.param.key.form_name': formConfigInfo.formName,
                'ohos.extra.param.key.module_name': formConfigInfo.moduleName,
            }
        }, componentId, {
            formBindingData: _formBindingData,
            callback: (error, formId) => {
                if (error?.code === 0) {
                    promptAction.showToast({message: $r('app.string.form_added_success_prompt'), duration: 500});
                    getContext().eventHub.emit(EVENT_ADD_CARD, {formId, keyAlias} as AddCardRequest);
                    getContext().eventHub.emit(EVENT_MINIMIZE_WINDOW_REQUEST, {});
                    closeCallback && closeCallback();
                } else {
                    promptAction.showToast({message: $r('app.string.form_added_fail_prompt', error.message), duration: 500});
                }
            },
        })
    }
}

@Component
struct CardSwiperItem {
    @Require @Prop componentId: string;
    @Require @Prop formConfig: FormConfigInfo;
    @Require @Prop keyAlias: string;
    @Prop formBindingData: formBindingData.FormBindingData;

    closeCallback?: () => void

    build() {
        Column() {
            Flex({
                direction: FlexDirection.Column,
                justifyContent: FlexAlign.Start,
                alignItems: ItemAlign.Center,
                space: { main:{value:COLUMN_ITEM_GAP, unit:LengthUnit.VP} }
            }) {
                Column({space:3}) {
                    Text(this.formConfig.displayName)
                        .fontSize(24)
                        .fontWeight(FontWeight.Bold)
                    Text(this.formConfig.description)
                        .fontSize(16)
                        .fontColor($r('sys.color.font_secondary'))
                }
                .padding({top:COLUMN_ITEM_GAP})
                .flexBasis(64)
                .flexShrink(1)
                //
                Row() {
                    Row() {
                        this.formConfig.builderWrapper.builder(...this.formConfig.params)
                    }
                    .borderRadius(14)
                    .bindContextMenu(
                        CardMenu(this.componentId, this.formConfig, this.keyAlias, this.formBindingData, this.closeCallback),
                        ResponseType.LongPress,
                        {
                            placement: Placement.RightTop
                        }
                    )
                    .clickEffect({level:ClickEffectLevel.HEAVY})
                    .id(this.componentId)
                }
                .height('100%')
                .flexShrink(10)
            }
            .height('100%')
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')
    }
}

@Component
struct CardSwiperComponent {
    @StorageProp('bottomRectHeight') bottomRectHeight: number = 0;
    @Require @Prop keyAlias: string;
    @Require @Prop itemInfo: OTPItemInfo;

    closeCallback?: () => void;

    private formImages(): Record<string, number> {
        const validatedUri = IconManager.validateUri(this.itemInfo.icon, this.itemInfo.icon_mime);
        if (validatedUri.startsWith('file:')) {
            const file = fs.openSync(validatedUri);
            return { 'icon': file.fd };
        }
        return {}
    }

    build() {
        Column({space:COLUMN_ITEM_GAP}) {
            Swiper() {
                ForEach(this.keyAlias? ItemEntryWidgetInfos(this.keyAlias, this.formImages(), this.itemInfo) : StaticCardWidgetInfos,
                    (item: FormConfigInfo, index: number) => {
                        CardSwiperItem({
                            closeCallback: this.closeCallback,
                            componentId: `comp_${index}`,
                            formConfig: item,
                            keyAlias: this.keyAlias,
                            formBindingData: formBindingData.createFormBindingData({
                                keyAlias: this.keyAlias,
                                itemInfo: this.itemInfo,
                            }),
                        })
                    }
                )
            }
            .height('calc(100% - 36vp)')
            .loop(false)
            .displayCount(1)
            //
            Row() {
                Text($r('app.string.form_long_press_hint'))
                    .fontSize(16)
                    .fontColor($r('sys.color.font_secondary'))
            }
            .height(36)
        }
        .height('100%')
        .width('100%')
        .padding({ bottom: COLUMN_ITEM_GAP+px2vp(this.bottomRectHeight) })
    }
}
