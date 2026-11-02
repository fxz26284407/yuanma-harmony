export interface TransportKey { publicKey: ArrayBuffer; privateKey: ArrayBuffer; }
export interface SessionInfo { publicKey: ArrayBuffer; hash: ArrayBuffer; }
export const newKey: () => TransportKey;
export const create: (privateKey: ArrayBuffer, pinnedMacKey: ArrayBuffer) => number;
export const begin: (handle: number) => ArrayBuffer;
export const finish: (handle: number, message: ArrayBuffer) => SessionInfo;
export const encrypt: (handle: number, plaintext: ArrayBuffer) => ArrayBuffer[];
export const decrypt: (handle: number, ciphertext: ArrayBuffer) => ArrayBuffer | undefined;
export const close: (handle: number) => void;
export const publicSpki: (exportedPublicKey: ArrayBuffer) => ArrayBuffer;
export const signatureP1363: (signature: ArrayBuffer) => ArrayBuffer;
export const sha256: (data: ArrayBuffer) => ArrayBuffer;
