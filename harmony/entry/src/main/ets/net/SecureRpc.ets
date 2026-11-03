import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { url } from '@kit.ArkTS';
import native from 'libcodexnoise.so';
import { encode, decode, utf8, stringOf, hex } from '../security/Bytes';
import { TransportIdentity } from '../security/Identity';

interface LinkReply { type: string; }
interface WireRequest { requestId: string; method: string; path: string; backend: string; body?: Object; authorization?: string; }
interface WireError { code: string; message: string; }
interface WireResponse<T> { requestId: string; data?: T; error?: WireError; }
export function linkError(message: string): Error { const error = new Error(message); error.name = 'LinkError'; return error; }
export class RemoteError extends Error {
  code: string;
  constructor(code: string, message: string) { super(`${code}: ${message}`); this.code = code; }
}
export function relayEndpoint(value?: string): string {
  let message: string = '二维码中的中继地址无效，请重新生成配对码';
  if (!value) { message = '缺少中继地址，请扫描 Mac 的新二维码更新连接'; }
  else {
    try {
      if (typeof value !== 'string' || value.length > 2048 || /[\s\u0000-\u001f\u007f]/.test(value)) { throw new Error('Invalid address'); }
      const endpoint = url.URL.parseURL(value);
      if ((endpoint.protocol !== 'ws:' && endpoint.protocol !== 'wss:') || !endpoint.hostname || endpoint.username || endpoint.password || endpoint.search || endpoint.hash || (endpoint.port && (!/^\d+$/.test(endpoint.port) || Number(endpoint.port) < 1 || Number(endpoint.port) > 65535))) { throw new Error('Invalid address'); }
      return endpoint.href;
    } catch (_) {}
  }
  const error = new Error(message); error.name = 'RelayConfigError'; throw error;
}

export class SecureRpc {
  private socket?: webSocket.WebSocket;
  private handle: number = 0;
  private stage: string = 'closed';
  private readyResolve?: () => void;
  private readyReject?: (error: Error) => void;
  private responseResolve?: (value: string) => void;
  private responseReject?: (error: Error) => void;
  private epoch: number = 0;
  private requestChain: Promise<void> = Promise.resolve();
  private queuedRequests: number = 0;
  private timer: number = -1;
  private handshakeTimer: number = -1;
  backend: string = 'codex';
  binding: string = '';
  encrypted: boolean = false;
  onClosed?: (error: Error) => void;
  onAuthenticationRequired?: () => void;

  async connect(key: TransportIdentity, macPublic: string, macId: string, relayUrl?: string): Promise<void> {
    const endpoint: string = relayEndpoint(relayUrl);
    this.close(); const pin = decode(macPublic);
    if (pin.byteLength !== 32 || hex(native.sha256(pin)) !== macId) { throw new Error('Mac 身份与固定公钥不匹配'); }
    try { this.handle = native.create(key.privateKey, pin); } finally { new Uint8Array(key.privateKey).fill(0); }
    this.stage = 'link'; const epoch: number = this.epoch; const socket = webSocket.createWebSocket(); this.socket = socket;
    const ready = new Promise<void>((resolve, reject) => { this.readyResolve = resolve; this.readyReject = reject; });
    ready.catch(() => { });
    this.handshakeTimer = setTimeout(() => { this.fail(linkError('安全连接恢复超时'), epoch); }, 10000);
    socket.on('message', (error: BusinessError, data: string | ArrayBuffer) => {
      if (epoch !== this.epoch || this.socket !== socket) { return; }
      if (error && error.code) { this.fail(linkError('网络连接暂时中断'), epoch); return; }
      this.receive(data, epoch);
    });
    socket.on('close', () => { this.fail(linkError('网络连接暂时中断'), epoch); });
    socket.on('error', () => { this.fail(linkError('网络暂时不可用'), epoch); });
    try {
      const opened = new Promise<void>((resolve, reject) => {
        socket.on('open', (error: BusinessError) => { if (epoch !== this.epoch) { return; } if (error && error.code) { reject(linkError('网络暂时不可用')); } else { resolve(); } });
      });
      const dialing = socket.connect(endpoint); dialing.then(() => { if (epoch !== this.epoch) { socket.close().catch(() => {}); } }, () => {});
      await Promise.race([dialing, ready]);
      await Promise.race([opened, ready]); console.info('CM_CONNECTION websocket-open');
      if (epoch !== this.epoch) { throw linkError('已取消旧连接'); }
      await socket.send(JSON.stringify({ role: 'client', gatewayId: macId }));
      await ready; if (epoch !== this.epoch || !this.encrypted) { throw linkError('已取消旧连接'); }
    } catch (error) { this.fail(error as Error, epoch); throw (error as Error); }
  }
  private receive(data: string | ArrayBuffer, epoch: number): void {
    if (epoch !== this.epoch) { return; }
    try {
      if (this.stage === 'link') {
        if (typeof data !== 'string' || (JSON.parse(data) as LinkReply).type !== 'linked') { throw new Error('中继路由响应无效'); }
        this.stage = 'handshake'; console.info('CM_CONNECTION relay-linked');
        this.sendPacket(native.begin(this.handle)); return;
      }
      if (typeof data === 'string') { throw new Error('拒绝明文业务数据'); }
      if (this.stage === 'handshake') {
        const info = native.finish(this.handle, data); this.binding = encode(info.hash);
        this.stage = 'ready'; console.info('CM_CONNECTION encrypted-ready'); this.encrypted = true; clearTimeout(this.handshakeTimer);
        const done = this.readyResolve; this.readyResolve = undefined; this.readyReject = undefined;
        if (done !== undefined) { done(); } return;
      }
      if (this.stage !== 'ready') { throw new Error('安全会话未就绪'); }
      const value = native.decrypt(this.handle, data);
      if (value === undefined) { return; }
      const result = stringOf(value); new Uint8Array(value).fill(0);
      const done = this.responseResolve;
      this.responseResolve = undefined; this.responseReject = undefined; clearTimeout(this.timer);
      if (done !== undefined) { done(result); }
    } catch (error) { this.fail(error as Error, epoch); }
  }
  private sendPacket(data: ArrayBuffer): void {
    if (this.socket === undefined) { this.fail(new Error('安全连接不存在')); return; }
    const socket = this.socket; const epoch: number = this.epoch; socket.send(data).catch(() => { this.fail(linkError('发送连接中断，已提交的消息会核对状态'), epoch); });
  }
  request<T>(method: string, path: string, body?: Object, authorization?: string): Promise<T> {
    if (this.queuedRequests >= 8) { return Promise.reject(new Error('当前操作较多，请稍后重试')); }
    const binding: string = this.binding; const backend: string = this.backend; this.queuedRequests++;
    const result: Promise<T> = this.requestChain.then(async (): Promise<T> => {
      if (!this.encrypted || this.binding !== binding) { throw linkError('连接正在恢复，排队请求未发送'); }
      return await this.requestNow<T>(method, path, backend, body, authorization);
    });
    this.requestChain = result.then(() => { this.queuedRequests--; }, () => { this.queuedRequests--; });
    return result;
  }
  private async requestNow<T>(method: string, path: string, backend: string, body?: Object, authorization?: string): Promise<T> {
    if (!this.encrypted || this.responseResolve !== undefined) { throw new Error('安全会话不可用或上一请求未完成'); }
    const epoch: number = this.epoch;
    const requestId: string = encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer);
    const request: WireRequest = { requestId: requestId, method: method, path: path, backend: backend, body: body, authorization: authorization };
    const promise = new Promise<string>((resolve, reject) => {
      this.responseResolve = resolve; this.responseReject = reject;
      this.timer = setTimeout(() => { this.fail(linkError('网络响应超时，已提交消息会核对状态'), epoch); }, 10000);
    });
    promise.catch(() => { });
    try {
      const bytes = utf8(JSON.stringify(request));
      const records = native.encrypt(this.handle, bytes); new Uint8Array(bytes).fill(0);
      // Noise records use ordered nonces; await each native send before the next.
      const socket = this.socket;
      if (!socket) { throw linkError('发送连接已断开'); }
      for (const record of records) {
        if (epoch !== this.epoch || this.socket !== socket) { throw linkError('连接已更新，上传尚未完成'); }
        if (!await socket.send(record)) { throw linkError('发送连接中断，已提交的消息会核对状态'); }
      }
      const raw = await promise;
      if (epoch !== this.epoch) { throw linkError('旧连接响应已丢弃'); }
      const response = JSON.parse(raw) as WireResponse<T>;
      if (response.requestId !== requestId) { this.close(); throw new Error('请求与响应不匹配'); }
      if (response.error !== undefined) { if (['AUTH_REQUIRED', 'AUTH_DENIED'].includes(response.error.code) && !path.startsWith('/v1/auth/') && !path.startsWith('/v1/pairings/') && this.onAuthenticationRequired) { this.onAuthenticationRequired(); } throw new RemoteError(response.error.code, response.error.message); }
      if (response.data === undefined) { throw new Error('服务端返回空业务结果'); }
      return response.data;
    } catch (error) { if (epoch === this.epoch && this.responseReject !== undefined) { this.fail(error as Error, epoch); } throw (error as Error); }
  }
  private fail(error: Error, epoch: number = this.epoch): void {
    if (epoch !== this.epoch || this.stage === 'closed') { return; }
    console.warn('CM_CONNECTION failed stage=' + this.stage + ' kind=' + error.name);
    const ready = this.readyReject; const response = this.responseReject;
    this.readyResolve = undefined; this.readyReject = undefined; this.responseResolve = undefined; this.responseReject = undefined;
    this.close(); if (ready !== undefined) { ready(error); } if (response !== undefined) { response(error); }
    if (this.onClosed !== undefined) { this.onClosed(error); }
  }
  close(): void {
    this.epoch++;
    const ready = this.readyReject; const response = this.responseReject;
    this.readyResolve = undefined; this.readyReject = undefined; this.responseResolve = undefined; this.responseReject = undefined;
    if (ready !== undefined) { ready(linkError('连接已更新')); }
    if (response !== undefined) { response(linkError('连接已更新，已提交消息会核对状态')); }
    clearTimeout(this.timer); clearTimeout(this.handshakeTimer); this.encrypted = false; this.stage = 'closed'; this.binding = '';
    if (this.handle > 0) { try { native.close(this.handle); } catch (_) { } this.handle = 0; }
    const ws = this.socket; this.socket = undefined;
    if (ws !== undefined) { ws.off('open'); ws.off('message'); ws.off('close'); ws.off('error'); ws.close().catch(() => { }); }
  }
}
