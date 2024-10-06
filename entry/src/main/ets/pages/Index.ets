import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { scanCore, scanBarcode } from '@kit.ScanKit';
import { PREF_KEY_ITEMS } from '../common/conts';
import { OTPItemInfo, EVENT_CODE_REQUEST, CodeRequestSchema, EVENT_UPDATE_ITEM,
    UpdateRequestSchema,
    CodeResponseSchema} from '../common/schema';
import { name2keyAlias } from '../common/utils';
import { OTPSchema, TOTPSchema } from '../crypto/otpUtils';

const REFRESH_INTERVAL = 250;//ms
const storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
    @LocalStorageLink(PREF_KEY_ITEMS) items: OTPItemInfo[] = [];
    @State selected: string = '';

    build() {
        RelativeContainer() {
            Navigation() {
                Stack() {
                    // main content
                    List() {
                        ForEach(this.items,
                            (item: OTPItemInfo) => {
                                ListItem() {
                                    OTPItem({
                                        icon: item.icon,
                                        code: item.code,
                                        schema: item.schema,
                                        keyAlias: item.keyAlias,
                                        selected: this.selected,
                                    })
                                }
                            },
                            (item: OTPItemInfo) => item.keyAlias,
                        )
                    }
                    .width('100%')
                    .height('100%')
                    // floating add button
                    Button() {
                        Image($r('sys.media.ohos_ic_public_scan'))
                            .width($r('app.float.add_icon_size')).height($r('app.float.add_icon_size'))
                            .fillColor($r('sys.color.comp_background_primary'))
                    }
                    .backgroundColor($r('app.color.color_ribbon'))
                    .width($r('app.float.add_circle_size'))
                    .height($r('app.float.add_circle_size'))
                    .position({bottom: '2vp', right: '30vp'}) // bottom safe area
                    .shadow({radius: 10})
                    .onClick(async () => {
                        const uri:string = await this.scanQrCode();
                        getContext(this).eventHub.emit(EVENT_UPDATE_ITEM, {uri} as UpdateRequestSchema);
                    })
                }
                .height('100%')
                .width('100%')
            }
            .title($r('app.string.app_title'), {
                backgroundColor: $r('app.color.color_background'),
            })
            .titleMode(NavigationTitleMode.Mini)
            .hideBackButton(true)
            .mode(NavigationMode.Auto)
            .backgroundColor($r('app.color.color_face'))
        }
        .height('100%')
        .width('100%')
    }

    aboutToAppear() {
        hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
        // this.loginWithHuaweiID();
    }

    private async scanQrCode(): Promise<string> {
        let options: scanBarcode.ScanOptions = {
            scanTypes: [scanCore.ScanType.ALL],
            enableMultiMode: true,
            enableAlbum: true
        };

        try {
            const result = await scanBarcode.startScanForResult(getContext(this), options);
            return result.originalValue
        } catch (err) {
            hilog.error(0x0001, '[Scan CPSample]', `Failed to get ScanResult by callback with options. Code: ${err.code}, message: ${err.message}`);
            return '';
        }
    }

    /**
     * Sample code for using HUAWEI ID to log in to atomic service.
     * According to the Atomic Service Review Guide, when a atomic service has an account system,
     * the option to log in with a HUAWEI ID must be provided.
     * The following presets the atomic service to use the HUAWEI ID silent login function.
     * To enable the atomic service to log in successfully using the HUAWEI ID, please refer
     * to the HarmonyOS HUAWEI ID Access Guide to configure the client ID and fingerprint certificate.
     */
    private loginWithHuaweiID() {
        // Create a login request and set parameters
        let loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
        // Whether to forcibly launch the HUAWEI ID login page when the user is not logged in with the HUAWEI ID
        loginRequest.forceLogin = false;
        // Execute login request
        let controller = new authentication.AuthenticationController();
        controller.executeRequest(loginRequest).then((data) => {
            let loginWithHuaweiIDResponse = data as authentication.LoginWithHuaweiIDResponse;
            let authCode = loginWithHuaweiIDResponse.data?.authorizationCode;
            // Send authCode to the backend in exchange for unionID, session
        }).catch((error: BusinessError) => {
            hilog.error(0x0000, 'testTag', 'error: %{public}s', JSON.stringify(error));
            if (error.code == authentication.AuthenticationErrorCode.ACCOUNT_NOT_LOGGED_IN) {
                // HUAWEI ID is not logged in, it is recommended to jump to the login guide page
            }
        })
    }
}

@Component
export struct OTPItem {
    @Prop icon: string;
    @Prop code: CodeResponseSchema;
    @Prop keyAlias: string;
    @Watch('onItemUpdated') @Prop schema: OTPSchema;
    @Link selected: string;
    @State remain_time: number = 0;

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            // Main Content
            Row({ space: '16vp' }) {
                // display issuer icon
                Image($rawfile(this.icon))
                    .margin({left: $r('app.float.visual_space')})
                    .borderRadius($r('app.float.issuer_icon_radius'))
                    .height($r('app.float.issuer_icon_size'))
                    .width($r('app.float.issuer_icon_size'))
                    .alt(this.schema.issuer)
                // display information area
                Column({ space: '4vp' }) {
                    Text() {
                        Span(this.schema.issuer)
                            .fontSize($r('sys.float.Subtitle_S'))
                            .fontWeight(FontWeight.Bold)
                            .fontColor($r('sys.color.font_primary'))
                        Span(` (${this.schema.name})`)
                            .fontSize($r('sys.float.Subtitle_S'))
                            .fontWeight(FontWeight.Normal)
                            .fontColor($r('sys.color.font_secondary'))
                    }

                    if (this.selected===this.keyAlias) {
                        Text(this.hiddenDigits())
                            .fontSize($r('sys.float.Subtitle_L'))
                            .letterSpacing(5)
                    } else if (this.remain_time <= 0) {
                        Text(this.splitDigits())
                            .fontWeight(FontWeight.Medium)
                            .fontSize($r('sys.float.Subtitle_L'))
                    }
                }
                .alignItems(HorizontalAlign.Start)
            }
            .align(Alignment.Top)
            .height('100%')
            .width('100%')
            .zIndex(1)
            // show progress bar for time-based OTP
            if (this.selected && (this.schema as TOTPSchema).period) {
                Progress({value: this.remain_time, total:(this.schema as TOTPSchema).period*1000})
                    .height('2vp')
                    .width('100%')
                    .zIndex((2))
                    .style({enableSmoothEffect:true})
            }
            // divider bar at the end
            Divider().strokeWidth('1px').zIndex(2)
        }
        .height('64vp')
        .width('100%')
        .onClick(ev => {
            if (this.selected===this.keyAlias) {
                this.selected = '';
            } else {
                this.selected = this.keyAlias;
            }
        });
    }

    private onItemUpdated() {
        if (this.selected===this.keyAlias) {
            setTimeout(() => {

            }, REFRESH_INTERVAL);
        }
    }

    private splitDigits(): string {
        if (this.code?.timestamp) {
            this.remain_time = Date.now() - this.code.timestamp;
            if (this.remain_time > REFRESH_INTERVAL) {
                return this.code.code.match(/.{1,3}/g)!.join(' ');
            }
        }

        getContext(this).eventHub.emit(EVENT_CODE_REQUEST, {
            keyAlias: this.keyAlias,
        } as CodeRequestSchema);
        return this.hiddenDigits();
    }

    private hiddenDigits(): string {
        return '⬤'.repeat(this.schema.digits).match(/.{1,3}/g)!.join(' ');
    }
}