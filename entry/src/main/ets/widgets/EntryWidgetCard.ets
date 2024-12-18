import { EntryCardBuilder } from './StaticWidgets';

@Entry
@Component
struct AigisWidgetCard {
    build() {
        FormLink({
            action: 'router',
            abilityName: 'EntryAbility',
        }) {
            EntryCardBuilder('100%', '100%', 0);
        }
    }
}
