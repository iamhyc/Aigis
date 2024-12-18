import { EntryCardBuilderWrapper } from "./StaticWidgets";

export interface FormConfigInfo {
    moduleName: 'entry',
    abilityName: string,
    formName: string,
    dimension: number,
    displayName: ResourceStr,
    description: ResourceStr,
    builderWrapper: WrappedBuilder<Object[]>,
    params: Object[],
}

export const CardWidgetInfos: FormConfigInfo[] = [
    // StaticEntryCard1x2,
    {
        moduleName: 'entry', abilityName: 'EntryFormAbility', formName: 'AigisWidget',
        dimension: 1, displayName: $r('app.string.AigisWidget_display_name'), description: $r('app.string.AigisWidget_desc'),
        builderWrapper: EntryCardBuilderWrapper as WrappedBuilder<Object[]>,
        params: ['54vp', '150vp', 14] as Object[],
    },
    // StaticEntryCard2x2,
    {
        moduleName: 'entry', abilityName: 'EntryFormAbility', formName: 'AigisWidget',
        dimension: 2, displayName: $r('app.string.AigisWidget_display_name'), description: $r('app.string.AigisWidget_desc'),
        builderWrapper: EntryCardBuilderWrapper  as WrappedBuilder<Object[]>,
        params: ['150vp', '150vp', 14] as Object[],
    },
];
