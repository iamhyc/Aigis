
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

export function numberToBigEndianByteArray(num: number, byteSize: number): Uint8Array {
    const byteArray = new Uint8Array(byteSize);
    for (let i = 0; i < byteSize; i++) {
        byteArray[byteSize - 1 - i] = num & 0xff;
        num = num >> 8;
    }
    return byteArray;
}

export function bigEndianByteArrayToNumber(arr: Uint8Array): number {
    let result = 0;
    for (let i = 0; i < arr.length; i++) {
        result = (result << 8) | arr[i];
    }
    return result;
}

export function stringToUint8Array(str: string): Uint8Array {
    return Uint8Array.from(Array.from(str).map(x => x.charCodeAt(0)));
}

export function Uint8ArrayToString(array: Uint8Array): string {
    return Array.from(array).map(x => String.fromCharCode(x)).join('');
}

const B32_RFC4648_DICT = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

// Reference[RFC4648]: https://github.com/scttcper/ts-base32/blob/v4.0.0/src/index.ts#L7
export function b32encode(input: Uint8Array): string {
    const view = new Uint8Array(input);

    let bits = 0;
    let value = 0;
    let output = '';

    for (let i = 0; i < view.length; i++) {
        value = (value << 8) | view[i]!;
        bits += 8;

        while (bits >= 5) {
            output += B32_RFC4648_DICT.charAt( (value >>> (bits - 5)) & 31 );
            bits -= 5;
        }
    }

    if (bits > 0) {
        output += B32_RFC4648_DICT.charAt( (value << (5 - bits)) & 31 );
    }

    while (output.length % 8 !== 0) {
        output += '=';
    }
    return output;
}

// Reference[RFC4648]: https://github.com/scttcper/ts-base32/blob/v4.0.0/src/index.ts#L75
export function b32decode(input: string): Uint8Array {
    input = input.toUpperCase().replace(/\s|=/g, '');

    const length = input.length;
    const output = new Uint8Array(length * 5 / 8);

    let value = 0;
    let index = 0;
    let offset = 0;

    for (let i = 0; i < length; i++) {
        value = (value << 5) | B32_RFC4648_DICT.indexOf(input[i]);
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

export function formatDateString(timestamp?: number) {
    const date = timestamp? new Date(timestamp) : new Date();
    return date.toLocaleString('zh-CN', {hour12: false})
        .replace(/\/|:/g, '')
        .split(' ').join('-');
}
