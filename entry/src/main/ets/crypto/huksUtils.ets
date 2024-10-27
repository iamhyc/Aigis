import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { AesGcmMaterial, PBKDF2Material } from '../common/schema';
import { stringToUint8Array } from '../common/utils';
import { JSON } from '@kit.ArkTS';

export type PurposeParams = Array<huks.HuksParam>;

const PARAMS_AES_PARAMS: huks.HuksParam[] = [
    {tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES},
    {tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,  value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256},
    {tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,value: huks.HuksCipherMode.HUKS_MODE_GCM},
    {tag: huks.HuksTag.HUKS_TAG_PADDING,   value: huks.HuksKeyPadding.HUKS_PADDING_NONE},
    {tag: huks.HuksTag.HUKS_TAG_DIGEST,    value: huks.HuksKeyDigest.HUKS_DIGEST_NONE},
];
export const PARAMS_AES_ENCRYPT: PurposeParams = PARAMS_AES_PARAMS.concat([
    {tag: huks.HuksTag.HUKS_TAG_PURPOSE,   value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT},
]);
export const PARAMS_AES_DECRYPT: PurposeParams = PARAMS_AES_PARAMS.concat([
    {tag: huks.HuksTag.HUKS_TAG_PURPOSE,   value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT},
]);
export enum AES_KEY_USAGE {
    ENCRYPT,
    DECRYPT,
}

export const PARAMS_DERIVE_SRC_KEY: PurposeParams = [
    {tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES},
    {tag: huks.HuksTag.HUKS_TAG_PURPOSE,   value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DERIVE},
    {tag: huks.HuksTag.HUKS_TAG_DIGEST,    value: huks.HuksKeyDigest.HUKS_DIGEST_SHA256},
    {tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,  value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256},
];
export const PARAMS_KEY256_DERIVE: PurposeParams = [
    {tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_PBKDF2},
    {tag: huks.HuksTag.HUKS_TAG_PURPOSE,   value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DERIVE},
    {tag: huks.HuksTag.HUKS_TAG_DIGEST,    value: huks.HuksKeyDigest.HUKS_DIGEST_SHA256},
    {tag: huks.HuksTag.HUKS_TAG_DERIVE_KEY_SIZE, value: 32},//32Bytes=256Bits
];

export const PARAMS_IN_HUKS: PurposeParams = [{
    tag:   huks.HuksTag.HUKS_TAG_DERIVED_AGREED_KEY_STORAGE_FLAG,
    value: huks.HuksKeyStorageType.HUKS_STORAGE_ONLY_USED_IN_HUKS,
}];
export const PARAMS_EXPORT_ALL: PurposeParams = [{
    tag:   huks.HuksTag.HUKS_TAG_DERIVED_AGREED_KEY_STORAGE_FLAG,
    value: huks.HuksKeyStorageType.HUKS_STORAGE_KEY_EXPORT_ALLOWED,
}];

async function generateRandomNonce(length: number): Promise<Uint8Array> {
    const rand = cryptoFramework.createRandom();
    const data = await rand.generateRandom(length);
    return Uint8Array.from(
        Array.from(data.data)
            .map(x => (x % 36).toString(36))
            .map(x => x.charCodeAt(0))
    );
}

export async function generateRandomSalt24(): Promise<Uint8Array> {
    return generateRandomNonce(24);
}
export async function generateRandomNonce12(): Promise<Uint8Array> {
    return generateRandomNonce(12);
}
export async function generateRandomAad32(): Promise<Uint8Array> {
    return generateRandomNonce(32);
}

export class HUKSAgent {
    private props: Array<huks.HuksParam> = [];

    constructor(params?: Array<huks.HuksParam>) {
        if (params!==undefined) {
            this.props = this.props.concat(params);
        }
    };

    with(params: Array<huks.HuksParam>) {
        this.props = this.props.concat(params);
        return this;
    }

    withKeyAlias(keyAlias: string) {
        this.with([
            {tag: huks.HuksTag.HUKS_TAG_IS_KEY_ALIAS, value: true},
            {tag: huks.HuksTag.HUKS_TAG_KEY_ALIAS,    value: stringToUint8Array(keyAlias)}
        ])
        return this;
    }

    withPBKDF2Material(material: PBKDF2Material) {
        this.with([
            {tag: huks.HuksTag.HUKS_TAG_SALT,      value: stringToUint8Array(material.salt)},
            {tag: huks.HuksTag.HUKS_TAG_ITERATION, value: material.iteration},
        ]);
        return this;
    }

    withAesGcmMaterial(material: AesGcmMaterial) {
        this.with([
            {tag: huks.HuksTag.HUKS_TAG_NONCE,           value: stringToUint8Array(material.nonce)},
            {tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: stringToUint8Array(material.aad)},
        ]);
        return this;
    }

    static async generateKeyItem(keyAlias: string, params: PurposeParams, _exported: boolean = false): Promise<string|undefined> {
        const agent = new HUKSAgent(params).with(PARAMS_IN_HUKS);
        const huksOptions: huks.HuksOptions = {
            properties: agent.props,
            inData: new Uint8Array(new Array())
        };
        try {
            await huks.generateKeyItem(keyAlias, huksOptions);
            return keyAlias;
        } catch (err) {
            console.error( `generateKeyItem failed: ${JSON.stringify(err)}` );
            return undefined;
        }
    }

    static async importKeyItem(keyAlias: string, params: PurposeParams, plaintext: Uint8Array): Promise<string|undefined> {
        const agent = new HUKSAgent(params);
        const huksOptions: huks.HuksOptions = {
            properties: agent.props,
            inData: plaintext,
        };
        try {
            await huks.importKeyItem(keyAlias, huksOptions);
            return keyAlias;
        } catch (err) {
            console.error( `importKeyItem failed: ${JSON.stringify(err)}` );
            return undefined;
        }
    }

    static async deleteKeyItem(keyAlias: string, params: PurposeParams) {
        const agent = new HUKSAgent(params);
        const huksOptions: huks.HuksOptions = {
            properties: agent.props,
            inData: new Uint8Array(new Array())
        };
        await huks.deleteKeyItem(keyAlias, huksOptions);
    }

    static async deriveAesKeyItem(srcKeyAlias: string, purpose: AES_KEY_USAGE, password: string, material: PBKDF2Material, outKeyAlias: string): Promise<void> {
        // init
        const initAgent = new HUKSAgent(PARAMS_KEY256_DERIVE).withPBKDF2Material(material);
        const initOptions: huks.HuksOptions = {
            properties: initAgent.props,
            inData: new Uint8Array(new Array()),
        };
        const session = await huks.initSession(srcKeyAlias, initOptions);
        initOptions.inData = stringToUint8Array(password);
        await huks.updateSession(session.handle, initOptions);
        // finish
        const purposeParams = purpose===AES_KEY_USAGE.DECRYPT? PARAMS_AES_DECRYPT : PARAMS_AES_ENCRYPT;
        const finishAgent = new HUKSAgent(purposeParams).withKeyAlias(outKeyAlias).with(PARAMS_IN_HUKS);
        const finishOptions: huks.HuksOptions = {
            properties: finishAgent.props,
            inData: new Uint8Array(new Array()),
        }
        await huks.finishSession(session.handle, finishOptions);
    }

    static async applyAesGcmEncryption(keyAlias: string, material: AesGcmMaterial, inData: Uint8Array): Promise<Uint8Array|undefined> {
        const agent = new HUKSAgent(PARAMS_AES_ENCRYPT).withAesGcmMaterial(material);
        const huksOptions: huks.HuksOptions = {
            properties: agent.props,
            inData,
        };
        //
        const session = await huks.initSession(keyAlias, huksOptions);
        const result = await huks.finishSession(session.handle, huksOptions);
        return result.outData;
    }

    static async applyAesGcmDecryption(keyAlias: string, material: AesGcmMaterial, cipherData: Uint8Array): Promise<Uint8Array|undefined> {
        const agent = new HUKSAgent(PARAMS_AES_DECRYPT).withAesGcmMaterial(material);
        agent.with([{
            tag: huks.HuksTag.HUKS_TAG_AE_TAG,
            value: cipherData.slice(cipherData.length-16)
        }]);
        const huksOptions: huks.HuksOptions = {
            properties: agent.props,
            inData: cipherData.slice(0, cipherData.length-16),
        };
        //
        const session = await huks.initSession(keyAlias, huksOptions);
        const result = await huks.finishSession(session.handle, huksOptions);
        return result.outData;
    }
}
