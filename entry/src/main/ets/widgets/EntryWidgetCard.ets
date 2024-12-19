import { EntryCardBuilder } from './StaticWidgets';

@Entry
@Component
struct AigisWidgetCard {
    build() {
        FormLink({
            action: 'router',
            abilityName: 'EntryAbility',
        }) {
            EntryCardBuilder({height: '100%', width: '100%', radius: 0});
        }
    }
}
