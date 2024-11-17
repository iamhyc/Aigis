import { AuthLevelSupport } from "../crypto/authUtils";
import { OTPSchema } from "../crypto/otpUtils";

export interface CodeResponseSchema {
    timestamp: number,
    code: string,
}

export interface OTPItemInfo {
    keyAlias: string,
    hashKeyAlias?: string,
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}

export interface SecretSchema {
    keyAlias: string,
    secret: string,
    encrypted?: AesGcmMaterial,
}

export interface AigisContentSchema {
    masterKey: MasterKeyInfo,
    items: OTPItemInfo[],
    secrets: SecretSchema[],
    settings?: string,
}

export interface IconPackStore {
    uuid: string,
    version: string,
    name: string,
    icons: number,
    uri: string,
    isDefault: boolean,
}

export interface IconPackSchema {
    uuid: string,
    version: string,
    name: string,
    icons: IssuerIconFormat[],
}

export interface IssuerIconFormat {
    filename: string,
    category?: string,
    issuer: string[],
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

export interface AtlAuthResult {
    authLevel: AuthLevelSupport,
    authToken: Uint8Array,
    timestamp: number,
};
