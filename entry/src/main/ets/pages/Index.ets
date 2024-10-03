import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    RelativeContainer() {
      Text(this.message)
        .id('HelloWorld')
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
        .alignRules({
          center: { anchor: '__container__', align: VerticalAlign.Center },
          middle: { anchor: '__container__', align: HorizontalAlign.Center }
        })
    }
    .height('100%')
    .width('100%')
  }

  aboutToAppear() {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    this.loginWithHuaweiID();
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
    });
  }
}