import { AigisContentSchema, ImporterSchema } from '../common/schema';
import { AegisImporter } from './aegis';
import { AigisImporter } from './aigis';

const aegisImporter = new AegisImporter();
const aigisImporter = new AigisImporter();
export const ImporterSelections: Map<string, ImporterSchema> = new Map([
    [aigisImporter.schema.type, aigisImporter.schema],
    //
    [aegisImporter.schema.type, aegisImporter.schema],
]);

export interface ImporterBehavior {
    schema: ImporterSchema,
    load: (fd: number, password: string) => Promise<AigisContentSchema | undefined>,
    save: (fd: number, masterKeyAlias: string, content: AigisContentSchema) => Promise<boolean>,
}

export function dispatchImporter(type: string): ImporterBehavior | undefined {
    switch (type) {
        case 'aegis':
            return aegisImporter;
        case 'aigis':
            return aigisImporter;
        default:
            return undefined;
    }
}

export { aegisImporter, aigisImporter, AigisContentSchema, ImporterSchema };
