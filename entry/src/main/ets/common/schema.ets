import { OTPSchema } from "../crypto/otpUtils";

interface IssuerName {
    issuer: string,
    name: string
}

export function name2keyAlias(props: IssuerName): string {
    return `${props.issuer}:${props.name}`;
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
}
export interface UpdateResponseSchema {
    success: boolean,
    message?: string,
}

export const EVENT_PERSIST_REQUEST: string = 'persist-request';
export interface PersistRequestSchema {

}
export interface PersistResponseSchema {
    success: boolean,
    message?: string,
}

export interface OTPItemInfo {
    keyAlias: string,
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}
