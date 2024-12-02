import { Uint8ArrayToString } from '../common/utils';
import { pbkdf2KeyDerive } from './authUtils';
import { salsa20R8 } from './salsa20';

export interface ScryptMaterial {
    salt: Uint8Array,
    length: number,
    n: number,
    r: number,
    p: number,
}

function Xor_Block32(X32: Uint32Array, b: Uint32Array) {
    for (let i = 0; i < X32.length; i++) {
        X32[i] ^= b[i];
    }
}

// Convert the last 16 words (64 bytes) of the block to a little-endian number
function Integerify32(block: Uint32Array): number {
    const slice = block.subarray(block.length-16, block.length);
    const dataView = new DataView(slice.buffer, slice.byteOffset, slice.byteLength);
    return dataView.getUint32(0, true);
}

function BlockMix32(Y: Uint32Array) {
    const r = Y.length / (2*16); // to (2*r) 16-word chunks
    const B = new Uint32Array(Y);

    let X = new Uint32Array( B.subarray(B.length-16, B.length) );
    for (let i = 0; i < 2 * r; i++) {
        const Bi = B.subarray(i*16, (i+1)*16);
        Xor_Block32(X, Bi);
        salsa20R8(X);
        if (i % 2 === 0) {
            Y.set(X, 8 * i);
        } else {
            Y.set(X, 16 * r + 8 * (i-1));
        }
    }
}

function ROMix(X32: Uint32Array, iterations: number) {
    const V: Array<Uint32Array> = new Array(iterations);
    //
    for (let i = 0; i < iterations; i++) {
        V[i] = new Uint32Array(X32);
        BlockMix32(X32);
    }
    //
    for (let _ = 0; _ < iterations; _++) {
        const j = Integerify32(X32) % iterations;
        Xor_Block32(X32, V[j]);
        BlockMix32(X32);
    }
}

export async function scryptKeyDerive(password: string, material: ScryptMaterial): Promise<Uint8Array> {
    const blockSize = 128 * material.r;
    const dkLen = blockSize * material.p;
    const salt = Uint8ArrayToString(material.salt);
    const dk = await pbkdf2KeyDerive(password, {salt, iteration:1}, dkLen*8);

    const exSalt = new Uint32Array(dkLen>>2);
    for (let i = 0; i < material.p; i++) { //TODO: ROMix could be paralleled
        const slice = dk.subarray(i*blockSize, (i+1)*blockSize);
        const B = new Uint32Array(slice.buffer, slice.byteOffset, slice.byteLength>>2);
        ROMix(B, material.n);
        exSalt.set(B, i * blockSize>>2);
    }

    const exSaltStr = Uint8ArrayToString(new Uint8Array(exSalt.buffer));
    const result = await pbkdf2KeyDerive(password, {salt:exSaltStr, iteration:1}, material.length*8);
    return result;
}
