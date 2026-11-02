import { util } from '@kit.ArkTS';
export function encode(value: ArrayBuffer): string {
  return new util.Base64Helper().encodeToStringSync(new Uint8Array(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
export function decode(value: string): ArrayBuffer {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) { throw new Error('密钥编码无效'); }
  let input: string = value.replace(/-/g, '+').replace(/_/g, '/');
  while (input.length % 4 !== 0) { input += '='; }
  const bytes = new util.Base64Helper().decodeSync(input);
  const result = bytes.slice().buffer as ArrayBuffer;
  if (encode(result) !== value) { throw new Error('密钥编码不是规范形式'); }
  return result;
}
export function utf8(value: string): ArrayBuffer {
  return new util.TextEncoder().encodeInto(value).slice().buffer as ArrayBuffer;
}
export function stringOf(value: ArrayBuffer): string {
  return new util.TextDecoder('utf-8', { fatal: true }).decodeToString(new Uint8Array(value));
}
export function hex(value: ArrayBuffer): string {
  let result: string = '';
  new Uint8Array(value).forEach((b: number) => { result += b.toString(16).padStart(2, '0'); });
  return result;
}
