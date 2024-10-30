import { userAuth } from '@kit.UserAuthenticationKit';
import { Atl1AuthResult, MasterKeyInfo, PBKDF2Material } from '../common/schema';
import { getRandomInt, stringToUint8Array, Uint8ArrayToString } from '../common/utils';
import { AES_KEY_USAGE, generateRandomSalt24, HUKSAgent, PARAMS_DERIVE_SRC_KEY } from './huksUtils';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

// Reference: https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/errorcode-useriam-V5
export enum AUTH_ERROR_CODE {
    AUTH_SUCCESS = 12500000,
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

export type AuthLevelSupport = 'ATL1' | 'ATL3';

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

export function ATL1AuthAvailable(): boolean {
    return checkAuthEnvironment() >= AuthTrustLevel.ATL1;
}

export function ATL3AuthAvailable(): boolean {
    return checkAuthEnvironment() >= AuthTrustLevel.ATL3;
}

export async function acquireUserAuthToken(level: AuthLevelSupport, challenge?: Uint8Array): Promise<Uint8Array> {
    return new Promise(async (resolve, reject) => {
        const rand = cryptoFramework.createRandom();
        if (challenge===undefined) {
            challenge = (await rand.generateRandom(32)).data;
        }
        //
        let authParam: userAuth.AuthParam;
        switch (level) {
            case 'ATL1':
                authParam = {
                    challenge, authTrustLevel: userAuth.AuthTrustLevel.ATL1,
                    authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.PIN],
                    reuseUnlockResult: {
                        reuseMode: userAuth.ReuseMode.AUTH_TYPE_RELEVANT,
                        reuseDuration: 5*1000,//5s
                    },
                };
                break;
            case 'ATL3':
                authParam = {
                    challenge, authTrustLevel: userAuth.AuthTrustLevel.ATL3,
                    authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
                    reuseUnlockResult: {
                        reuseMode: userAuth.ReuseMode.AUTH_TYPE_RELEVANT,
                        reuseDuration: 5*1000,//5s
                    },
                };
                break;
            default:
                throw new Error(`Unsupported Auth Level: ${level}`);
        }
        //
        const userAuthInstance = userAuth.getUserAuthInstance(authParam, {
            'title': 'Aigis Authenticator',
        });
        userAuthInstance.on('result', {
            onResult(result) {
                userAuthInstance.off('result');
                if (result.result===AUTH_ERROR_CODE.AUTH_SUCCESS) {
                    resolve(result.token);
                } else {
                    reject(result.result);
                }
            }
        });
        //
        userAuthInstance.start();
    });
}

export async function acquireAtl1Auth(): Promise<Atl1AuthResult> {
    const authToken = await acquireUserAuthToken('ATL1');
    const timestamp  = Date.now();
    return { authToken, timestamp };
}

async function pbkdf2KeyDerive(password: string, material: PBKDF2Material, keySize: 256): Promise<Uint8Array> {
    const pbkdf2 = cryptoFramework.createKdf('PBKDF2|SHA256');
    const spec: cryptoFramework.PBKDF2Spec = {
        algName: 'PBKDF2', password,
        salt: stringToUint8Array(material.salt),
        iterations: material.iteration,
        keySize: Math.floor(keySize/8),
    };
    const secret = await pbkdf2.generateSecret(spec);
    return secret.data;
}

export async function generateMasterKeyInHUKS(keyAlias: string, password: string, purpose: AES_KEY_USAGE, secret?: PBKDF2Material, params?: PBKDF2Material): Promise<MasterKeyInfo> {
    const type = 'PBKDF2';
    const version = 'v1';
    // derive AES256 key from password and import in HUKS
    if (secret===undefined) {
        secret = {
            salt: Uint8ArrayToString(await generateRandomSalt24()),
            iteration: getRandomInt(1000, 10000),
        };
    }
    const secretKey = await pbkdf2KeyDerive(password, secret, 256);
    await HUKSAgent.importKeyItem(keyAlias, PARAMS_DERIVE_SRC_KEY, secretKey);
    // derive AES256-ECB key (with AES256key) in HUKS
    if (params===undefined) {
        params = {
            salt: Uint8ArrayToString(await generateRandomSalt24()),
            iteration: getRandomInt(1000, 10000),
        };
    }
    await HUKSAgent.deriveAesKeyItem(keyAlias, purpose, password, params, keyAlias);
    //
    return { type, version, keyAlias, secret, params };
}
