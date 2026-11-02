import { util } from '@kit.ArkTS';

export interface AuthChallenge {
  challengeId: string;
  purpose: string;
  gatewayId: string;
  deviceId: string;
  nonce: string;
  expiresAt: number;
  signingPublicKey: string;
}

export interface AuthContext {
  purpose: string;
  pinnedGatewayId: string;
  expectedDeviceId: string;
  transportPublicKey: string;
  sessionBinding: string;
  signingPublicKey: string;
}

// Serialize the application transcript only. Noise performs all transport cryptography.
export function authTranscript(challenge: AuthChallenge, context: AuthContext): Uint8Array {
  if ((context.purpose !== 'pair' && context.purpose !== 'login') ||
    challenge.purpose !== context.purpose || challenge.gatewayId !== context.pinnedGatewayId ||
    challenge.deviceId !== context.expectedDeviceId || challenge.signingPublicKey !== context.signingPublicKey ||
    context.transportPublicKey.length === 0 || context.sessionBinding.length === 0 ||
    challenge.expiresAt <= Date.now() || challenge.nonce.length !== 43) {
    throw new Error('Authentication challenge context mismatch');
  }
  const value: (string | number)[] = ['CodexMobileAuth', 1, context.purpose, challenge.gatewayId,
    challenge.deviceId, challenge.nonce, challenge.expiresAt, context.transportPublicKey,
    context.sessionBinding, context.signingPublicKey];
  return new util.TextEncoder().encodeInto(JSON.stringify(value));
}
