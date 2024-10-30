import { OTPSchema } from "../crypto/otpUtils";

export function iconMatcher(issuer: string): string {
    const issuerKey = issuer.toLowerCase().replace(/(\.org|\.com)$/, '')
    return `icons/issuers/${issuerKey}.svg`;
}

export interface CodeResponseSchema {
    timestamp: number,
    code: string,
}

export interface OTPItemInfo {
    keyAlias: string,
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}

export interface EncryptedSecret {
    material: AesGcmMaterial,
    secret: string,
}

export interface SecretSchema {
    keyAlias: string,
    secret?: string,
    hashKeyAlias?: string,
    encrypted?: EncryptedSecret,
}

export interface AigisContentSchema {
    masterKey: MasterKeyInfo,
    items: OTPItemInfo[],
    secrets: SecretSchema[],
    rawSecrets?: Uint8Array[],
    settings?: string,
}

export interface PBKDF2Material {
    salt: string,
    iteration: number,
}
export interface MasterKeyInfo {
    type: 'PBKDF2',
    version: 'v1',
    keyAlias: string,
    secret: PBKDF2Material,
    params: PBKDF2Material,
}

export interface AesGcmMaterial {
    aad: string,
    nonce: string,
}

export interface Atl1AuthResult {
    authToken: Uint8Array,
    timestamp: number,
};
