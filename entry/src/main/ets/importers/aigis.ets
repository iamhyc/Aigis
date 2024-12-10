import { buffer, util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ImporterBehavior } from ".";
import { AesGcmMaterial, AigisContentSchema,
    ImporterSchema,
    MasterKeyInfo,
    OTPItemInfo,
    SecretSchema} from '../common/schema';
import { formatDateString, stringToUint8Array, Uint8ArrayToString } from '../common/utils';
import { generateMasterKeyInHUKSV1, generateMasterKeyInHUKSV2 } from '../crypto/authUtils';
import { AES_KEY_USAGE, generateAesGcmMaterial, HUKSAgent, PARAMS_DERIVE_SRC_KEY } from '../crypto/huksUtils';

interface AigisExportFormat {
    keyParams: AesGcmMaterial,
    masterKey: MasterKeyInfo,
    settings: string, //Base64String
    items: string, //OTPItemInfo[],
    secrets: string, //SecretSchema[],
}

export class AigisImporter implements ImporterBehavior {
    schema: ImporterSchema = {
        type: 'aigis',
        name: $r('app.string.importer_aigis_name'),
        description: $r('app.string.importer_aigis_desc'),
        format: ['.json'],
        import_password_required: true,
        export_password_required: false,
        export_filename: `aigis-export-${formatDateString()}.json`,
    };

    async save(fd: number, masterKeyAlias: string, content: AigisContentSchema): Promise<boolean> {
        try {
            const b64 = new util.Base64Helper();
            const settings = Uint8ArrayToString(await b64.encode( stringToUint8Array(content.settings ?? '[]') ));
            //
            const keyParams: AesGcmMaterial = await generateAesGcmMaterial();
            const items = Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmEncryption(masterKeyAlias, keyParams,
                stringToUint8Array(JSON.stringify(content.items))))!
            );
            const secrets = Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmEncryption(masterKeyAlias, keyParams,
                  stringToUint8Array(JSON.stringify(content.secrets))))!
            );
            const masterKey = content.masterKey;
            const exported: AigisExportFormat = {
                keyParams, masterKey, settings, items, secrets
            };
            //
            await fs.write(fd, JSON.stringify(exported));
            return true;
        } catch (err) {
            return false;
        }
    }

    async load(fd: number, password: string): Promise<AigisContentSchema> {
        const arrayBuffer = new ArrayBuffer(1*1024*1024);//1MB
        const readLen = await fs.read(fd, arrayBuffer);
        const exported: AigisExportFormat = JSON.parse( buffer.from(arrayBuffer, 0, readLen).toString() );

        const decKeyAlias = 'tmp-key';
        try {
            const masterKey = exported.masterKey;
            switch (masterKey.version) {
                case 'v2':
                    await generateMasterKeyInHUKSV2(decKeyAlias, password, AES_KEY_USAGE.DECRYPT, undefined, masterKey.secret);
                    break;
                case 'v1':
                    await generateMasterKeyInHUKSV1(decKeyAlias, password, AES_KEY_USAGE.DECRYPT, undefined, masterKey.secret, masterKey.params);
                    break;
                default:
                    throw Error('Not supported Master Key.')
            }
            //
            const keyParms = exported.keyParams;
            const items: OTPItemInfo[] = JSON.parse(Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmDecryption(decKeyAlias, keyParms, stringToUint8Array(exported.items)))!
            ));
            const secrets: SecretSchema[] = JSON.parse(Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmDecryption(decKeyAlias, keyParms, stringToUint8Array(exported.secrets)))!
            ))
            // decrypt secrets
            for (const secret of secrets) {
                if (secret.encrypted) {
                    const _secret = await HUKSAgent.applyAesGcmDecryption(decKeyAlias, secret.encrypted, stringToUint8Array(secret.secret));
                    secret.secret = Uint8ArrayToString(_secret!);
                    secret.encrypted = undefined;
                }
            }
            //
            const b64 = new util.Base64Helper();
            const settings = Uint8ArrayToString(await b64.decode(exported.settings));
            return { masterKey, settings, items, secrets };
        } catch (error) {
            throw new Error("decryption failure.");
        } finally {
            HUKSAgent.deleteKeyItem(decKeyAlias, PARAMS_DERIVE_SRC_KEY);
        }
    }
}
