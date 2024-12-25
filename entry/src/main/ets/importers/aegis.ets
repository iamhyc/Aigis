import { ImporterBehavior } from '.';
import { AigisContentSchema, ImporterSchema, MasterKeyInfo, OTPItemInfo, SecretSchema } from '../common/schema';
import { formatDateString, stringToUint8Array, Uint8ArrayToString } from '../common/utils';
import { generateRandomAad32, generateRandomNonce12 } from '../crypto/huksUtils';
import { AlgorithmSupport, OtpSchemaSupport, TimedOTPSchema } from '../crypto/otpUtils'
import { scryptKeyDerive, ScryptMaterial } from 'scrypt';
import { buffer, taskpool, util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { FAKE_OTP_CODE } from '../common/conts';

interface KeyParams {
    nonce: string,
    tag: string,
}

interface CommonSlotSchema {
    type: number,
    uuid: string,
    key: string,
    key_params: KeyParams,
}

interface ScryptSlotSchema extends CommonSlotSchema {
    type: 1,
    n: number, r: number, p: number,
    salt: string,
    repaired?: boolean,
    is_backup?: boolean,
}

interface ItemEntryInfoSchema {
    secret: string,
    algo: AlgorithmSupport,
    digits: number,
    period: number,
}

interface ItemEntrySchema {
    uuid: string,
    favorite?: boolean,
    type: OtpSchemaSupport,
    name: string,
    issuer: string,
    info: ItemEntryInfoSchema,
    note?: string,
    groups?: string[],
    //
    icon?: string,
    icon_mime?: string,
    icon_hash?: string,
}

interface AegisDBSchema {
    version: 3,
    entries: ItemEntrySchema[],
    groups: string[],
}

interface AegisExportHeaderSchema {
    slots?: CommonSlotSchema[],
    params?: KeyParams,
}

interface AegisExportSchema {
    version: 1,
    header: AegisExportHeaderSchema,
    db: AegisDBSchema | string,
}

function hexToUint8Array(hex: string): Uint8Array {
    if (hex.length % 2 !== 0) {
        hex = '0' + hex;
    }

    const uint8Array = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
        uint8Array[i / 2] = parseInt(hex.substr(i, 2), 16);
    }

    return uint8Array;
}

function uint8ArrayToHex(uint8Array: Uint8Array): string {
    return Array.from(uint8Array)
        .map(byte => byte.toString(16).padStart(2, '0'))
        .join('');
}

@Concurrent
async function scryptKeyDeriveWrapper(password: string, material: ScryptMaterial): Promise<Uint8Array> {
    return await scryptKeyDerive(password, material);
}

async function callScryptKeyDerive(password: string, material: ScryptMaterial): Promise<Uint8Array> {
    const task = new taskpool.Task(scryptKeyDeriveWrapper, password, material);
    const result: Uint8Array = await taskpool.execute(task, taskpool.Priority.HIGH) as Uint8Array;
    return result;
}

export class AegisImporter implements ImporterBehavior {
    schema: ImporterSchema = {
        type: 'aegis',
        name: $r('app.string.importer_aegis_name'),
        description: $r('app.string.importer_aegis_desc'),
        format: ['.json'],
        import_password_required: false,
        export_password_required: true,
        export_filename: `aegis-backup-${formatDateString()}.json`,
    };

    async load(fd: number, password?: string): Promise<AigisContentSchema | undefined> {
        const arrayBuffer = new ArrayBuffer(1*1024*1024);//1MB
        const readLen = await fs.read(fd, arrayBuffer);
        const exported: AegisExportSchema = JSON.parse( buffer.from(arrayBuffer, 0, readLen).toString() );
        // decrypt Aegis DB
        if (typeof exported.db === 'string') {
            const dec_db = await this.decryptAegisDB(exported.db, password??'', exported.header);
            if (dec_db) {
                exported.db = dec_db;
            } else {
                return undefined;
            }
        }
        // convert to AigisContentSchema
        const masterKey: MasterKeyInfo = {
            type: 'PBKDF2', version: 'v1', keyAlias: 'dummy',
            secret: { salt: '', iteration: 0 },
            params: { salt: '', iteration: 0 },
        };
        const items: OTPItemInfo[] = [];
        const secrets: SecretSchema[] = [];
        for (const item of exported.db.entries) {
            items.push({
                uuid: item.uuid, keyAlias: item.uuid, icon: '',
                favorite: item.favorite,
                code: { timestamp:0, code: FAKE_OTP_CODE }, //FIXME: remove later
                schema: {
                    type: item.type, issuer: item.issuer, name: item.name,
                    algorithm: item.info.algo,
                    digits: item.info.digits,
                    groups: item.groups,
                    note: item.note,
                    period: item.info.period,
                } as TimedOTPSchema
            });
            secrets.push({ keyAlias: item.uuid, secret: item.info.secret });
        }
        // return
        return { masterKey, items, secrets };
    }

    async save(fd: number, password: string, content: AigisContentSchema): Promise<boolean> {
        // convert to AegisDBSchema
        const entries: ItemEntrySchema[] = [];
        for (let i = 0; i < content.items.length; i++) {
            const item = content.items[i];
            const secret = content.secrets[i];
            entries.push({
                uuid: util.generateRandomUUID(),
                favorite: item.favorite,
                type: item.schema.type,
                name: item.schema.name,
                issuer: item.schema.issuer,
                note: item.schema.note,
                groups: item.schema.groups,
                info: {
                    secret: secret.secret,
                    algo: item.schema.algorithm,
                    digits: item.schema.digits,
                    period: (item.schema as TimedOTPSchema).period,
                },
            });
        }
        //
        const export_db: AegisDBSchema = {
            version: 3, entries, groups: []
        };
        const exported = this.encryptAegisDB(password, export_db);
        try {
            await fs.write(fd, JSON.stringify(exported));
            return true;
        } catch (e) {
            return false;
        }
    }

    private async genSymKeyByData(symKeyData: Uint8Array) {
        let symKeyBlob: cryptoFramework.DataBlob = { data: symKeyData };
        let aesGenerator = cryptoFramework.createSymKeyGenerator('AES256');
        let symKey = await aesGenerator.convertKey(symKeyBlob);
        return symKey;
    }

    private async applyAESGCMEncryption(symKeyData: Uint8Array, nonce: Uint8Array, plaintext: Uint8Array): Promise<[Uint8Array, Uint8Array]> {
        const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
        const symKey = await this.genSymKeyByData(symKeyData);
        await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, {
            algName: 'GcmParamsSpec',
            iv: { data: nonce },
            authTag: { data: new Uint8Array(16) },
        } as cryptoFramework.GcmParamsSpec);
        //
        const encryptUpdate = await cipher.update({data: plaintext});
        const authTag = await cipher.doFinal(null);
        return [encryptUpdate.data, authTag.data];
    }

    private async applyAESGCMDecryption(symKeyData: Uint8Array, params: KeyParams, cipherText: Uint8Array): Promise<Uint8Array> {
        const decoder = cryptoFramework.createCipher('AES256|GCM|NoPadding');
        const symKey = await this.genSymKeyByData(symKeyData);
        await decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, {
            algName: 'GcmParamsSpec',
            iv: { data: hexToUint8Array(params.nonce) },
            authTag: { data: hexToUint8Array(params.tag) },
        } as cryptoFramework.GcmParamsSpec);
        //
        const decryptUpdate = await decoder.update({data: cipherText});
        await decoder.doFinal(null);
        return decryptUpdate.data;
    }

    private async decryptAegisDB(cipherText: string, password: string, header: AegisExportHeaderSchema): Promise<AegisDBSchema | undefined> {
        if (header.slots===undefined || header.params===undefined) { return undefined; }

        // decrypt master key with slot key
        let master_key: Uint8Array | undefined;
        for (const slot of header.slots) {
            if (slot.type!==1) { continue; }
            const scrypt = slot as ScryptSlotSchema;
            const salt = hexToUint8Array(scrypt.salt);
            const material: ScryptMaterial = { N:scrypt.n, r:scrypt.r, p:scrypt.p, salt, length:32 };
            const key: Uint8Array = await callScryptKeyDerive(password, material);
            //
            try {
                const slotKey = hexToUint8Array(slot.key);
                master_key = await this.applyAESGCMDecryption(key, slot.key_params, slotKey);
                break;
            } catch (e) {
                continue;
            }
        }
        if (master_key===undefined) { return undefined; }

        // decrypt DB content with master key
        const b64 = new util.Base64Helper();
        const encryptedDB = await b64.decode( stringToUint8Array(cipherText) );
        const dbContent = await this.applyAESGCMDecryption(master_key, header.params, encryptedDB);
        return JSON.parse( Uint8ArrayToString(dbContent) ) as AegisDBSchema;
    }

    private async encryptAegisDB(password: string, db: AegisDBSchema): Promise<AegisExportSchema> {
        const salt = await generateRandomAad32();
        const material: ScryptMaterial = { N:32768, r:8, p:1, salt, length:32 };
        const key: Uint8Array = await callScryptKeyDerive(password, material);

        // derive master key
        const master_key = await generateRandomAad32(); //for 256-bit AES key

        // encrypt DB with master_key
        const b64 = new util.Base64Helper();
        const db_content = stringToUint8Array( JSON.stringify(db) );
        const header_nonce = await generateRandomNonce12();
        const enc_db_result = await this.applyAESGCMEncryption(master_key, header_nonce, db_content);
        const enc_db_content = Uint8ArrayToString(await b64.encode(enc_db_result[0]));
        const header_tag = enc_db_result[1];

        // encrypt master key
        const slot_nonce = await generateRandomNonce12();
        const enc_master_key_result = await this.applyAESGCMEncryption(key, slot_nonce, master_key);
        const enc_master_key = enc_master_key_result[0];
        const slot_tag = enc_master_key_result[1];

        return {
            version: 1,
            header: {
                slots: [{
                    type: 1,
                    uuid: util.generateRandomUUID(),
                    key: uint8ArrayToHex(enc_master_key),
                    key_params: {
                        nonce: uint8ArrayToHex(slot_nonce),
                        tag: uint8ArrayToHex(slot_tag),
                    },
                    n: material.N, r: material.r, p: material.p,
                    salt: uint8ArrayToHex(salt),
                    repaired: false, is_backup: false,
                } as ScryptSlotSchema],
                params: {
                    nonce: uint8ArrayToHex(header_nonce),
                    tag: uint8ArrayToHex(header_tag),
                }
            },
            db: enc_db_content,
        };
    }
}
