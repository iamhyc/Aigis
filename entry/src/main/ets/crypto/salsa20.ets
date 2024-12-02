// Reference: https://en.wikipedia.org/wiki/Salsa20

function ROTL(a: number, b: number): number {
    return (a << b) | (a >>> (32 - b));
}

function QR(X: Uint32Array, a: number, b: number, c: number, d: number) {
    X[b] ^= ROTL(X[a] + X[d], 7);
    X[c] ^= ROTL(X[b] + X[a], 9);
    X[d] ^= ROTL(X[c] + X[b], 13);
    X[a] ^= ROTL(X[d] + X[c], 18);
}

export function salsa20R8(X: Uint32Array) {
    const B = new Uint32Array(X);
    for (let i = 0; i < 8; i += 2) {
        QR(B, 0, 4, 8, 12);
        QR(B, 5, 9, 13, 1);
        QR(B, 10, 14, 2, 6);
        QR(B, 15, 3, 7, 11);
        //
        QR(B, 0, 1, 2, 3);
        QR(B, 5, 6, 7, 4);
        QR(B, 10, 11, 8, 9);
        QR(B, 15, 12, 13, 14);
    }
    for (let i = 0; i < X.length; i++) {
        X[i] += B[i];
    }
}
