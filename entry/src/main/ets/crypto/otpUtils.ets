import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { name2keyAlias, shallowCopy, splitOnce } from '../common/utils';

type AlgorithmSupport = 'MD5' | 'SHA1' | 'SHA256' | 'SHA512';
type AlgorithmModern = 'SHA1' | 'SHA256' | 'SHA512';

export interface OTPSchema {
    type: string,
    name: string,
    issuer: string,
    secret?: string,
    algorithm: AlgorithmSupport,
    digits: number,
    counter: number,
}

export interface TimedOTPSchema extends OTPSchema {
    period: number,
}

export interface PinedOTPSchema extends OTPSchema {
    pid: string,
}

export interface HOTPSchema extends OTPSchema {
    type: 'hotp',
    algorithm: AlgorithmModern,
}

export interface TOTPSchema extends OTPSchema,TimedOTPSchema {
    type: 'totp',
    algorithm: AlgorithmModern,
}

interface MOTPSchema extends OTPSchema,TimedOTPSchema,PinedOTPSchema {
    type: 'motp',
    algorithm: 'MD5',
    period: 10,
    digits: 6,
}

interface YAOTPSchema extends OTPSchema,TimedOTPSchema,PinedOTPSchema {
    type: 'yandex',
    algorithm: 'SHA256',
    period: 30,
    digits: 8,
}

// http://tools.ietf.org/html/rfc4226#section-5.4
function rfc4226Sec5_4Impl(hash: Uint8Array): number {
    const offset = hash[hash.length - 1] & 0xf;
    const otp = ((hash[offset] & 0x7f) << 24)
        | ((hash[offset + 1] & 0xff) << 16)
        | ((hash[offset + 2] & 0xff) << 8)
        | (hash[offset + 3] & 0xff);
    return otp;
}

function numberToBigEndianByteArray(num: number, byteSize: number): Uint8Array {
    const byteArray = new Uint8Array(byteSize);
    for (let i = 0; i < byteSize; i++) {
        byteArray[byteSize - 1 - i] = num & 0xff;
        num = num >> 8;
    }
    return byteArray;
}

function b32decode(input: string): Uint8Array {
    input = input.toUpperCase().replace(/\s|=/g, '');

    const dic = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    const length = input.length;
    const output = new Uint8Array(length * 5 / 8);

    let value = 0;
    let index = 0;
    let offset = 0;

    for (let i = 0; i < length; i++) {
        value = (value << 5) | dic.indexOf(input[i]);
        offset += 5;

        if (offset >= 8) {
            output[index++] = (value >>> (offset - 8)) & 255;
            offset -= 8;
        }
    }

    return output;
}

export function parseURI(uri: string): Map<string, string> {
    const re = /otpauth:\/\/(\w+)\/([^\?]+)\?(.+)/;
    const results = re.exec(uri)!;
    const type = results[1], issuer_name = decodeURIComponent(results[2]), args = results[3];
    //
    const name = splitOnce(issuer_name, ':')[1];
    const args_array = args.split('&')
        .map(x => x.split('='))
        .map(x => [decodeURIComponent(x[0]), decodeURIComponent(x[1])])
        .concat([['type', type], ['name', name]]) as [string, string][];
    return new Map(args_array);
}

export abstract class OTP {
    protected readonly _schema: OTPSchema;

    constructor(schema: OTPSchema) {
        this._schema = schema;
    }

    abstract get uri(): string;
    abstract generateOTP(): Promise<string>;

    get schema() {
        const _leak_schema = shallowCopy(this._schema) as OTPSchema;
        _leak_schema.secret = undefined;
        return _leak_schema;
    }

    get keyAlias() {
        return name2keyAlias({issuer:this._schema.issuer, name:this._schema.name});
    }

    async generateHash(realCounter?: number): Promise<Uint8Array> {
        realCounter = realCounter ?? this._schema.counter;
        const counterBytes: Uint8Array = numberToBigEndianByteArray(realCounter, 8);

        const keyData = b32decode(this._schema.secret!);
        const symKey = await cryptoFramework.createSymKeyGenerator('HMAC').convertKey({data:keyData});

        const mac = cryptoFramework.createMac(this._schema.algorithm);
        await mac.init(symKey);

        await mac.update({data: counterBytes});
        const macResult = await mac.doFinal();
        return macResult.data;
    }

    otpToString(otp: number): string {
        const _digits = this._schema.digits;
        const code_num = otp % Math.pow(10, _digits);
        let code_str = code_num.toString();
        while (code_str.length < _digits) code_str = "0" + code_str;
        return code_str;
    }
}

export class HOTP extends OTP {
    constructor(hotpSchema: HOTPSchema) {
        super(hotpSchema);
    }

    static fromURI(uri: string): HOTP {
        const args = parseURI(uri);
        return HOTP.fromArguments(args)
    }

    static fromArguments(args: Map<string,string>): HOTP {
        if (args.get('algorithm') !== undefined) {
            const hotpSchema: HOTPSchema = {
                type: 'hotp',
                name: args.get('name') || '',
                issuer: args.get('issuer') || '',
                secret: args.get('secret') || '',
                algorithm: args.get('algorithm') as AlgorithmModern,
                digits: Number(args.get('digits') || 0),
                counter:Number(args.get('counter') || 0),
            }
            return new HOTP(hotpSchema);
        } else {
            throw Error('Fail to parse HOTP schema from URI.');
        }
    }

    get uri(): string {
        const s = this._schema as HOTPSchema;
        return encodeURI(`otpauth://${s.type}/${s.issuer}:${s.name}?algorithm=${s.algorithm}&counter=${s.counter}&digits=${s.digits}&issuer=${s.issuer}&secret=${s.secret}`);
    }

    async generateOTP(): Promise<string> {
        const hash = await this.generateHash();
        const otp = rfc4226Sec5_4Impl(hash);
        return this.otpToString(otp);
    }
}

export class TOTP extends OTP {
    constructor(totpSchema: TOTPSchema) {
        super(totpSchema);
    }

    static fromURI(uri: string): TOTP {
        const args = parseURI(uri);
        return TOTP.fromArguments(args);
    }

    static fromArguments(args: Map<string,string>) {
        if (args.get('algorithm') !== undefined) {
            const totpSchema: TOTPSchema = {
                type: 'totp',
                name: args.get('name') || '',
                issuer: args.get('issuer') || '',
                secret: args.get('secret') || '',
                algorithm: args.get('algorithm') as AlgorithmModern,
                period: Number(args.get('period') || 0),
                digits: Number(args.get('digits') || 0),
                counter: 0,
            };
            return new TOTP(totpSchema);
        } else {
            throw Error('Fail to parse TOTP schema from URI.');
        }
    }

    get uri(): string {
        const s = this._schema as TOTPSchema;
        return encodeURI(`otpauth://${s.type}/${s.issuer}:${s.name}?algorithm=${s.algorithm}&period=${s.period}&digits=${s.digits}&issuer=${s.issuer}&secret=${s.secret}`);
    }

    async generateOTP(): Promise<string> {
        const period = (this._schema as TOTPSchema).period;
        const realCounter = Math.floor(Date.now() / 1000 / period);
        //
        const hash = await this.generateHash(realCounter);
        const otp = rfc4226Sec5_4Impl(hash);
        return this.otpToString(otp);
    }
}
