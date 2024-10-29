import { OTPSchema } from "../crypto/otpUtils";
import { stringToUint8Array, Uint8ArrayToString } from "./utils";

interface IssuerName {
    issuer: string,
    name: string
}

export function name2keyAlias(props: IssuerName): string {
    return `${props.issuer}:${props.name}`;
}

export function iconMatcher(issuer: string): string {
    const issuerKey = issuer.toLowerCase().replace(/(\.org|\.com)$/, '')
    return `icons/issuers/${issuerKey}.svg`;
}

export interface CodeResponseSchema {
    timestamp: number,
    code: string,
}

export const FAKE_OTP_CODE = '******';

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
    encrypted?: boolean,
}

export interface AigisContentSchema {
    masterKey: MasterKeyInfo,
    items: OTPItemInfo[],
    secrets: SecretSchema[],
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
