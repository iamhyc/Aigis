import { buffer, util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ImporterClass } from ".";
import { AesGcmMaterial, AigisContentSchema,
    MasterKeyInfo,
    OTPItemInfo,
    SecretSchema} from '../common/schema';
import { stringToUint8Array, Uint8ArrayToString } from '../common/utils';
import { generateMasterKeyInHUKS } from '../crypto/authUtils';
import { AES_KEY_USAGE, generateRandomAad32, generateRandomNonce12, HUKSAgent,
    PARAMS_DERIVE_SRC_KEY } from '../crypto/huksUtils';

interface AigisExportFormat {
    keyParams: AesGcmMaterial,
    masterKey: MasterKeyInfo,
    settings: string, //Base64String
    items: string, //OTPItemInfo[],
    secrets: string, //SecretSchema[],
}

export class AigisImporter extends ImporterClass {
    constructor() { super(); }
    
    async save(fd: number, masterKeyAlias: string, content: AigisContentSchema): Promise<boolean> {
        try {
            const b64 = new util.Base64Helper();
            const settings = Uint8ArrayToString(await b64.encode( stringToUint8Array(content.settings ?? '[]') ));
            //
            const keyParams: AesGcmMaterial = {
                aad: Uint8ArrayToString(await generateRandomAad32()),
                nonce: Uint8ArrayToString(await generateRandomNonce12()),
            };
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
        const arrayBuffer = new ArrayBuffer(1024*1024);//1MB
        const readLen = await fs.read(fd, arrayBuffer);
        const exported: AigisExportFormat = JSON.parse( buffer.from(arrayBuffer, 0, readLen).toString() );

        const decKeyAlias = 'tmp-key';
        try {
            const masterKey = exported.masterKey;
            await generateMasterKeyInHUKS(decKeyAlias, password, AES_KEY_USAGE.DECRYPT, masterKey.secret, masterKey.params);
            //
            const keyParms = exported.keyParams;
            const items: OTPItemInfo[] = JSON.parse(Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmDecryption(decKeyAlias, keyParms, stringToUint8Array(exported.items)))!
            ));
            const secrets: SecretSchema[] = JSON.parse(Uint8ArrayToString(
              (await HUKSAgent.applyAesGcmDecryption(decKeyAlias, keyParms, stringToUint8Array(exported.secrets)))!
            ))
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
