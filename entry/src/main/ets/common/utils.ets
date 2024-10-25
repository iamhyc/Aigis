
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
