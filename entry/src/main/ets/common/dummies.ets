import { TimedOTPSchema } from "../crypto/otpUtils";
import { FAKE_OTP_CODE } from "./conts";
import { OTPItemInfo } from "./schema";

export const DummyOTPItemInfo: OTPItemInfo = {
    keyAlias: '',
    icon: '',
    code: { timestamp: 0, code: FAKE_OTP_CODE },
    schema: {
        type: 'totp',
        name: 'Dummy',
        period: 30,
        issuer: 'Aigis',
        algorithm: 'SHA256',
        digits: 6,
        counter: 0,
    } as TimedOTPSchema
}