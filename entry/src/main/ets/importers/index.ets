import { AigisContentSchema, ImporterSchema } from '../common/schema';
import { AigisImporter } from './aigis';

const aigisImporter = new AigisImporter();
export const ImporterSelections: Map<string, ImporterSchema> = new Map([
    [aigisImporter.schema.type, aigisImporter.schema],
]);

export interface ImporterBehavior {
    schema: ImporterSchema,
    load: (fd: number, password: string) => Promise<AigisContentSchema | undefined>,
    save: (fd: number, masterKeyAlias: string, content: AigisContentSchema) => Promise<boolean>,
}

export function dispatchImporter(type: string): ImporterBehavior | undefined {
    switch (type) {
        case 'aigis':
            return aigisImporter;
        default:
            return undefined;
    }
}

export { aigisImporter, AigisContentSchema, ImporterSchema };
