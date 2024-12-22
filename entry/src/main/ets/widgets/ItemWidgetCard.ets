import { DummyOTPItemInfo } from '../common/dummies';
import { EVENT_CODE_REQUEST } from '../common/events';
import { OTPItemInfo } from '../common/schema';
import { ItemWidgetBuilder } from './DynamicWidgets';

const localStorage = new LocalStorage();

@Entry(localStorage)
@Component
struct ItemWidgetCard {
    @LocalStorageProp('formImages') formImages: Record<string,number> = {};
    @LocalStorageProp('keyAlias') keyAlias: string = '';
    @LocalStorageProp('itemInfo') itemInfo: OTPItemInfo = DummyOTPItemInfo;

    build() {
        RelativeContainer() {
            ItemWidgetBuilder(this.keyAlias, this.formImages, this.itemInfo, {height: '100%', width: '100%', radius: 0}, () => {
                postCardAction(this, {
                    action: 'message',
                    params: EVENT_CODE_REQUEST,
                });
            })
        }
    }
}
