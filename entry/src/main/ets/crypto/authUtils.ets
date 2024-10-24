import { userAuth } from '@kit.UserAuthenticationKit';

// Reference: https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/errorcode-useriam-V5
export enum AUTH_ERROR_CODE {
    AUTH_FAILED = 12500001,
    GENERAL_OPERATION_ERROR = 12500002,
    AUTH_CANCELED = 12500003,
    AUTH_TIMEOUT = 12500004,
    AUTH_TYPE_NOT_SUPPORT = 12500005,
    AUTH_LEVEL_NOT_SUPPORT = 12500006,
    AUTH_SERVICE_BUSY = 12500007,
    AUTH_LOCKED_OUT = 12500009,
    AUTH_NOT_ENROLLED = 12500010,
    AUTH_SWITCH_TO_CUSTOM = 12500011,
    AUTH_PIN_EXPIRED = 12500013,
    AUTH_FACE_AUTH_FAILED = 12700001,
}

export enum AuthTrustLevel {
    None,
    ATL1,
    ATL2,
    ATL3,
    ATL4,
}

export function checkAuthEnvironment(): AuthTrustLevel {
    // NONE: even no pin available
    try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
    } catch (err) {
        return AuthTrustLevel.None;
    }
    //
    try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL4);
        return AuthTrustLevel.ATL4;
    } catch (err) {
        try {
            userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL4);
            return AuthTrustLevel.ATL4;
        } catch (err) {
            try {
                userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL3);
                return AuthTrustLevel.ATL3;
            } catch (err) {
                return AuthTrustLevel.ATL1;
            }
        }
    }
}

export function biometricAuthAvailable(): boolean {
    return checkAuthEnvironment() >= AuthTrustLevel.ATL2;
}

export class PBKDF2MasterKey {

}