import { huks } from '@kit.UniversalKeystoreKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import native from 'libcodexnoise.so';
import { encode, decode, utf8 } from './Bytes';

export interface TransportIdentity { publicKey: string; privateKey: ArrayBuffer; }
export interface WrappedIdentity { version: number; nonce: string; ciphertext: string; publicKey: string; }
export class Identity {
  private alias: string = 'codex-mobile-transport-wrap-v1';
  private store?: preferences.Preferences;
  async initialize(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: 'codex-mobile-identity' });
  }
  private params(purpose: number, nonce?: Uint8Array, tag?: Uint8Array, publicKey: string = ''): huks.HuksParam[] {
    const p: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose }
    ];
    if (nonce !== undefined) {
      p.push({ tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM });
      p.push({ tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE });
      p.push({ tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce });
      p.push({ tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new Uint8Array(utf8(`CodexMobileTransportIdentity/v1/${publicKey}`)) });
      if (tag !== undefined) { p.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag }); }
    }
    return p;
  }
  private async crypt(purpose: number, data: Uint8Array, nonce: Uint8Array, publicKey: string, tag?: Uint8Array): Promise<Uint8Array> {
    const options: huks.HuksOptions = { properties: this.params(purpose, nonce, tag, publicKey), inData: data };
    const session = await huks.initSession(this.alias, options);
    try {
      const result = await huks.finishSession(session.handle, options);
      if (result.outData === undefined) { throw new Error('HUKS 未返回密钥封装结果'); }
      return result.outData;
    } catch (error) {
      try { await huks.abortSession(session.handle, { properties: [] }); } catch (_) { }
      throw (error as Error);
    }
  }
  async transport(): Promise<TransportIdentity> {
    if (this.store === undefined) { throw new Error('身份存储尚未初始化'); }
    const wrapped: string = await this.store.get('transport', '') as string;
    const exists: boolean = await huks.hasKeyItem(this.alias, { properties: [] });
    if (wrapped.length > 0) {
      if (!exists) { throw new Error('设备封装密钥丢失，请显式重置身份并重新配对'); }
      const item = JSON.parse(wrapped) as WrappedIdentity;
      if (item.version !== 1 || typeof item.publicKey !== 'string' || decode(item.publicKey).byteLength !== 32) { throw new Error('设备身份版本不受支持'); }
      const ciphertext = new Uint8Array(decode(item.ciphertext));
      const nonce = new Uint8Array(decode(item.nonce));
      if (nonce.length !== 12 || ciphertext.length !== 48) { throw new Error('设备身份封装记录损坏'); }
      const plain = await this.crypt(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, ciphertext.slice(0, -16), nonce, item.publicKey, ciphertext.slice(-16));
      if (plain.length !== 32) { plain.fill(0); throw new Error('设备身份长度异常'); }
      const result: TransportIdentity = { publicKey: item.publicKey, privateKey: plain.slice().buffer as ArrayBuffer };
      plain.fill(0); return result;
    }
    if (!exists) { await huks.generateKeyItem(this.alias, { properties: this.params(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT) }); }
    const key = native.newKey();
    try {
      const nonce = cryptoFramework.createRandom().generateRandomSync(12).data;
      const encrypted = await this.crypt(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, new Uint8Array(key.privateKey), nonce, encode(key.publicKey));
      if (encrypted.length !== 48) { throw new Error('HUKS GCM 输出格式异常'); }
      const record: WrappedIdentity = { version: 1, publicKey: encode(key.publicKey), nonce: encode(nonce.slice().buffer as ArrayBuffer), ciphertext: encode(encrypted.slice().buffer as ArrayBuffer) };
      await this.store.put('transport', JSON.stringify(record)); await this.store.flush();
      return { publicKey: record.publicKey, privateKey: key.privateKey.slice(0) };
    } finally { new Uint8Array(key.privateKey).fill(0); }
  }
  async get(name: string): Promise<string> { if (this.store === undefined) { throw new Error('身份存储未初始化'); } return await this.store.get(name, '') as string; }
  async put(name: string, value: string): Promise<void> { if (this.store === undefined) { throw new Error('身份存储未初始化'); } await this.store.put(name, value); await this.store.flush(); }
}
