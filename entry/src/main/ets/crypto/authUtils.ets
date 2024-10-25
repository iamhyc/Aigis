import { userAuth } from '@kit.UserAuthenticationKit';
import { MasterKeyInfo, PBKDF2Material } from '../common/schema';
import { getRandomInt } from '../common/utils';
import { AES_KEY_USAGE, generateRandomSalt24, HUKSAgent, PARAMS_DERIVE_SRC_KEY } from './huksUtils';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

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
    // ATL1: at least with PIN available
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

export async function pbkdf2KeyDerive(password: string, material: PBKDF2Material, keySize: 256): Promise<Uint8Array> {
    const pbkdf2 = cryptoFramework.createKdf('PBKDF2|SHA256');
    const spec: cryptoFramework.PBKDF2Spec = {
        algName: 'PBKDF2', password,
        salt: material.salt,
        iterations: material.iteration,
        keySize: Math.floor(keySize/8),
    };
    const secret = await pbkdf2.generateSecret(spec);
    return secret.data;
}

export async function generateMasterKeyInHUKS(keyAlias: string, password: string, purpose: AES_KEY_USAGE): Promise<MasterKeyInfo> {
    const type = 'PBKDF2';
    const version = 'v1';
    // derive AES256 key from password and import in HUKS
    const secret: PBKDF2Material = {
        salt: await generateRandomSalt24(),
        iteration: getRandomInt(1000, 10000),
    };
    const secretKey = await pbkdf2KeyDerive(password, secret, 256);
    await HUKSAgent.importKeyItem(keyAlias, PARAMS_DERIVE_SRC_KEY, secretKey);
    // derive AES256-ECB key (with AES256key) in HUKS
    const params: PBKDF2Material = {
        salt: await generateRandomSalt24(),
        iteration: getRandomInt(1000, 10000),
    }
    await HUKSAgent.deriveAesKeyItem(keyAlias, purpose, password, params, keyAlias);
    //
    return { type, version, keyAlias, secret, params };
}
