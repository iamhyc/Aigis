
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

// Reference: https://github.com/bevacqua/fuzzysearch/blob/master/index.js
// Reference: https://github.com/helyo-world/fuzzysearch-ts/blob/master/index.ts
export function fuzzysearch (needle: string, haystack: string) {
	const hlen = haystack.length;
	const nlen = needle.length;
	if (nlen > hlen) {
		return false;
	}
	if (nlen === hlen) {
		return needle === haystack;
	}
	outer: for (let i = 0, j = 0; i < nlen; i++) {
		const nch = needle.charCodeAt(i);
		while (j < hlen) {
			if (haystack.charCodeAt(j++) === nch) {
				continue outer;
			}
		}
		return false;
	}
	return true;
}

export function arrayRearrange<T>(array: T[], prevIndex: number, newIndex: number) {
    const stepper = prevIndex<newIndex? +1 : -1;
    while (prevIndex!=newIndex) {
        let tmp = array[ prevIndex+stepper ]
        array[ prevIndex+stepper ] = array[ prevIndex ]
        array[ prevIndex ] = tmp;
        //
        prevIndex += stepper;
    }
}

export function getRandomInt(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function stringToUint8Array(str: string): Uint8Array {
    return Uint8Array.from(Array.from(str).map(x => x.charCodeAt(0)));
}

export function Uint8ArrayToString(array: Uint8Array): string {
    return Array.from(array).map(x => String.fromCharCode(x)).join('');
}

export function b32decode(input: string): Uint8Array {
    input = input.toUpperCase().replace(/\s|=/g, '');

    const dic = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    const length = input.length;
    const output = new Uint8Array(length * 5 / 8);

    let value = 0;
    let index = 0;
    let offset = 0;

    for (let i = 0; i < length; i++) {
        value = (value << 5) | dic.indexOf(input[i]);
        offset += 5;

        if (offset >= 8) {
            output[index++] = (value >>> (offset - 8)) & 255;
            offset -= 8;
        }
    }

    return output;
}

export function isValidBase32String(str: string): boolean {
    const base32Regex = /^[A-Z2-7]+=*$/;
    return base32Regex.test(str);
}

export function isValidBase64String(str: string): boolean {
    const base64Regex = /^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/;
    return base64Regex.test(str);
}
