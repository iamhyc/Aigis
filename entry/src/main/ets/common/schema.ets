import { OTPSchema } from "../crypto/otpUtils";

export const EVENT_CODE_REQUEST: string = 'code-request';
export interface CodeRequestSchema {
    issuer: string,
    name: string,
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

export interface OTPItemInfo {
    icon: string,
    code: CodeResponseSchema,
    schema: OTPSchema,
}
