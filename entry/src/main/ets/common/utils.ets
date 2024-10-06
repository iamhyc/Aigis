
interface IssuerName {
    issuer: string,
    name: string
}

export function name2keyAlias(props: IssuerName): string {
    return `${props.issuer}:${props.name}`;
}

export function shallowCopy(obj: object): object {
    let newObj: Record<string, Object> = {};
    for (let key of Object.keys(obj)) {
        newObj[key] = obj[key];
    }
    return newObj;
}

export function deepCopy(obj: object): object {
    let newObj: Record<string, Object> | Object[] = Array.isArray(obj) ? [] : {};
    for (let key of Object.keys(obj)) {
        if (typeof obj[key] === 'object') {
            newObj[key] = deepCopy(obj[key]);
        } else {
            newObj[key] = obj[key];
        }
    }
    return newObj;
}

export function splitOnce(text:string, sep: string): [string, string] {
    const index = text.indexOf(sep);
    if (index === -1) {
        return [text, ''];
    }
    return [text.slice(0, index), text.slice(index + 1)];
}
