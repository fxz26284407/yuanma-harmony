import { huks } from '@kit.UniversalKeystoreKit';
import native from 'libcodexnoise.so';

export class HuksSigner {
  private alias: string = 'codex-mobile-device-signing-v1';
  private properties(purpose: number): huks.HuksParam[] {
    return [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_ECC },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_ECC_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_DIGEST, value: huks.HuksKeyDigest.HUKS_DIGEST_SHA256 }
    ];
  }
  async ensureKey(): Promise<void> {
    if (!await huks.hasKeyItem(this.alias, { properties: [] })) {
      await huks.generateKeyItem(this.alias, { properties: this.properties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_SIGN | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_VERIFY) });
    }
  }
  async publicKey(): Promise<ArrayBuffer> {
    await this.ensureKey(); const result = await huks.exportKeyItem(this.alias, { properties: [] });
    if (result.outData === undefined) { throw new Error('HUKS 公钥导出失败'); }
    return native.publicSpki(result.outData.slice().buffer as ArrayBuffer);
  }
  async signChallenge(bytes: Uint8Array): Promise<ArrayBuffer> {
    if (bytes.length === 0 || bytes.length > 4096) { throw new Error('身份挑战长度无效'); }
    await this.ensureKey();
    const options: huks.HuksOptions = { properties: this.properties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_SIGN), inData: bytes };
    const session = await huks.initSession(this.alias, options);
    try {
      const result = await huks.finishSession(session.handle, options);
      if (result.outData === undefined) { throw new Error('HUKS 签名失败'); }
      return native.signatureP1363(result.outData.slice().buffer as ArrayBuffer);
    } catch (error) {
      try { await huks.abortSession(session.handle, { properties: [] }); } catch (_) { }
      throw (error as Error);
    }
  }
}
