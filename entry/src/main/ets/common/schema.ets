import { OTPSchema } from "../crypto/otpUtils";
import { fuzzysearch } from "./utils";

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

export interface OTPItemInfo {
    keyAlias: string,
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}
