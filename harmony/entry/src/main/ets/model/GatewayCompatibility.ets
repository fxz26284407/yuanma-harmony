// App 发布时维护最低兼容版本，用户无需自行调整。
export const MIN_GATEWAY_VERSION: string = '0.1.7';
export const GATEWAY_UPDATE_COMMAND: string = 'npm install -g @fxz26284407/yuanma-gateway@latest';
export interface GatewayInfo { gatewayVersion?: string; }

export function requireGatewayVersion(version?: string): string {
  const error = new Error('无法确认 Gateway 版本，最低要求 ' + MIN_GATEWAY_VERSION + '。请在 Mac 更新后重新生成二维码：\n' + GATEWAY_UPDATE_COMMAND + '\nyuanma-gateway restart\nyuanma-gateway pair');
  error.name = 'GatewayVersionError';
  if (typeof version !== 'string' || version.length > 100) { throw error; }
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.exec(version);
  if (match === null || [match[1], match[2], match[3]].some((part: string) => !Number.isSafeInteger(Number(part)))) { throw error; }
  if (match[4] && match[4].split('.').some((part: string) => /^\d+$/.test(part) && part.length > 1 && part.startsWith('0'))) { throw error; }
  const minimum: string[] = MIN_GATEWAY_VERSION.split('.');
  let supported: boolean = !match[4];
  for (let i = 0; i < 3; i++) {
    if (Number(match[i + 1]) !== Number(minimum[i])) { supported = Number(match[i + 1]) > Number(minimum[i]); break; }
  }
  if (!supported) {
    error.message = 'Gateway ' + version + ' 版本过低，最低要求 ' + MIN_GATEWAY_VERSION + '。请在 Mac 更新：\n' + GATEWAY_UPDATE_COMMAND + '\nyuanma-gateway restart\nyuanma-gateway pair';
    throw error;
  }
  return version;
}
