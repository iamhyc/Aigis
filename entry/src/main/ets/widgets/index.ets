import { OTPItemInfo } from "../common/schema";
import { ItemWidgetBuilderWrapper } from "./DynamicWidgets";
import { EntryCardBuilderWrapper } from "./StaticWidgets";

export interface FormDimension {
    height: string | number,
    width: string | number,
    radius: number,
}

export interface FormConfigInfo {
    moduleName: 'entry',
    abilityName: 'EntryFormAbility',
    formName: string,
    dimension: number,
    displayName: ResourceStr,
    description: ResourceStr,
    builderWrapper: WrappedBuilder<Object[]>,
    params: Object[],
}

export interface ItemFormBindingData {
    formImages: Record<string, number>,
    keyAlias: string,
    itemInfo: OTPItemInfo,
}

const CardDimension1: FormDimension  = {
    height:'54vp', width:'150vp', radius:14
};
const CardDimension2: FormDimension  = {
    height:'150vp', width:'150vp', radius:14
};

export const StaticCardWidgetInfos: FormConfigInfo[] = [
    // StaticEntryCard (1x2),
    {
        moduleName: 'entry', abilityName: 'EntryFormAbility', formName: 'AigisWidget',
        dimension: 1, displayName: $r('app.string.AigisWidget_display_name'), description: $r('app.string.AigisWidget_desc'),
        builderWrapper: EntryCardBuilderWrapper as WrappedBuilder<Object[]>,
        params: [CardDimension1],
    },
    // StaticEntryCard (2x2),
    {
        moduleName: 'entry', abilityName: 'EntryFormAbility', formName: 'AigisWidget',
        dimension: 2, displayName: $r('app.string.AigisWidget_display_name'), description: $r('app.string.AigisWidget_desc'),
        builderWrapper: EntryCardBuilderWrapper  as WrappedBuilder<Object[]>,
        params: [CardDimension2],
    },
];

export function ItemEntryWidgetInfos(keyAlias: string, formImages: Record<string, number>, itemInfo: OTPItemInfo): FormConfigInfo[] {
    return [
        // ItemEntryWidget (1x2)
        {
            moduleName: 'entry', abilityName: 'EntryFormAbility', formName: 'ItemWidget',
            dimension: 1, displayName: $r('app.string.ItemWidget_display_name'), description: $r('app.string.ItemWidget_desc'),
            builderWrapper: ItemWidgetBuilderWrapper as WrappedBuilder<Object[]>,
            params: [keyAlias, formImages, itemInfo, CardDimension1],
        },
    ];
}
