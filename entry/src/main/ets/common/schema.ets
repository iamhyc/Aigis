import { OTPSchema } from "../crypto/otpUtils";
import { ValueType } from "./settings";

interface IssuerName {
    issuer: string,
    name: string
}

export function name2keyAlias(props: IssuerName): string {
    return `${props.issuer}:${props.name}`;
}

export function iconMatcher(issuer: string): string {
    return `icons/issuers/${issuer.toLowerCase()}.svg`;
}

export const EVENT_CODE_REQUEST: string = 'code-request';
export interface CodeRequestSchema {
    keyAlias: string,
}
export interface CodeResponseSchema {
    timestamp: number,
    code: string,
}

export const EVENT_UPDATE_ITEM: string = 'update-item';
export interface UpdateRequestSchema {
    uri: string,
    keyAlias?: string,
}
export interface UpdateResponseSchema {
    success: boolean,
    message?: string,
}

export const EVENT_MOVE_TO_TOP: string = 'move-to-top';
export interface MoveToTopRequestSchema {
    keyAlias: string,
}

export const EVENT_REMOVE_ITEM: string = 'remove-item';
export interface RemovalRequestSchema {
    keyAlias: string,
}

export const EVENT_UPDATE_SETTING: string = 'update-setting';
export interface SettingUpdateRequestSchema {
    key: string,
    value: ValueType,
}

export const EVENT_UPDATE_PASSWORD: string = 'update-password';
export interface PasswordUpdateRequestSchema {
    password: string,
}

export interface OTPItemInfo {
    keyAlias: string,
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}

export interface PBKDF2Material {
    salt: Uint8Array,
    iteration: number,
}
export interface MasterKeyInfo {
    type: 'PBKDF2',
    version: 'v1',
    keyAlias: string,
    secret: PBKDF2Material,
    params: PBKDF2Material,
}
