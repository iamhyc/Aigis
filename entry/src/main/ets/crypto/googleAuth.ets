
// Reference: https://protobuf.dev/programming-guides/encoding/
import { b32encode, bigEndianByteArrayToNumber, Uint8ArrayToString } from "../common/utils";
import { AlgorithmSupport } from "./otpUtils";
import { util } from "@kit.ArkTS";

enum Algorithm {
    ALGORITHM_UNSPECIFIED = 0,
    ALGORITHM_SHA1 = 1,
    ALGORITHM_SHA256 = 2,
    ALGORITHM_SHA512 = 3,
    ALGORITHM_MD5 = 4,
}

enum DigitCount {
    DIGIT_COUNT_UNSPECIFIED = 0,
    DIGIT_COUNT_SIX = 1,
    DIGIT_COUNT_EIGHT = 2,
}

enum OtpType {
    OTP_TYPE_UNSPECIFIED = 0,
    OTP_TYPE_HOTP = 1,
    OTP_TYPE_TOTP = 2,
}

type Int64 = number;
type Int32 = number;
type OtpParameters = [
    _type: 'OtpParameters',
    secret: Uint8Array,
    name: string,
    issuer: string,
    algorithm: Algorithm,
    digits: DigitCount,
    type: OtpType,
    counter: Int64,
];
type MigrationPayload = [
    _type: 'MigrationPayload',
    otp_parameters: OtpParameters[],
    version: Int32,
    batch_size: Int32,
    batch_index: Int32,
    batch_id: Int32,
];

const MIGRATION_SCHEMA_HEADER = 'otpauth-migration://offline?data=';
const MSB_BIT = 0x80;

function algorithmEnumToString(algorithm: Algorithm): AlgorithmSupport {
    switch (algorithm) {
        case Algorithm.ALGORITHM_MD5:
            return 'MD5';
        case Algorithm.ALGORITHM_SHA1:
            return 'SHA1';
        case Algorithm.ALGORITHM_SHA512:
            return 'SHA512';
        case Algorithm.ALGORITHM_SHA256:
        case Algorithm.ALGORITHM_UNSPECIFIED:
        default:
            return 'SHA256';
    }
}

function genDummyOtpParameters(index: number = 0): OtpParameters {
    return [
        'OtpParameters',
        new Uint8Array(),// 1
        'User'+index.toString().padStart(4, '0'),//2
        'Server',// 3
        Algorithm.ALGORITHM_SHA1,//4
        DigitCount.DIGIT_COUNT_SIX,//5
        OtpType.OTP_TYPE_TOTP,//6
        0,//7
    ];
}

function genDummyMigrationPayload(): MigrationPayload {
    return [
        'MigrationPayload',
        [],//1
        1,//2
        1,//3
        0,//4
        0,//5
    ]
}

function getProtobufValueOffset(protobuf: Uint8Array, inital: number): number {
    let ptr = inital;
    while ((ptr<protobuf.length) && ((protobuf[ptr++] & MSB_BIT) !== 0)) {
        continue;
    }
    return ptr;
}

function decodeProtobuf<T extends MigrationPayload | OtpParameters>(protobuf: Uint8Array, dummy: T): T {
    let ptr = 0;

    while (ptr < protobuf.length) {
        // read tag
        const tag = protobuf[ptr++];
        const wireType = tag & 0x07;
        const fieldNumber = tag >> 3;
        // read value
        const endPtr = getProtobufValueOffset(protobuf, ptr);
        const slice = protobuf.slice(ptr, endPtr);
        const value = Uint8Array.from(slice).reverse().map(x => x & ~MSB_BIT);
        ptr = endPtr;

        switch (wireType) {
            case 0: // VARINT
                dummy[fieldNumber] = bigEndianByteArrayToNumber(value);
                break;
            case 2: // LEN
                const offset = bigEndianByteArrayToNumber(value);
                const slice  = protobuf.slice(ptr, ptr + offset);
                ptr += offset;
                //
                if (dummy[0] === 'MigrationPayload' && fieldNumber===1) {
                    const dummyParams = genDummyOtpParameters( dummy[1].length );
                    dummy[1].push( decodeProtobuf(slice, dummyParams) )
                } else {
                    if (dummy[0] === 'OtpParameters' && fieldNumber===1) {
                        dummy[1] = slice;
                    } else {
                        dummy[fieldNumber] = Uint8ArrayToString(slice);
                    }
                }
                break;
            default:
                break;
        }
    }

    return dummy;
}

function encodeMigrationPayload(payload: MigrationPayload): Uint8Array {
    throw new Error('Not implemented.');
}

export function decodeOtpauthMigrationLink(uri: string): string[] {
    if (!uri.startsWith(MIGRATION_SCHEMA_HEADER)) { return []; }

    const b64 = new util.Base64Helper();
    const payload = decodeURIComponent( uri.substring(MIGRATION_SCHEMA_HEADER.length) );
    const protobuf = b64.decodeSync(payload);;

    const dummyPayload = genDummyMigrationPayload();
    const decodedPayload = decodeProtobuf(protobuf, dummyPayload);
    const otp_parameters = decodedPayload[1] as OtpParameters[];

    const result: string[] = [];
    for (const param of otp_parameters) {
        const secret = b32encode(param[1]);
        const name = param[2];
        const issuer = param[3];
        const algorithm = algorithmEnumToString(param[4]);
        const digits = param[5]===DigitCount.DIGIT_COUNT_EIGHT? 8 : 6;
        const type = param[6]===OtpType.OTP_TYPE_HOTP?'hotp':'totp';
        const counter = param[7].toString();
        //
        const raw_uri = `otpauth://${type}/${issuer}:${name}?algorithm=${algorithm}&digits=${digits}&counter=${counter}&issuer=${issuer}&secret=${secret}`;
        const uri = encodeURI(raw_uri);
        result.push(uri);
    }
    return result;
}
