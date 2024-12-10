import { AuthLevelSupport } from "../crypto/authUtils";
import { OTPSchema } from "../crypto/otpUtils";

export interface CodeResponseSchema {
    timestamp: number,
    code: string,
    next?: string,
}

export type ImageMimeType = 'image/svg+xml'|'image/png'|'image/jpeg'|'image/webp';

export interface OTPItemInfo {
    uuid?: string,
    keyAlias: string,
    icon: string,
    icon_mime?: ImageMimeType,
    code: CodeResponseSchema,
    schema: OTPSchema,
    favorite?: boolean,
    last_used_timestamp?: number,
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

export type MasterKeyInfo = MasterKeyInfoV1 | MasterKeyInfoV2;
export interface MasterKeyInfoV1 {
    type: 'PBKDF2',
    version: 'v1',
    keyAlias: string,
    secret: PBKDF2Material,
    params: PBKDF2Material,
}
export interface MasterKeyInfoV2 {
    type: 'PBKDF2',
    version: 'v2',
    keyAlias: string,
    secret: PBKDF2Material,
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

export interface ImporterSchema {
    type: string,
    name: ResourceStr,
    description?: ResourceStr,
    format: ('.json' | '.txt')[],
    export_filename: string,
    import_password_required: boolean,
    export_password_required: boolean,
}
