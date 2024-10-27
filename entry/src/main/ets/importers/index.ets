import { AigisContentSchema } from '../common/schema';

export abstract class ImporterClass {
    constructor() {}
    abstract load(fd: number, password?: string): Promise<AigisContentSchema>;
    abstract save(fd: number, masterKeyAlias: string, content: AigisContentSchema): Promise<boolean>;
}
