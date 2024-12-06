import { fileIo as fs } from '@kit.CoreFileKit';
import { IconPackSchema, IconPackStore } from "./schema";
import { buffer } from '@kit.ArkTS';

interface IconFile {
    category?: string,
    filename: string,
}

type IssuerIconsMap = Map<string, IconFile[]>;
type PackIssuerIconsMap = Map<string, IssuerIconsMap>;

const ConstKeywords = [
    'books', 'reader', 'reading', 'library', //Books.svg
    'chat', 'talk', 'forum', 'message', 'social', //Chat.svg
    'cloud', 'server', //Cloud.svg
    'domain', 'internet', 'dns', 'network', //Domain.svg
    'education', 'student', 'learning', 'school', 'college', 'university', //Education.svg
    'gallery', 'photography', 'photos', 'pictures', 'camera', //Gallery.svg
    'gaming', 'game', //Gaming.svg
    'key', 'security', 'login', 'password', 'encryption', //Key.svg
    'mail', 'email', //Mail.svg
    'user', 'profile', 'personal', //User.svg
];

export class IconManager {
    private readonly _icons: IconPackStore[];
    private map: PackIssuerIconsMap = new Map();

    constructor(icons: IconPackStore[]) {
        this._icons = icons;
    }

    private async load(pack: IconPackStore, sync: boolean = false) {
        // load `pack.json`
        const manifestFile = `${pack.uri}/pack.json`;
        const arrayBuffer = new ArrayBuffer(1*1024*1024); //1MB
        const tempPackFile = sync? fs.openSync(manifestFile) : await fs.open(manifestFile);
        const readLen = sync? fs.readSync(tempPackFile.fd, arrayBuffer) : await fs.read(tempPackFile.fd, arrayBuffer);
        const iconPack: IconPackSchema =JSON.parse( buffer.from(arrayBuffer, 0, readLen).toString() );
        // convert into `IssuerIconsMap`
        const subMap: IssuerIconsMap = new Map();
        for (const icon of iconPack.icons) {
            for (const _issuer of icon.issuer) {
                const issuer = _issuer.toLowerCase();
                const iconFile: IconFile = {category: icon.category, filename: icon.filename};
                if (subMap.has(issuer)) {
                    subMap.get(issuer)!.push(iconFile);
                } else {
                    subMap.set(issuer, [iconFile]);
                }
            }
        }
        // insert into map
        this.map.set(iconPack.uuid, subMap);
    }

    private async loadAll(sync: boolean=false) {
        for (const pack of this._icons) {
            if (!this.map.has(pack.uuid)) {
                sync ? this.load(pack, true) : await this.load(pack);
            }
        }
    }

    private loadAllSync() { this.loadAll(true); }

    get icons() {
        return this._icons;
    }

    async appendPack(pack: IconPackStore) {
        await this.load(pack);
        this._icons.push(pack);
    }

    removePack(uuid: string) {
        const idx = this._icons.findIndex(x => x.uuid===uuid);
        idx>=0 && this._icons.splice(idx, 1);
        this.map.delete(uuid);
    }

    setDefaultIconPack(uuid: string): boolean {
        const packIdx = this._icons.findIndex(x => x.uuid===uuid);
        const prevDefault = this._icons.findIndex(x => x.isDefault);

        if (packIdx<0 || prevDefault<0) { return false; }

        if (packIdx===prevDefault) {
            return false;
        } else {
            this._icons[prevDefault].isDefault = false;
            this._icons[packIdx].isDefault = true;
            return true;
        }
    }

    async match(issuer: string, uuid?: string): Promise<string> {
        uuid = uuid ?? this._icons.find(x => x.isDefault)?.uuid;
        if (uuid && !this.map.has(uuid)) {
            const pack = this._icons.find(x => x.uuid===uuid);
            await this.load(pack!);
        }

        const rootUri = this._icons.find(x => x.uuid===uuid)?.uri;
        const subMap = uuid? this.map.get(uuid) : undefined;
        const key = issuer.toLowerCase().replace(/(\.org|\.com)$/, '');
        // 1. return exact match
        if (rootUri && subMap?.has(key)) {
            return rootUri+'/'+subMap.get(key)![0].filename;
        }
        // 2. return embedded match
        const resDir = getContext().resourceDir;
        const resFile = `${resDir}/icons/issuers/${key}.svg`;
        if (await fs.access(resFile)) {
            return resFile;
        }
        // 3. return generic keyword match
        for (const keyword of ConstKeywords) {
            if (key.includes(keyword) && rootUri && subMap?.has(keyword)) {
                return rootUri+'/'+subMap.get(keyword)![0].filename;
            }
        }
        // 4. return empty string
        return '';
    }

    matchAllSync(issuer: string): Map<ResourceStr,string> {
        this.loadAllSync();

        const key = issuer.toLowerCase().replace(/(\.org|\.com)$/, '');
        const results: Map<ResourceStr, string> = new Map();
        // 1. append exact matches or generic keyword matches
        for (const uuid of this.map.keys()) {
            const iconPack = this._icons.find(x => x.uuid===uuid)!;
            const rootUri = iconPack.uri + '/';
            const subMap = this.map.get(uuid)!;
            for (const keyword of [key].concat(ConstKeywords)) {
                if (key.includes(keyword) && subMap.has(keyword)) {
                    const files = subMap.get(keyword)!;
                    for (const file of files) {
                        const stem = file.filename.split('/').slice(-1)[0];
                        const entry = [iconPack.name, stem].join(' ▸ ');
                        results.set(entry, rootUri + file.filename);
                    }
                }
            }
        }
        // 2. append embedded match
        const resDir = getContext().resourceDir;
        const resFile = `${resDir}/icons/issuers/${key}.svg`;
        if (fs.accessSync(resFile)) {
            results.set($r('app.string.edit_icon_embedded'), resFile);
        }
        // 3. append `IssuerIcon`
        results.set($r('app.string.edit_icon_default'), '');
        return results;
    }

    static validateUri(uri: string): string {
        const resDir = getContext().resourceDir;
        const isAbsPath = uri.startsWith('/data/storage');

        uri = uri.trim();
        if (uri==='') {
            return '';
        } else if (isAbsPath && fs.accessSync(uri)) {
            return 'file://'+uri;
        } else if (!isAbsPath && fs.accessSync(resDir+'/'+uri)) {
            return 'file://'+resDir+'/'+uri;
        } else {
            return '';
        }
    }
}
