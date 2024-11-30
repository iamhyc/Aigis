import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { numberToBigEndianByteArray, shallowCopy, splitOnce } from '../common/utils';

export type OtpSchemaSupport = 'totp' | 'hotp' | 'steam';
export type AlgorithmSupport = 'MD5' | 'SHA1' | 'SHA256' | 'SHA512';
export type AlgorithmModern = 'SHA1' | 'SHA256' | 'SHA512';

export interface IssuerName {
    issuer: string,
    name: string
}

export interface OTPSchema {
    type: OtpSchemaSupport,
    name: string,
    issuer: string,
    secret?: string,
    algorithm: AlgorithmSupport,
    digits: number,
    counter: number,
    groups?: string[],
    note?: string,
}

export interface TimedOTPSchema extends OTPSchema {
    period: number,
}

export interface PinedOTPSchema extends OTPSchema {
    pin: string,
}

export interface HOTPSchema extends OTPSchema {
    type: 'hotp',
    algorithm: AlgorithmModern,
}

export interface TOTPSchema extends OTPSchema,TimedOTPSchema {
    type: 'totp',
    algorithm: AlgorithmModern,
}

export interface SteamSchema extends OTPSchema,TimedOTPSchema {
    type: 'steam',
    algorithm: 'SHA1',
    period: 30,
    digits: 5,
}

// interface MOTPSchema extends OTPSchema,TimedOTPSchema,PinedOTPSchema {
//     type: 'motp',
//     algorithm: 'MD5',
//     period: 10,
//     digits: 6,
// }
//
// interface YAOTPSchema extends OTPSchema,TimedOTPSchema,PinedOTPSchema {
//     type: 'yandex',
//     algorithm: 'SHA256',
//     period: 30,
//     digits: 8,
// }

// http://tools.ietf.org/html/rfc4226#section-5.4
function rfc4226Sec5_4Impl(hash: Uint8Array): number {
    const offset = hash[hash.length - 1] & 0xf;
    const otp = ((hash[offset] & 0x7f) << 24)
        | ((hash[offset + 1] & 0xff) << 16)
        | ((hash[offset + 2] & 0xff) << 8)
        | (hash[offset + 3] & 0xff);
    return otp;
}

export function issuerNameToString(props: IssuerName): string {
    return `${props.issuer}:${props.name}`;
}

export function parseURI(uri: string): Map<string, string> {
    const re = /otpauth:\/\/(\w+)\/([^\?]*)\?(.*)/;
    const results = re.exec(uri)!;
    const type = results[1], issuer_name = decodeURIComponent(results[2]), args = results[3];
    //
    const _split = splitOnce(issuer_name, ':');
    const name = _split[1]===''? _split[0] : _split[1]
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

    static fromArguments(args: Map<string,string>): OTP {
        const _type = args.get('type') as OtpSchemaSupport;
        switch (_type) {
            case 'hotp':
                return HOTP.fromArguments(args);
            case 'totp':
                return TOTP.fromArguments(args);
            case 'steam':
                return SteamOTP.fromArguments(args);
            default:
                throw Error(`Unsupported OTP Type "${_type}".`);;
        }
    }

    static fromSchema(schema: OTPSchema): OTP {
        switch (schema.type) {
            case 'hotp':
                return new HOTP(schema as HOTPSchema);
            case 'totp':
                return new TOTP(schema as TOTPSchema);
            case 'steam':
                return new SteamOTP(schema as SteamSchema);
            default:
                throw Error(`Unsupported OTP Type ${schema.type}.`);
        }
    }

    abstract get uri(): string;
    abstract generateOTP(secret: Uint8Array, next?: boolean): Promise<string>;

    get schema() {
        const _leak_schema = shallowCopy(this._schema) as OTPSchema;
        _leak_schema.secret = undefined;
        return _leak_schema;
    }

    get secret_leaked_schema() {
        const _leak_schema = shallowCopy(this._schema) as OTPSchema;
        return _leak_schema;
    }

    async generateHash(secret: Uint8Array, realCounter?: number): Promise<Uint8Array> {
        realCounter = realCounter ?? this._schema.counter;
        const counterBytes: Uint8Array = numberToBigEndianByteArray(realCounter, 8);

        const keyData = secret;
        const symKey = await cryptoFramework.createSymKeyGenerator('HMAC').convertKey({data:keyData});

        const mac = cryptoFramework.createMac(this._schema.algorithm);
        await mac.init(symKey);
        await mac.update({data: counterBytes});
        const macResult = await mac.doFinal();
        return macResult.data;
    }

    async generateHashWithSecret(secret: Uint8Array, realCounter?: number): Promise<Uint8Array> {
        realCounter = realCounter ?? this._schema.counter;
        const counterBytes: Uint8Array = numberToBigEndianByteArray(realCounter, 8);

        const symKey = await cryptoFramework.createSymKeyGenerator('HMAC').convertKey({data:secret});
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
                note: args.get('note') || undefined,
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

    async generateOTP(secret: Uint8Array): Promise<string> {
        const hash = await this.generateHash(secret);
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
        const totpSchema: TOTPSchema = {
            type: 'totp',
            name: args.get('name') ?? '',
            issuer: args.get('issuer') ?? '',
            secret: args.get('secret') ?? '',
            algorithm: (args.get('algorithm') ?? 'SHA1') as AlgorithmModern,
            period: Number(args.get('period') ?? 30),
            digits: Number(args.get('digits') ?? 6),
            counter: 0,
            note: args.get('note') || undefined,
        };
        return new TOTP(totpSchema);
    }

    get uri(): string {
        const s = this._schema as TOTPSchema;
        return encodeURI(`otpauth://${s.type}/${s.issuer}:${s.name}?algorithm=${s.algorithm}&period=${s.period}&digits=${s.digits}&issuer=${s.issuer}&secret=${s.secret}`);
    }

    async generateOTP(secret: Uint8Array, next?: boolean): Promise<string> {
        const period = (this._schema as TOTPSchema).period;
        const realCounter = Math.floor(Date.now() / 1000 / period) + (next?1:0);
        //
        const hash = await this.generateHash(secret, realCounter);
        const otp = rfc4226Sec5_4Impl(hash);
        return this.otpToString(otp);
    }
}

export class SteamOTP extends OTP {
    private STEAM_ALPHABET: string = "23456789BCDFGHJKMNPQRTVWXY";

    constructor(steamSchema: SteamSchema) {
        super(steamSchema);
    }

    static fromURI(uri: string): SteamOTP {
        const args = parseURI(uri);
        return SteamOTP.fromArguments(args);
    }

    static fromArguments(args: Map<string,string>) {
        const steamSchema: SteamSchema = {
            type: 'steam', algorithm: 'SHA1', period: 30, digits: 5,
            issuer: args.get('issuer') || 'Steam',
            name: args.get('name') || '',
            secret: args.get('secret') || '',
            counter: 0,
            note: args.get('note') || undefined,
        };
        return new SteamOTP(steamSchema);
    }

    get uri(): string {
        const s = this._schema as SteamSchema;
        return encodeURI(`otpauth://${s.type}/${s.issuer}:${s.name}?algorithm=${s.algorithm}&period=${s.period}&digits=${s.digits}&issuer=${s.issuer}&secret=${s.secret}`);
    }

    async generateOTP(secret: Uint8Array, next?: boolean): Promise<string> {
        const period = (this._schema as TOTPSchema).period;
        const realCounter = Math.floor(Date.now() / 1000 / period) + (next?1:0);
        //
        const hash = await this.generateHash(secret, realCounter);
        const otp = rfc4226Sec5_4Impl(hash);
        return this.otpToSteamString(otp);
    }

    private otpToSteamString(otp: number): string {
        let res: string = '';
        for (let i=0; i < this._schema.digits; i++) {
            const _index = otp % this.STEAM_ALPHABET.length;
            res += this.STEAM_ALPHABET[_index];
            otp = Math.floor(otp / this.STEAM_ALPHABET.length);
        }
        return res;
    }
}
