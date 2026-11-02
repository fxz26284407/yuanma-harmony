import { CreateProjectBody } from './UiTypes';
import { connection } from '@kit.NetworkKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { SuggestionView, SuggestionBody, ChangeSummary, DiffChunk, DraftImage, ImageUploadBody, ImageUploadResult, RemoveImagesBody, ThreadManagementRequest, ThreadManagementBody, ThreadManagementResult } from './UiTypes';
import { ExtensionItem, ExtensionPage, PermissionState, PermissionBody, ImageReference, ImageChunk } from './UiTypes';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Identity } from '../security/Identity';
import { HuksSigner } from '../security/HuksSigner';
import { authTranscript, AuthChallenge, AuthContext } from '../security/AuthTranscript';
import native from 'libcodexnoise.so';
import { encode, decode, hex, utf8 } from '../security/Bytes';
import { SecureRpc, relayEndpoint, RemoteError } from '../net/SecureRpc';

import { DisplaySettings, UiState, PairMaterial, KnownMac, ClaimResult, ClaimBody, ProofBody, LoginBody, LoginProof, PairStatus, LoginResult, ProjectItem, ThreadItem, ThreadPage, SnapshotBackend, SnapshotMessage, ExecutionSummary, LiveProgress, Snapshot, TextInputItem, HistoryItem, HistoryTurn, HistoryPage, HistoryChunk, MessageView, MessagePayload, PendingSend, SendBody, QueuedMessage, SteerBody, OperationResult, QuestionOption, QuestionItem, QuestionAnswer, QuestionReplyBody, ApprovalItem, ApprovalReplyBody, ApprovalReplyResult, InterruptBody, InterruptResult, CancelBody, NavigationThread, NavigationProject, NavigationSection, NavigationData, ModelItem, ModelSettings, ModelSettingsBody, CreateThreadBody, BackendStatus } from './UiState';
export * from './UiState';

@Observed
export class MobileSession extends UiState {
  private attachmentRoot: string = '';
  private imageRoot: string = '';
  private imageCache: Map<string, string> = new Map<string, string>();
  private imageTasks: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private imageWrites: Promise<void> = Promise.resolve();
  private selectedImageId: string = '';
  private extensionGeneration: number = 0;
  private draftWrites: Promise<void> = Promise.resolve();
  private olderMessages: MessageView[] = [];
  private readingMessage?: MessageView;
  private displayWrites: Promise<void> = Promise.resolve();
  private identity: Identity = new Identity();
  private signer: HuksSigner = new HuksSigner();
  private rpc: SecureRpc = new SecureRpc();
  private appearanceContext?: common.Context;
  private mac?: KnownMac;
  private transportPublic: string = '';
  private signingPublic: string = '';
  private pendingSend?: PendingSend;
  private asyncQuestions: ApprovalItem[] = [];
  private suggestionRequestKey: string = '';
  private suggestionPending: boolean = false;
  private suggestionTurnId: string = '';
  private token: string = '';
  private tokenExpires: number = 0;
  private generation: number = 0;
  private reconnectTask?: Promise<void>;
  private retryTimer: number = -1;
  private retryDelay: number = 500;
  private foreground: boolean = true;
  private network?: connection.NetConnection;
  private networkId: number = -1;
  private networkLink: string = '';

  constructor() {
    super();
    this.rpc.onClosed = () => { this.connectionLost(); };
    this.rpc.onAuthenticationRequired = () => { this.connectionLost(); };
  }
  private applyAppearance(): void {
    const context = this.appearanceContext; if (!context) { return; }
    const light: boolean = this.appearance === 'light';
    AppStorage.setOrCreate('appAppearance', this.appearance);
    context.getApplicationContext().setColorMode(light ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    const background: string = light ? '#F6F8FB' : '#2D333F'; const ink: string = light ? '#202B3D' : '#DBE3EF';
    window.getLastWindow(context).then(async (main: window.Window) => { await main.setWindowSystemBarProperties({ statusBarColor: background, navigationBarColor: background, statusBarContentColor: ink, navigationBarContentColor: ink }); }).catch(() => {});
  }
  async saveDisplaySettings(reduceTransparency: boolean, reduceMotion: boolean, appearance: string = this.appearance): Promise<void> {
    if (appearance !== 'dark' && appearance !== 'light') { throw new Error('无效的外观选项'); }
    this.appearance = appearance; this.applyAppearance();
    this.reduceTransparency = reduceTransparency; this.reduceMotion = reduceMotion; const value: DisplaySettings = { reduceTransparency: reduceTransparency, reduceMotion: reduceMotion, appearance: appearance };
    this.displayWrites = this.displayWrites.catch(() => {}).then(async () => { await this.identity.put('displaySettings', JSON.stringify(value)); }); await this.displayWrites;
  }
  async initialize(context: common.Context): Promise<void> {
    if (this.initialized) { return; }
    this.appearanceContext = context;
    await this.identity.initialize(context);
    this.nextSuggestionEnabled = (await this.identity.get('nextSuggestionEnabled')) !== 'false';
    this.attachmentRoot = context.filesDir + '/codex-attachments'; if (!fileIo.accessSync(this.attachmentRoot)) { fileIo.mkdirSync(this.attachmentRoot); }
    try { this.imageRoot = context.cacheDir + '/codex-media'; if (!fileIo.accessSync(this.imageRoot)) { fileIo.mkdirSync(this.imageRoot); } fileIo.listFileSync(this.imageRoot).forEach((name: string) => { if (/^(ext-)?[a-f0-9]{64}\.(png|jpg|gif|webp|svg)$/.test(name)) { fileIo.unlinkSync(this.imageRoot + '/' + name); } }); } catch (_) { this.imageRoot = ''; }
    const display: string = await this.identity.get('displaySettings'); if (display) { const value = JSON.parse(display) as DisplaySettings; this.reduceTransparency = value.reduceTransparency === true; this.reduceMotion = value.reduceMotion === true; this.appearance = value.appearance === 'light' ? 'light' : 'dark'; }
    this.applyAppearance();
    const pending: string = await this.identity.get('pendingSend');
    if (pending) { this.pendingSend = JSON.parse(pending) as PendingSend; this.lastMessageState = 'unknown'; }
    const cached: string = await this.identity.get('knownMac');
    if (cached.length > 0) { this.mac = JSON.parse(cached) as KnownMac; this.hasKnownMac = true; this.fingerprint = this.mac.gatewayId; this.projectCreationPath = (await this.identity.get('projectCreationPath.' + this.mac.gatewayId)) || '~/workspace'; }
    this.initialized = true; this.watchNetwork();
  }
  private async connect(mac: KnownMac, generation: number = this.generation): Promise<void> {
    this.checkGeneration(generation); this.clearConnection(); this.status = '正在建立安全会话';
    const key = await this.identity.transport();
    try { this.checkGeneration(generation); this.transportPublic = key.publicKey;
      this.signingPublic = encode(await this.signer.publicKey()); this.checkGeneration(generation);
      await this.rpc.connect(key, mac.publicKey, mac.gatewayId, mac.relayUrl);
    } finally { new Uint8Array(key.privateKey).fill(0); }
    this.checkGeneration(generation); this.mac = mac; this.encrypted = true; this.fingerprint = mac.gatewayId; this.status = '安全会话已建立';
    this.projectCreationPath = (await this.identity.get('projectCreationPath.' + mac.gatewayId)) || '~/workspace'; this.checkGeneration(generation);
  }
  private async sign(challenge: AuthChallenge, purpose: string, deviceId: string): Promise<string> {
    if (this.mac === undefined) { throw new Error('缺少固定的 Mac 身份'); }
    const context: AuthContext = { purpose: purpose, pinnedGatewayId: this.mac.gatewayId, expectedDeviceId: deviceId,
      transportPublicKey: this.transportPublic, sessionBinding: this.rpc.binding, signingPublicKey: this.signingPublic };
    return encode(await this.signer.signChallenge(authTranscript(challenge, context)));
  }
  async pair(materialText: string): Promise<void> {
    if (this.busy || materialText.length > 8192) { throw new Error('配对材料过大或操作尚未完成'); }
    const material = JSON.parse(materialText) as PairMaterial;
    if (!material || material.profile !== 'Noise_IK_25519_ChaChaPoly_BLAKE2b' || typeof material.gatewayId !== 'string' || !/^[a-f0-9]{64}$/.test(material.gatewayId) ||
      typeof material.publicKey !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(material.publicKey) || typeof material.secret !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(material.secret) ||
      typeof material.pairingId !== 'string' || !material.pairingId || material.pairingId.length > 200 || !Number.isSafeInteger(material.expiresAt) || material.expiresAt <= Date.now()) { throw new Error('配对材料无效或已过期'); }
    const endpoint: string = relayEndpoint(material.relayUrl);
    if (this.mac !== undefined && (this.mac.gatewayId !== material.gatewayId || this.mac.publicKey !== material.publicKey)) { throw new Error('Mac 身份变化，请先明确断开旧身份后重新确认'); }
    const previousMac: KnownMac | undefined = this.mac;
    this.reconnectEnabled = true; this.busy = true; const generation = ++this.generation;
    try {
      const mac: KnownMac = { gatewayId: material.gatewayId, publicKey: material.publicKey, relayUrl: endpoint };
      await this.connect(mac, generation);
      const existingId: string = this.hasKnownMac && previousMac ? await this.identity.get(`device.${mac.gatewayId}`) : '';
      this.checkGeneration(generation);
      if (existingId) {
        await this.login(existingId, generation); this.checkGeneration(generation);
        await this.identity.put('knownMac', JSON.stringify(mac)); this.hasKnownMac = true;
        this.detail = '连接地址已更新，原设备身份和项目权限保留'; return;
      }
      const claimBody: ClaimBody = { pairingId: material.pairingId, secret: material.secret, name: 'HarmonyOS Codex Mobile', signingPublicKey: this.signingPublic };
      const claim = await this.rpc.request<ClaimResult>('POST', '/v1/pairings/claim', claimBody);
      this.deviceId = claim.deviceId;
      await this.identity.put(`device.${mac.gatewayId}`, claim.deviceId);
      const proof: ProofBody = { claimId: claim.claimId, challengeId: claim.challenge.challengeId, signature: await this.sign(claim.challenge, 'pair', claim.deviceId) };
      await this.rpc.request<PairStatus>('POST', '/v1/pairings/proof', proof, `Pairing ${claim.claimToken}`);
      this.status = '正在完成设备授权'; this.detail = '正在验证 Mac 预先授予的项目权限';
      while (Date.now() < claim.expiresAt && generation === this.generation) {
        const state = await this.rpc.request<PairStatus>('GET', `/v1/pairings/${claim.claimId}/status`, undefined, `Pairing ${claim.claimToken}`);
        if (state.state === 'approved') {
          await this.identity.put('knownMac', JSON.stringify(mac)); this.hasKnownMac = true;
          await this.login(claim.deviceId, generation); return;
        }
        if (state.state !== 'pending') { throw new Error(`配对未完成：${state.state}`); }
        await new Promise<void>((resolve) => { setTimeout(resolve, 2000); });
      }
      throw new Error('配对已过期或被取消');
    } catch (error) { if (previousMac) { this.mac = previousMac; } this.disconnect(); if (this.hasKnownMac && this.reconnectEnabled) { this.scheduleRecovery(500); } throw (error as Error); } finally { this.busy = false; }
  }
  private async login(deviceId: string, generation: number = this.generation): Promise<void> {
    if (this.mac === undefined) { throw new Error('缺少 Mac 身份'); }
    this.status = '正在验证设备身份';
    const data: LoginBody = { deviceId: deviceId, gatewayId: this.mac.gatewayId };
    const challenge = await this.rpc.request<AuthChallenge>('POST', '/v1/auth/challenge', data);
    this.checkGeneration(generation);
    const proof: LoginProof = { challengeId: challenge.challengeId, signature: await this.sign(challenge, 'login', deviceId) };
    this.checkGeneration(generation);
    const result = await this.rpc.request<LoginResult>('POST', '/v1/auth/verify', proof);
    this.checkGeneration(generation);
    this.token = result.accessToken; this.tokenExpires = result.expiresAt; this.deviceId = result.deviceId;
    this.projects = await this.rpc.request<ProjectItem[]>('GET', '/v1/projects', undefined, `Bearer ${this.token}`); this.checkGeneration(generation);
    this.authenticated = true;
    const status = await this.rpc.request<BackendStatus>('GET', '/v1/status', undefined, `Bearer ${this.token}`); this.checkGeneration(generation);
    if (status.backendReady) { try { const models = await this.rpc.request<ModelItem[]>('GET', '/v1/models', undefined, `Bearer ${this.token}`); this.checkGeneration(generation); this.models = models; } catch (error) { if (!this.authenticated || generation !== this.generation) { throw error as Error; } } }
    this.status = '已连接 Mac'; this.detail = status.backendReady ? '安全连接已恢复' : 'Mac 已连接，Codex 后端暂未就绪';
    this.recovering = false; this.recoveryIssue = ''; this.retryDelay = 500; clearTimeout(this.retryTimer); this.connectionVersion++;
  }
  private checkGeneration(generation: number): void { if (generation !== this.generation) { const error = new Error('已取消旧连接操作'); error.name = 'LinkError'; throw error; } }
  private clearConnection(): void { this.encrypted = false; this.authenticated = false; this.token = ''; this.approvals = []; this.extensionGeneration++; this.extensionItems = []; this.extensionTotal = 0; this.extensionLoading = false; this.extensionSyncStatus = ''; }
  private connectionLost(reason: string = 'transport'): void {
    console.info('CM_CONNECTION reset reason=' + reason);
    this.generation++; this.rpc.close(); this.clearConnection();
    if (this.reconnectEnabled && this.hasKnownMac && this.foreground) { this.recovering = true; this.status = '正在恢复连接'; this.detail = '网络切换后自动恢复，草稿保留，已提交消息会核对状态'; this.scheduleRecovery(500); }
  }
  private scheduleRecovery(delay: number): void {
    clearTimeout(this.retryTimer);
    if (!this.initialized || !this.foreground || !this.reconnectEnabled || !this.hasKnownMac || this.authenticated) { return; }
    this.recovering = true;
    this.retryTimer = setTimeout(() => { if (this.busy || this.reconnectTask) { this.scheduleRecovery(250); return; } this.reconnect().catch(() => {}); }, delay);
  }
  setForeground(active: boolean): void {
    this.foreground = active;
    if (!active) { this.disconnect(); this.status = this.reconnectEnabled ? '已暂停连接，返回后自动恢复' : '连接已暂停'; }
    else if (this.initialized) { this.watchNetwork(); if (!this.authenticated) { this.scheduleRecovery(0); } }
  }
  private watchNetwork(): void {
    if (this.network) { return; }
    try {
      this.network = connection.createNetConnection(); this.network.register(() => {});
      this.network.on('netAvailable', (net: connection.NetHandle) => { const changed: boolean = this.networkId !== net.netId && (this.networkId >= 0 || (this.reconnectTask !== undefined && this.recovering)); if (this.networkId !== net.netId) { this.networkLink = ''; } this.networkId = net.netId; if (!this.foreground || !this.hasKnownMac || !this.reconnectEnabled) { return; } this.retryDelay = 500; if (changed) { this.connectionLost('network-available'); } else if (!this.authenticated) { this.scheduleRecovery(0); } });
      this.network.on('netConnectionPropertiesChange', (info: connection.NetConnectionPropertyInfo) => { if (info.netHandle.netId !== this.networkId) { return; } const p = info.connectionProperties; const key: string = JSON.stringify([p.interfaceName, p.linkAddresses.map((a: connection.LinkAddress) => a.address.address + '/' + a.prefixLength).sort(), p.routes.filter((r: connection.RouteInfo) => r.isDefaultRoute).map((r: connection.RouteInfo) => r.interface + ':' + r.gateway.address + ':' + r.destination.address.address + '/' + r.destination.prefixLength).sort()]); const changed: boolean = this.networkLink !== '' && key !== this.networkLink; this.networkLink = key; if (changed && this.foreground && this.reconnectEnabled && this.hasKnownMac) { this.retryDelay = 500; this.connectionLost('network-properties'); } });
      this.network.on('netLost', (net: connection.NetHandle) => { if (net.netId !== this.networkId) { return; } this.networkId = -1; this.networkLink = ''; if (this.foreground && this.reconnectEnabled && this.hasKnownMac) { this.connectionLost('network-lost'); } });
    } catch (_) { this.network = undefined; }
  }
  dispose(): void { this.setForeground(false); if (this.network) { try { this.network.unregister(() => {}); } catch (_) {} this.network = undefined; this.networkId = -1; } }
  reconnect(): Promise<void> {
    if (this.reconnectTask) { return this.reconnectTask; }
    if (this.busy || this.mac === undefined) { return Promise.reject(new Error('没有已配对的 Mac，或操作尚未完成')); }
    this.reconnectEnabled = true; this.recoveryIssue = ''; clearTimeout(this.retryTimer); const generation: number = ++this.generation;
    const task: Promise<void> = this.restoreConnection(generation); this.reconnectTask = task;
    task.then(() => { if (this.reconnectTask === task) { this.reconnectTask = undefined; } }, () => { if (this.reconnectTask === task) { this.reconnectTask = undefined; } }); return task;
  }
  private async restoreConnection(generation: number): Promise<void> {
    this.busy = true; this.recovering = true;
    try {
      console.info('CM_CONNECTION restore-start');
      const mac = this.mac!; await this.connect(mac, generation); const id: string = await this.identity.get(`device.${mac.gatewayId}`); this.checkGeneration(generation); if (!id) { throw new Error('设备身份记录缺失，请重新配对'); }
      await this.login(id, generation);
      try { const navigation = await this.rpc.request<NavigationData>('GET', '/v1/navigation', undefined, this.authorization()); this.checkGeneration(generation); this.navigation = navigation; this.newProjectCapability = navigation.newProjectCapability || 'none'; await this.loadHistory(); await this.loadModelSettings(); } catch (error) { if (!this.authenticated || generation !== this.generation) { throw error as Error; } this.detail = '已连接 Mac，会话正在同步'; }
    } catch (error) {
      if (generation === this.generation) {
        this.rpc.close(); this.clearConnection();
        const failed = error as Error; console.warn('CM_CONNECTION restore-failed kind=' + failed.name + ' code=' + (failed instanceof RemoteError ? failed.code : 'local')); const denied: boolean = (failed instanceof RemoteError && failed.code === 'AUTH_DENIED') || failed.message.includes('身份与固定公钥不匹配') || failed.message.includes('身份记录缺失');
        if (failed.name === 'RelayConfigError') { this.reconnectEnabled = false; this.recovering = false; this.recoveryIssue = failed.message; this.status = '需更新连接地址'; this.detail = this.recoveryIssue; clearTimeout(this.retryTimer); }
        else if (denied) { this.reconnectEnabled = false; this.recovering = false; this.recoveryIssue = '设备授权需要确认，请在 Mac 检查此设备'; this.status = '需检查 Mac 授权'; this.detail = this.recoveryIssue; clearTimeout(this.retryTimer); }
        else { this.status = '正在恢复连接'; this.recovering = true; this.retryDelay = Math.min(15000, this.retryDelay * 2); this.scheduleRecovery(this.retryDelay); }
      }
      throw error as Error;
    } finally { this.busy = false; }
  }
  private authorization(): string {
    if (!this.authenticated || !this.rpc.encrypted || this.tokenExpires <= Date.now()) { this.connectionLost(); const error = new Error('连接正在恢复，本次请求未发送'); error.name = 'LinkError'; throw error; }
    return `Bearer ${this.token}`;
  }
  async send(projectId: string, threadId: string, content: string): Promise<void> {
    if (this.busy || (content.trim().length === 0 && this.references.length === 0 && this.attachments.length === 0)) { throw new Error('请输入指令或选择图片，并等待上一操作完成'); }
    if (!this.projects.some((p: ProjectItem) => p.id === projectId && p.capability === 'control')) { throw new Error('该项目仅允许阅读，请在 Mac 调整设备授权'); }
    if (this.pendingSend !== undefined && (!threadId || this.pendingSend.projectId !== projectId || this.pendingSend.threadId !== threadId)) { throw new Error('上一条发送结果未知，请先恢复原会话核对'); }
    this.busy = true;
    const sourceDraftKey = this.draftKey();
    const selectedReferences: string[] = this.references.map((r: ExtensionItem) => r.id);
    const selectedImages: DraftImage[] = [...this.attachments];
    try {
      if (!threadId) {
        const body: CreateThreadBody = { projectId: projectId, model: this.selectedModel || undefined, effort: this.selectedEffort || undefined, serviceTier: this.selectedServiceTier || null, approvalMode: this.permissionMode, confirmFullAccess: this.fullAccessConfirmed };
        const thread = await this.rpc.request<ThreadItem>('POST', '/v1/threads', body, this.authorization());
        threadId = thread.id; this.changes = undefined; this.diffReview = undefined; this.suggestionText = ''; this.suggestionState = 'idle'; this.suggestionTurnId = ''; this.selectedThreadId = thread.id; this.selectedThreadName = thread.name;
        const newKey: string = this.draftKey(); const draft: string = this.draft; const refs: string = JSON.stringify(this.references); const images: string = JSON.stringify(selectedImages); this.draftWrites = this.draftWrites.catch(() => {}).then(async () => { await this.identity.put(newKey, draft); await this.identity.put('refs.' + newKey, refs); await this.identity.put('images.' + newKey, images); });
      }
      const hash: string = this.draftHash(projectId, threadId, content, selectedReferences, selectedImages.map((item: DraftImage) => item.id));
      if (this.pendingSend !== undefined && (this.pendingSend.hash !== hash || this.pendingSend.threadId !== threadId || this.pendingSend.projectId !== projectId)) {
        throw new Error('上一条发送结果未知，请先恢复原会话核对；不能换新 ID 重发');
      }
      await this.uploadImages(projectId, selectedImages);
      const id: string = this.pendingSend !== undefined ? this.pendingSend.id : encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer);
      this.pendingSend = { draftKey: sourceDraftKey, id: id, projectId: projectId, threadId: threadId, hash: hash };
      await this.identity.put('pendingSend', JSON.stringify(this.pendingSend));
      const body: SendBody = { type: 'message.send', clientMessageId: id, projectId: projectId, threadId: threadId, payload: { text: content, references: selectedReferences, images: selectedImages.map((item: DraftImage) => item.id) } };
      try {
        const result = await this.rpc.request<QueuedMessage>('POST', '/v1/commands', body, this.authorization());
        this.lastSubmissionId = result.id; this.lastMessageState = result.state; this.lastPendingText = content;
        await this.identity.put('pendingSend', ''); this.pendingSend = undefined;
        await this.acknowledgeDraft(sourceDraftKey, hash, projectId, threadId);
        this.detail = '网关已接收，执行状态以后端事实为准';
      } catch (error) {
        const failed = error as Error;
        if ((failed.name === 'LinkError' && failed.message.includes('未发送')) || (failed instanceof RemoteError && ['PROJECT_FORBIDDEN', 'THREAD_MISMATCH', 'UNSAFE_THREAD', 'PAYLOAD_TOO_LARGE', 'QUEUE_FULL', 'AUTH_REQUIRED', 'AUTH_DENIED', 'INVALID_REFERENCES', 'REFERENCE_UNAVAILABLE', 'INVALID_IMAGES', 'IMAGE_NOT_READY'].includes(failed.code))) {
          await this.identity.put('pendingSend', ''); this.pendingSend = undefined; this.lastMessageState = 'failed';
        } else { this.lastMessageState = 'unknown'; }
        throw failed;
      }
      try { await this.loadHistory(); } catch (_) { this.detail = '消息已接收，状态暂未刷新；请勿换新 ID 重发'; }
    } finally { this.busy = false; this.uploadProgress = -1; }
  }
  async answerQuestion(request: ApprovalItem, values: Map<string, string>): Promise<void> {
    if (this.busy) { throw new Error('请等待当前操作完成'); }
    const answers: Record<string, QuestionAnswer> = {};
    request.questions.forEach((q: QuestionItem) => { const answer = values.get(q.id) || ''; if (!answer.trim()) { throw new Error('请回答每个问题'); } answers[q.id] = { answers: [answer] }; });
    this.busy = true;
    try {
      const body: QuestionReplyBody = { projectId: this.selectedProjectId, threadId: this.selectedThreadId, id: request.id, sourceTurnId: request.sourceTurnId, answers: answers };
      await this.rpc.request<ApprovalReplyResult>('POST', '/v1/questions/reply', body, this.authorization());
      this.approvals = this.approvals.filter((a: ApprovalItem) => a.id !== request.id); this.detail = '回答已提交'; await this.loadHistory();
    } finally { this.busy = false; }
  }
  async replyApproval(id: string, decision: string): Promise<void> {
    if (this.busy) { throw new Error('请等待当前操作完成'); }
    this.busy = true;
    try {
      const body: ApprovalReplyBody = { projectId: this.selectedProjectId, threadId: this.selectedThreadId, id: id, decision: decision };
      await this.rpc.request<ApprovalReplyResult>('POST', '/v1/approvals/reply', body, this.authorization());
      this.approvals = this.approvals.filter((a: ApprovalItem) => a.id !== id);
      this.detail = '审批答复已提交';
    } finally { this.busy = false; }
  }
  async stop(): Promise<void> {
    if (this.busy || !this.currentTurnId) { throw new Error('当前没有可停止的任务'); }
    this.busy = true;
    try {
      const body: InterruptBody = { projectId: this.selectedProjectId, threadId: this.selectedThreadId, turnId: this.currentTurnId };
      await this.rpc.request<InterruptResult>('POST', '/v1/turns/interrupt', body, this.authorization());
      this.detail = '停止请求已提交，等待后端确认'; await this.loadHistory();
    } finally { this.busy = false; }
  }
  async cancelQueued(submissionId?: string): Promise<void> {
    const id: string = submissionId || this.lastSubmissionId;
    const state: string = this.queueMessages.find((m: SnapshotMessage) => m.id === id)?.state || (id === this.lastSubmissionId ? this.lastMessageState : '');
    if (this.busy || !id || state !== 'queued') { throw new Error('当前消息已不能撤回'); }
    this.busy = true;
    try {
      const body: CancelBody = { type: 'queue.cancel', clientOperationId: encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer), submissionId: id };
      await this.rpc.request<OperationResult>('POST', '/v1/commands', body, this.authorization()); await this.loadHistory();
    } finally { this.busy = false; }
  }
  async steer(turnId: string, submissionId?: string): Promise<void> {
    const id: string = submissionId || this.lastSubmissionId;
    const state: string = this.queueMessages.find((m: SnapshotMessage) => m.id === id)?.state || (id === this.lastSubmissionId ? this.lastMessageState : '');
    if (this.busy || !id || state !== 'queued') { throw new Error('没有可引导的本设备队列项'); }
    this.busy = true;
    try {
      const body: SteerBody = { type: 'queue.steer', clientOperationId: encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer), submissionId: id, expectedTurnId: turnId };
      const result = await this.rpc.request<OperationResult>('POST', '/v1/commands', body, this.authorization());
      this.lastMessageState = result.state === 'succeeded' ? 'steered' : result.state;
      try { await this.loadHistory(); } catch (_) { this.detail = '引导结果已返回，历史暂未刷新'; }
    } finally { this.busy = false; }
  }
  async manageThread(thread: NavigationThread, request: ThreadManagementRequest): Promise<void> {
    if (this.busy) { throw new Error('操作尚未完成'); }
    if (!this.projects.some((p: ProjectItem) => p.id === thread.projectId && p.capability === 'control')) { throw new Error('此会话只读，不能修改'); }
    if (request.action === 'project' && !this.projects.some((p: ProjectItem) => p.id === request.targetProjectId && p.capability === 'control')) { throw new Error('没有目标项目的操作权限'); }
    let result: ThreadManagementResult; this.busy = true;
    try {
    if (request.action === 'project' || request.action === 'archive') {
      if (this.pendingSend?.threadId === thread.id) { throw new Error('请先核对该会话上次发送的结果，再操作'); }
      if (thread.id === this.selectedThreadId && this.hasDraftContent) { throw new Error('此会话还有草稿，请先发送或清空后操作'); }
      await this.draftWrites.catch(() => {}); const key: string = 'draft.' + thread.projectId + '.' + thread.id;
      const body: string = await this.identity.get(key); const refs: string = await this.identity.get('refs.' + key); const images: string = await this.identity.get('images.' + key);
      if (body.trim() || (refs && (JSON.parse(refs) as ExtensionItem[]).length > 0) || (images && (JSON.parse(images) as DraftImage[]).length > 0)) { throw new Error('此会话还有本机草稿，请先处理后再操作'); }
    }
      const body: ThreadManagementBody = { projectId: thread.projectId, action: request.action, name: request.name, pinned: request.pinned, targetProjectId: request.targetProjectId, sectionId: request.sectionId };
      result = await this.rpc.request<ThreadManagementResult>('POST', '/v1/threads/' + thread.id + '/management', body, this.authorization());
      if (thread.id === this.selectedThreadId && !result.archived) { this.selectedProjectId = result.projectId; this.selectedThreadName = result.name || result.displayName; }
    } catch (error) {
      if (error instanceof RemoteError) {
        if (error.code === 'THREAD_PENDING') { throw new Error('会话还有待处理或状态未确认的消息，请先核对'); }
        if (error.code === 'TURN_BUSY') { throw new Error('会话正在执行，完成或停止后再操作'); }
        if (error.code === 'PROJECT_FORBIDDEN') { throw new Error('没有目标项目的操作权限'); }
        if (error.code === 'CHILD_THREAD_SCOPE') { throw new Error('包含其他项目的子会话，请在 Mac 处理封存'); }
        if (error.code === 'THREAD_MISMATCH') { throw new Error('会话位置已变化，请刷新侧栏后重试'); }
        if (error.code === 'UNSAFE_THREAD') { throw new Error('请先确认此会话的审批权限，再移动项目'); }
      }
      throw error as Error;
    } finally { this.busy = false; }
    if (result.archived && thread.id === this.selectedThreadId) { await this.createThread(); }
    else if (request.action === 'project' && thread.id === this.selectedThreadId) { await this.loadHistory(); await this.loadPermissions(); }
    await this.refreshNavigation();
  }
  async refreshNavigation(): Promise<void> {
    if (!this.authenticated || this.busy) { return; } this.busy = true;
    try { const generation: number = this.generation; const navigation = await this.rpc.request<NavigationData>('GET', '/v1/navigation', undefined, this.authorization()); this.checkGeneration(generation); this.navigation = navigation; this.newProjectCapability = navigation.newProjectCapability || 'none'; const projects = [...navigation.projects, ...navigation.sections.reduce((items: ProjectItem[], section: NavigationSection) => [...items, ...section.projects], [])]; const seen: Set<string> = new Set<string>(); this.projects = projects.filter((p: ProjectItem) => ['read', 'control'].includes(p.capability) && !seen.has(p.id) && !!seen.add(p.id)); } finally { this.busy = false; }
  }
  async openNavigationThread(thread: NavigationThread): Promise<void> {
    if (!thread.projectId) { throw new Error('该会话尚未分配项目，请先在 Mac 归入项目'); }
    const p = this.projects.find((item: ProjectItem) => item.id === thread.projectId);
    if (p === undefined) { throw new Error('请在 Mac 为手机授权该项目'); }
    this.selectedProjectId = thread.projectId; await this.selectThread(thread);
  }
  async loadPermissions(): Promise<void> {
    if (!this.selectedThreadId || !this.authenticated) { return; }
    const thread: string = this.selectedThreadId; const project: string = this.selectedProjectId;
    const value = await this.rpc.request<PermissionState>('GET', '/v1/threads/' + thread + '/permissions?projectId=' + encodeURIComponent(project), undefined, this.authorization());
    if (thread === this.selectedThreadId && project === this.selectedProjectId) { this.permissionMode = value.mode; this.permissionMobileControl = value.mobileControl; this.fullAccessConfirmed = value.mode === 'full' && value.mobileControl; }
  }
  async applyPermissions(mode: string, confirmFullAccess: boolean): Promise<void> {
    if (!this.canControlProject || this.busy) { throw new Error('当前项目不允许修改权限，或操作尚未完成'); }
    if (this.lastMessageState === 'unknown') { throw new Error('请先核对上一条消息的发送结果'); }
    if (!['ask', 'auto', 'full'].includes(mode) || (mode === 'full' && !confirmFullAccess)) { throw new Error('请先确认完整存取权'); }
    this.busy = true;
    try { if (this.selectedThreadId) { const body: PermissionBody = { projectId: this.selectedProjectId, mode: mode, confirmFullAccess: confirmFullAccess }; const value = await this.rpc.request<PermissionState>('POST', '/v1/threads/' + this.selectedThreadId + '/permissions', body, this.authorization()); this.permissionMode = value.mode; this.permissionMobileControl = value.mobileControl; } else { this.permissionMode = mode; this.permissionMobileControl = true; } this.fullAccessConfirmed = mode === 'full' && confirmFullAccess; }
    finally { this.busy = false; }
  }
  async loadExtensions(query: string): Promise<void> {
    if (!this.authenticated || !this.selectedProjectId) { throw new Error('请先连接 Mac 并选择项目'); }
    const generation: number = ++this.extensionGeneration; const project: string = this.selectedProjectId; const thread: string = this.selectedThreadId; const mac: string = this.fingerprint; this.extensionLoading = true;
    try { const result = await this.rpc.request<ExtensionPage>('GET', '/v1/extensions?projectId=' + encodeURIComponent(this.selectedProjectId) + (this.selectedThreadId ? '&threadId=' + encodeURIComponent(this.selectedThreadId) : '') + '&query=' + encodeURIComponent(query), undefined, this.authorization()); if (generation === this.extensionGeneration && mac === this.fingerprint && this.authenticated && project === this.selectedProjectId && thread === this.selectedThreadId) { this.extensionItems = result.items; this.extensionTotal = result.total; } }
    finally { if (generation === this.extensionGeneration) { this.extensionLoading = false; } }
  }
  async syncExtensions(): Promise<void> {
    if (!this.authenticated || this.busy || this.extensionSyncing) { throw new Error('请先连接 Mac，并等待当前操作完成'); }
    const selected: string = this.selectedProjectId; const thread: string = this.selectedThreadId;
    const project = this.projects.find((p: ProjectItem) => p.id === selected) || this.projects[0];
    if (!project) { throw new Error('当前 Mac 没有已授权项目，暂时无法同步扩展'); }
    const generation: number = ++this.extensionGeneration; const mac: string = this.fingerprint;
    this.extensionSyncing = true; this.extensionLoading = true; this.extensionSyncStatus = '';
    try {
      const scope: string = project.id === selected && thread ? '&threadId=' + encodeURIComponent(thread) : '';
      const result = await this.rpc.request<ExtensionPage>('GET', '/v1/extensions?projectId=' + encodeURIComponent(project.id) + scope + '&refresh=true', undefined, this.authorization());
      if (generation !== this.extensionGeneration || mac !== this.fingerprint || !this.authenticated || selected !== this.selectedProjectId || thread !== this.selectedThreadId) { return; }
      if (!result.refreshed || result.skillCount === undefined || result.pluginCount === undefined) { throw new Error('当前 Mac 网关尚不支持手动同步，请先更新网关'); }
      this.extensionItems = result.items; this.extensionTotal = result.total;
      this.extensionIconVersion++;
      this.references = this.references.map((ref: ExtensionItem) => result.items.find((item: ExtensionItem) => item.id === ref.id) || ref);
      this.extensionSyncStatus = '已同步：' + result.skillCount + ' 个 Skill、' + result.pluginCount + ' 个插件' + (result.browserCount ? '、' + result.browserCount + ' 个浏览器入口' : '');
    } finally { this.extensionSyncing = false; if (generation === this.extensionGeneration) { this.extensionLoading = false; } }
  }
  async toggleReference(item: ExtensionItem): Promise<void> {
    if (this.busy) { throw new Error('请等待当前提交完成'); }
    if (this.references.some((r: ExtensionItem) => r.id === item.id)) { this.references = this.references.filter((r: ExtensionItem) => r.id !== item.id); }
    else { if (this.references.length >= 8) { throw new Error('最多选择 8 个插件或 skill'); } this.references = [...this.references, item]; }
    const key: string = 'refs.' + this.draftKey(); const value: string = JSON.stringify(this.references);
    this.draftWrites = this.draftWrites.catch(() => {}).then(async () => { await this.identity.put(key, value); }); await this.draftWrites;
  }
  private async saveImages(): Promise<void> {
    const key: string = 'images.' + this.draftKey(); const value: string = JSON.stringify(this.attachments);
    this.draftWrites = this.draftWrites.catch(() => {}).then(async () => { await this.identity.put(key, value); }); await this.draftWrites;
  }
  async pickImages(): Promise<void> {
    if (this.busy || !this.canControlProject) { throw new Error('请先选择可执行项目，并等待当前操作完成'); }
    if (this.attachments.length >= 4) { throw new Error('每条消息最多发送 4 张图片'); }
    if (!this.attachmentRoot) { throw new Error('图片存储尚未就绪'); }
    this.busy = true;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions(); options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 4 - this.attachments.length;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      for (const uri of result.photoUris.slice(0, options.maxSelectNumber)) { const item = await this.prepareImage(uri); if (this.attachments.reduce((n: number, current: DraftImage) => n + current.size, 0) + item.size > 8388608) { this.deleteImageFile(item); throw new Error('每条消息的图片合计不能超过 8 MiB，请减少图片'); } this.attachments = [...this.attachments, item]; await this.saveImages(); }
    } finally { this.busy = false; }
  }
  private async prepareImage(uri: string): Promise<DraftImage> {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    let source: image.ImageSource | undefined; let pixels: image.PixelMap | undefined; let packer: image.ImagePacker | undefined;
    try {
      source = image.createImageSource(file.fd); const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0 || info.size.width * info.size.height > 100000000) { throw new Error('图片尺寸过大，请先裁剪后重试'); }
      const ratio: number = Math.min(1, 2560 / Math.max(info.size.width, info.size.height));
      pixels = await source.createPixelMap({ desiredSize: { width: Math.max(1, Math.round(info.size.width * ratio)), height: Math.max(1, Math.round(info.size.height * ratio)) } });
      packer = image.createImagePacker(); const bytes = await packer.packing(pixels, { format: 'image/jpeg', quality: 90 });
      if (bytes.byteLength === 0 || bytes.byteLength > 8388608) { throw new Error('图片处理后仍超过 8 MiB，请裁剪后重试'); }
      const md = cryptoFramework.createMd('SHA256'); await md.update({ data: new Uint8Array(bytes) });
      const id: string = hex((await md.digest()).data.slice().buffer as ArrayBuffer) + '_' + encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer); const path: string = this.attachmentRoot + '/' + id + '.jpg';
      const output = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      try { let offset: number = 0; while (offset < bytes.byteLength) { const written: number = await fileIo.write(output.fd, bytes.slice(offset)); if (written <= 0) { throw new Error('图片保存失败'); } offset += written; } }
      catch (error) { try { fileIo.unlinkSync(path); } catch (_) {} throw error as Error; }
      finally { await fileIo.close(output); }
      return { id: id, path: path, uri: fileUri.getUriFromPath(path), size: bytes.byteLength, mime: 'image/jpeg' };
    } finally { if (packer) { await packer.release(); } if (pixels) { await pixels.release(); } if (source) { await source.release(); } await fileIo.close(file); }
  }
  async removeImage(id: string): Promise<void> {
    if (this.busy || (this.pendingSend && this.pendingSend.threadId === this.selectedThreadId && this.pendingSend.projectId === this.selectedProjectId)) { throw new Error('请先等待发送结果确认'); }
    const removed = this.attachments.find((item: DraftImage) => item.id === id); if (!removed) { return; }
    this.attachments = this.attachments.filter((item: DraftImage) => item.id !== id); await this.saveImages(); this.deleteImageFile(removed);
    if (this.authenticated) { const body: RemoveImagesBody = { projectId: this.selectedProjectId, images: [id] }; this.rpc.request<Object>('POST', '/v1/images/remove', body, this.authorization()).catch(() => {}); }
  }
  private deleteImageFile(item: DraftImage): void { if (this.attachmentRoot && /^[a-f0-9]{64}_[A-Za-z0-9_-]{22}$/.test(item.id) && item.path === this.attachmentRoot + '/' + item.id + '.jpg') { try { fileIo.unlinkSync(item.path); } catch (_) {} } }
  private async uploadImages(project: string, items: DraftImage[]): Promise<void> {
    if (!items.length) { return; } this.uploadProgress = 0;
    const total: number = items.reduce((n: number, item: DraftImage) => n + item.size, 0); let completed: number = 0;
    for (const item of items) {
      if (!this.attachmentRoot || !/^[a-f0-9]{64}_[A-Za-z0-9_-]{22}$/.test(item.id) || item.path !== this.attachmentRoot + '/' + item.id + '.jpg' || item.size <= 0 || item.size > 8388608) { throw new Error('待发送图片无效，请重新选择'); }
      const file = await fileIo.open(item.path, fileIo.OpenMode.READ_ONLY);
      try {
        if ((await fileIo.stat(file.fd)).size !== item.size) { throw new Error('待发送图片已变化，请重新选择'); }
        let offset: number = 0;
        while (offset < item.size) {
          fileIo.lseek(file.fd, offset, fileIo.WhenceType.SEEK_SET); const bytes = new ArrayBuffer(Math.min(131072, item.size - offset)); const count: number = await fileIo.read(file.fd, bytes);
          if (count !== bytes.byteLength) { throw new Error('图片读取不完整，请重新选择'); }
          const body: ImageUploadBody = { projectId: project, imageId: item.id, offset: offset, totalBytes: item.size, mime: item.mime, data: encode(bytes) };
          const result = await this.rpc.request<ImageUploadResult>('POST', '/v1/images/upload', body, this.authorization());
          if (result.imageId !== item.id || !Number.isInteger(result.nextOffset) || result.nextOffset < offset + count || result.nextOffset > item.size) { throw new Error('图片上传回执无效，请重试'); }
          offset = result.nextOffset; this.uploadProgress = Math.round((completed + offset) * 100 / total);
        }
      } finally { await fileIo.close(file); }
      completed += item.size;
    }
  }
  private async restoreReferences(): Promise<void> {
    this.extensionGeneration++; this.extensionItems = []; this.extensionTotal = 0; this.extensionLoading = false; this.extensionSyncStatus = ''; const value: string = await this.identity.get('refs.' + this.draftKey()); this.references = value ? JSON.parse(value) as ExtensionItem[] : [];
    const images: string = await this.identity.get('images.' + this.draftKey()); this.attachments = images ? JSON.parse(images) as DraftImage[] : [];
  }
  loadImage(ref: ImageReference): Promise<string> {
    const project: string = this.selectedProjectId;
    return this.loadCachedImage(ref.id, project, '/v1/threads/' + ref.threadId + '/media?projectId=' + encodeURIComponent(project) + '&turnId=' + encodeURIComponent(ref.turnId) + '&itemId=' + encodeURIComponent(ref.itemId) + '&index=' + ref.index);
  }
  loadExtensionIcon(item: ExtensionItem): Promise<string> {
    if (!item.iconId || !this.selectedProjectId) { return Promise.reject(new Error('扩展没有可用图标')); }
    const project: string = this.selectedProjectId;
    return this.loadCachedImage('ext:' + item.iconId + ':' + this.appearance + ':' + this.extensionIconVersion, project, '/v1/extensions/' + encodeURIComponent(item.id) + '/icon?projectId=' + encodeURIComponent(project) + (this.selectedThreadId ? '&threadId=' + encodeURIComponent(this.selectedThreadId) : '') + '&theme=' + this.appearance, true);
  }
  private loadCachedImage(id: string, project: string, endpoint: string, icon: boolean = false): Promise<string> {
    const mac: string = this.fingerprint; const key: string = (icon ? 'ext-' : '') + hex(native.sha256(utf8(mac + ':' + project + ':' + id)));
    const cached: string | undefined = this.imageCache.get(key); if (cached) { this.imageCache.delete(key); this.imageCache.set(key, cached); return Promise.resolve(fileUri.getUriFromPath(cached)); }
    const pending: Promise<string> | undefined = this.imageTasks.get(key); if (pending) { return pending; }
    const result: Promise<string> = this.imageWrites.then(async (): Promise<string> => {
      if (!this.imageRoot || !this.authenticated || project !== this.selectedProjectId || mac !== this.fingerprint) { throw new Error('图片缓存或连接不可用，请重新打开图片'); }
      let offset: number = 0; let version: string = ''; let file: fileIo.File | undefined; let path: string = '';
      try { while (true) {
        if (project !== this.selectedProjectId || mac !== this.fingerprint) { throw new Error('项目或 Mac 已切换'); }
        const chunk = await this.rpc.request<ImageChunk>('GET', endpoint + '&offset=' + offset + (version ? '&version=' + version : ''), undefined, this.authorization());
        if (project !== this.selectedProjectId || mac !== this.fingerprint) { throw new Error('项目或 Mac 已切换'); }
        if (chunk.totalBytes > (icon ? 2097152 : 8388608) || (version && version !== chunk.version) || (!['image/png', 'image/jpeg', 'image/gif', 'image/webp'].includes(chunk.mime) && !(icon && chunk.mime === 'image/svg+xml'))) { throw new Error('图片过大、格式不受支持或内容已变化'); }
        if (!file) { const ext: string = chunk.mime === 'image/jpeg' ? 'jpg' : chunk.mime === 'image/svg+xml' ? 'svg' : chunk.mime.slice(6); path = this.imageRoot + '/' + key + '.' + ext; file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC); }
        const bytes: ArrayBuffer = decode(chunk.data); let written: number = 0; while (written < bytes.byteLength) { const count: number = fileIo.writeSync(file.fd, bytes.slice(written)); if (count <= 0) { throw new Error('图片缓存写入失败'); } written += count; }
        version = chunk.version; offset += bytes.byteLength; if (this.selectedImageId === id) { this.imageProgress = Math.round(offset * 100 / Math.max(1, chunk.totalBytes)); }
        if (chunk.nextOffset === undefined || chunk.nextOffset === null) { if (offset !== chunk.totalBytes) { throw new Error('图片传输不完整'); } break; }
        if (chunk.nextOffset !== offset || bytes.byteLength === 0) { throw new Error('图片分段位置无效'); }
      }
      } catch (error) { if (file) { fileIo.closeSync(file); file = undefined; } if (path) { try { fileIo.unlinkSync(path); } catch (_) {} } throw error as Error; }
      finally { if (file) { fileIo.closeSync(file); } }
      this.imageCache.set(key, path); if (this.imageCache.size > 32) { const oldest: string = Array.from(this.imageCache.keys())[0]; const old: string | undefined = this.imageCache.get(oldest); this.imageCache.delete(oldest); if (old) { try { fileIo.unlinkSync(old); } catch (_) {} } }
      return fileUri.getUriFromPath(path);
    });
    this.imageWrites = result.then(() => {}, () => {}); this.imageTasks.set(key, result); result.then(() => { this.imageTasks.delete(key); }, () => { this.imageTasks.delete(key); }); return result;
  }
  async readImage(ref: ImageReference): Promise<void> { this.selectedImageId = ref.id; this.imageUri = ''; this.imageLabel = ref.label; this.imageProgress = 0; this.imageLoading = true; try { const uri: string = await this.loadImage(ref); if (this.selectedImageId === ref.id) { this.imageUri = uri; } } finally { if (this.selectedImageId === ref.id) { this.imageLoading = false; } } }
  async loadModelSettings(): Promise<void> {
    const thread: string = this.selectedThreadId; const project: string = this.selectedProjectId; if (!thread || !this.authenticated) { return; }
    const value = await this.rpc.request<ModelSettings>('GET', '/v1/threads/' + thread + '/model?projectId=' + encodeURIComponent(project), undefined, this.authorization());
    if (this.selectedThreadId === thread && this.selectedProjectId === project) { this.selectedModel = value.model; this.selectedEffort = value.effort; this.selectedServiceTier = value.serviceTier || ''; this.modelDetail = value.model + ' · ' + (value.effort || '默认'); }
  }
  async applyModel(model: string, effort: string, serviceTier?: string): Promise<void> {
    if (this.busy) { throw new Error('请等待当前操作完成'); }
    if (!this.canControlProject) { throw new Error('仅可在可执行项目修改模型设置'); }
    if (serviceTier === undefined && (this.selectedServiceTier === 'priority' || this.selectedServiceTier === 'fast')) { serviceTier = this.models.find((m: ModelItem) => m.model === model)?.fastTier || ''; }
    this.busy = true;
    try {
      if (this.selectedThreadId) {
        const body: ModelSettingsBody = { projectId: this.selectedProjectId, threadId: this.selectedThreadId, model: model, effort: effort, serviceTier: serviceTier === undefined ? undefined : serviceTier || null };
        const applied = await this.rpc.request<ModelSettings>('POST', '/v1/threads/model', body, this.authorization());
        model = applied.model; effort = applied.effort; serviceTier = applied.serviceTier || '';
      }
      this.selectedModel = model; this.selectedEffort = effort; if (serviceTier !== undefined) { this.selectedServiceTier = serviceTier; } this.modelDetail = model + ' · ' + effort + (this.selectedThreadId ? ' · 已应用' : ' · 用于新任务');
    } finally { this.busy = false; }
  }
  private draftHash(project: string, thread: string, value: string, refs: string[], images: string[] = []): string { return hex(native.sha256(utf8(JSON.stringify(images.length ? [project, thread, value, refs, images] : refs.length ? [project, thread, value, refs] : [project, thread, value])))); }
  private async acknowledgeDraft(sourceKey: string, hash: string, project: string, thread: string): Promise<void> {
    const currentKey: string = this.draftKey(); const keys: string[] = sourceKey !== currentKey ? [sourceKey] : [];
    const matches: boolean = this.selectedProjectId === project && this.selectedThreadId === thread && this.draftHash(project, thread, this.draft, this.references.map((r: ExtensionItem) => r.id), this.attachments.map((item: DraftImage) => item.id)) === hash;
    if (matches) { keys.push(currentKey); }
    if (keys.length) { const write = this.draftWrites.catch(() => {}).then(async () => { for (const key of keys) { const saved: string = await this.identity.get('images.' + key); await this.identity.put(key, ''); await this.identity.put('refs.' + key, ''); await this.identity.put('images.' + key, ''); if (saved) { for (const item of JSON.parse(saved) as DraftImage[]) { if (!this.attachments.some((current: DraftImage) => current.id === item.id)) { this.deleteImageFile(item); } } } } }); this.draftWrites = write; if (matches) { this.draft = ''; this.references = []; this.attachments = []; } await write; }
  }
  private draftKey(): string { return 'draft.' + this.selectedProjectId + '.' + (this.selectedThreadId || 'new'); }
  async updateDraft(value: string): Promise<void> {
    this.draft = value; const key = this.draftKey();
    this.draftWrites = this.draftWrites.catch(() => {}).then(async () => { await this.identity.put(key, value); });
    await this.draftWrites;
  }
  async saveSuggestionSetting(enabled: boolean): Promise<void> { this.nextSuggestionEnabled = enabled; await this.identity.put('nextSuggestionEnabled', enabled ? 'true' : 'false'); }
  async acceptSuggestion(): Promise<void> { if (this.showSuggestion && !this.busy) { await this.updateDraft(this.suggestionText); } }
  private updateSuggestion(snapshot: Snapshot): void {
    const latest: string = snapshot.backend.latestTurnId || ''; this.suggestionTurnId = latest;
    const suggestion: SuggestionView | undefined = snapshot.suggestion;
    this.suggestionText = !this.currentTurnId && suggestion?.sourceTurnId === latest ? suggestion.text : '';
    this.suggestionState = !this.currentTurnId && suggestion?.sourceTurnId === latest ? suggestion.state : 'idle';
    const key: string = this.connectionVersion + ':' + this.selectedThreadId + ':' + latest;
    if (!this.nextSuggestionEnabled || !latest || this.currentTurnId || this.hasDraftContent || this.queueMessages.length > 0 || this.pendingSend || !this.canExecute || this.suggestionState !== 'idle' || this.suggestionPending || this.suggestionRequestKey === key) { return; }
    const project: string = this.selectedProjectId; const thread: string = this.selectedThreadId; const generation: number = this.generation;
    this.suggestionPending = true; this.suggestionRequestKey = key;
    const body: SuggestionBody = { projectId: project, sourceTurnId: latest };
    Promise.resolve().then(() => this.rpc.request<SuggestionView>('POST', '/v1/threads/' + thread + '/suggestion', body, this.authorization())).then((value: SuggestionView) => {
      if (generation !== this.generation || thread !== this.selectedThreadId || project !== this.selectedProjectId || this.currentTurnId || this.suggestionTurnId !== latest || value.sourceTurnId !== latest) { return; }
      if (value.state === 'busy') { this.suggestionRequestKey = ''; return; }
      this.suggestionState = value.state; this.suggestionText = value.text;
    }).catch(() => { if (generation === this.generation && thread === this.selectedThreadId) { this.suggestionRequestKey = ''; } }).finally(() => { this.suggestionPending = false; });
  }
  async saveProjectCreationPath(path: string): Promise<void> {
    const value: string = path.trim();
    if (!value || value.length > 4096 || /[\x00-\x1f\x7f]/.test(value) || !(value.startsWith('/') || value === '~' || value.startsWith('~/'))) { throw new Error('请输入 Mac 绝对路径或 ~/ 开头的路径'); }
    if (!this.mac) { throw new Error('请先连接 Mac'); }
    const generation: number = this.generation;
    await this.identity.put('projectCreationPath.' + this.mac.gatewayId, value); this.checkGeneration(generation);
    this.projectCreationPath = value;
  }
  async createProject(name: string): Promise<void> {
    if (this.busy || !this.authenticated) { throw new Error('请先连接 Mac，等待当前操作完成'); }
    if (this.newProjectCapability !== 'control') { throw new Error('请先在 Mac 将此设备的新项目权限设为自动可执行'); }
    const title: string = name.trim();
    if (!title || title === '.' || title === '..' || /[\\/\x00-\x1f\x7f]/.test(title)) { throw new Error('请输入有效项目名称，不能包含路径分隔符'); }
    this.busy = true;
    try {
      const generation: number = this.generation;
      const parentPath: string = this.projectCreationPath;
      const md = cryptoFramework.createMd('SHA256'); await md.update({ data: new Uint8Array(utf8(JSON.stringify([this.mac!.gatewayId, parentPath, title]))) }); this.checkGeneration(generation);
      const storageKey: string = 'createProject.' + hex((await md.digest()).data.slice().buffer as ArrayBuffer); this.checkGeneration(generation);
      let requestId: string = await this.identity.get(storageKey); this.checkGeneration(generation);
      if (!requestId) { requestId = encode(cryptoFramework.createRandom().generateRandomSync(16).data.slice().buffer as ArrayBuffer); await this.identity.put(storageKey, requestId); this.checkGeneration(generation); }
      const body: CreateProjectBody = { name: title, requestId: requestId, parentPath: parentPath };
      const project = await this.rpc.request<ProjectItem>('POST', '/v1/projects', body, this.authorization()); this.checkGeneration(generation);
      this.projects = [...this.projects.filter((p: ProjectItem) => p.id !== project.id), project];
      this.selectedProjectId = project.id;
    } finally { this.busy = false; }
    await this.createThread();
    await this.refreshNavigation();
  }
  async createThread(): Promise<void> {
    if (this.busy || !this.selectedProjectId) { throw new Error('请先选择项目'); }
    if (!this.projects.some((p: ProjectItem) => p.id === this.selectedProjectId && p.capability === 'control')) { throw new Error('只读项目不能创建任务'); }
    this.permissionMode = 'ask'; this.permissionMobileControl = true; this.fullAccessConfirmed = false;
    this.lastSubmissionId = ''; this.lastMessageState = ''; this.lastPendingText = '';
    this.olderMessages = []; this.historyCursor = ''; this.changes = undefined; this.diffReview = undefined; this.suggestionText = ''; this.suggestionState = 'idle'; this.suggestionTurnId = ''; this.selectedThreadId = ''; this.selectedThreadName = '新任务'; this.messages = []; this.queueMessages = []; this.approvals = []; this.currentTurnId = ''; this.draft = await this.identity.get(this.draftKey()); await this.restoreReferences();
  }
  async selectProject(projectId: string): Promise<void> {
    if (this.busy) { throw new Error('操作尚未完成'); }
    this.busy = true;
    try {
      const page = await this.rpc.request<ThreadPage>('GET', `/v1/threads?projectId=${encodeURIComponent(projectId)}`, undefined, this.authorization());
      this.selectedProjectId = projectId; this.changes = undefined; this.diffReview = undefined; this.suggestionText = ''; this.suggestionState = 'idle'; this.threads = page.data; this.selectedThreadId = ''; this.permissionMode = 'ask'; this.permissionMobileControl = true; this.fullAccessConfirmed = false; this.selectedThreadName = this.projects.some((p: ProjectItem) => p.id === projectId && p.capability === 'control') ? '新任务' : '项目会话'; this.messages = []; this.queueMessages = []; this.olderMessages = []; this.historyCursor = ''; this.approvals = []; this.currentTurnId = ''; this.lastSubmissionId = ''; this.lastMessageState = ''; this.lastPendingText = ''; this.draft = await this.identity.get(this.draftKey()); await this.restoreReferences();
    } finally { this.busy = false; }
  }
  async selectThread(thread: ThreadItem): Promise<void> {
    if (this.busy) { throw new Error('操作尚未完成'); }
    this.busy = true;
    try { this.queueMessages = []; this.lastSubmissionId = ''; this.lastMessageState = ''; this.lastPendingText = ''; this.approvals = []; this.currentTurnId = ''; this.olderMessages = []; this.historyCursor = ''; this.changes = undefined; this.diffReview = undefined; this.suggestionText = ''; this.suggestionState = 'idle'; this.suggestionTurnId = ''; this.selectedThreadId = thread.id; this.selectedThreadName = thread.name; this.selectedModel = thread.model || ''; this.selectedEffort = ''; this.selectedServiceTier = ''; this.modelDetail = thread.model || '沿用会话模型'; this.draft = await this.identity.get(this.draftKey()); await this.restoreReferences(); await this.loadHistory(); await this.loadModelSettings(); await this.loadPermissions(); }
    finally { this.busy = false; }
  }
  async refresh(): Promise<void> {
    if (this.busy || this.refreshing) { return; } this.refreshing = true;
    try { await this.loadHistory(); } finally { this.refreshing = false; }
  }
  async openChanges(turnId: string): Promise<void> {
    if (!this.selectedThreadId || !turnId || this.diffLoading) { return; }
    const thread: string = this.selectedThreadId; const project: string = this.selectedProjectId;
    this.diffLoading = true;
    try { const review = await this.rpc.request<ChangeSummary>('GET', '/v1/threads/' + thread + '/changes?projectId=' + encodeURIComponent(project) + '&turnId=' + encodeURIComponent(turnId), undefined, this.authorization());
      if (thread !== this.selectedThreadId || project !== this.selectedProjectId) { return; }
      this.diffReview = review; this.diffFileId = ''; this.diffText = ''; this.diffMore = false;
    } finally { this.diffLoading = false; }
    if (this.diffReview?.files.length) { await this.selectDiffFile(this.diffReview.files[0].id); }
  }
  async selectDiffFile(fileId: string): Promise<void> {
    if (this.diffLoading || !this.diffReview?.files.some((f) => f.id === fileId)) { return; }
    this.diffFileId = fileId; this.diffText = ''; this.diffOffset = 0; this.diffMore = true; await this.loadMoreDiff();
  }
  async loadMoreDiff(): Promise<void> {
    if (this.diffLoading || !this.diffMore || !this.diffReview) { return; }
    const thread: string = this.selectedThreadId; const file: string = this.diffFileId; const version: string = this.diffReview.version; this.diffLoading = true;
    try { const chunk = await this.rpc.request<DiffChunk>('GET', '/v1/threads/' + thread + '/diff?projectId=' + encodeURIComponent(this.selectedProjectId) + '&turnId=' + encodeURIComponent(this.diffReview.turnId) + '&fileId=' + encodeURIComponent(file) + '&version=' + encodeURIComponent(version) + '&offset=' + this.diffOffset, undefined, this.authorization());
      if (thread !== this.selectedThreadId || file !== this.diffFileId || version !== this.diffReview?.version) { return; }
      this.diffText += chunk.text; this.diffOffset = chunk.nextOffset ?? chunk.totalChars; this.diffMore = chunk.nextOffset !== undefined && chunk.nextOffset !== null;
    } finally { this.diffLoading = false; }
  }
  private async loadHistory(): Promise<void> {
    if (!this.selectedProjectId || !this.selectedThreadId || !this.projects.some((p: ProjectItem) => p.id === this.selectedProjectId)) { return; }
    const projectAtStart: string = this.selectedProjectId; const threadAtStart: string = this.selectedThreadId;
    const suffix: string = `?projectId=${encodeURIComponent(projectAtStart)}`;
    const snapshot = await this.rpc.request<Snapshot>('GET', `/v1/threads/${this.selectedThreadId}/view${suffix}`, undefined, this.authorization());
    if (this.selectedProjectId !== projectAtStart || this.selectedThreadId !== threadAtStart) { return; }
    this.changes = snapshot.changes;
    if (snapshot.backend.name && this.selectedThreadName !== snapshot.backend.name) { this.selectedThreadName = snapshot.backend.name; if (!this.busy) { this.refreshNavigation().catch(() => {}); } }
    this.asyncQuestions = snapshot.asyncQuestions || [];
    this.approvals = [...snapshot.approvals, ...this.asyncQuestions.filter((q: ApprovalItem) => !q.answered)];
    this.queueMessages = snapshot.messages.filter((m: SnapshotMessage) => ['queued', 'dispatching', 'nativeQueued', 'unknown'].includes(m.state));
    if (snapshot.backend.permissions) { this.permissionMode = snapshot.backend.permissions.mode; this.permissionMobileControl = snapshot.backend.permissions.mobileControl; this.fullAccessConfirmed = this.permissionMode === 'full' && this.permissionMobileControl; }
    this.currentTurnId = snapshot.backend.turnId || ''; this.waiting = snapshot.backend.waiting;
    this.activityTitle = this.currentTurnId ? snapshot.activityTitle || (snapshot.history.activityTurnId === this.currentTurnId ? snapshot.history.activityTitle || '' : '') : '';
    if (this.pendingSend !== undefined && this.pendingSend.projectId === this.selectedProjectId && this.pendingSend.threadId === this.selectedThreadId) {
      const id: string = this.pendingSend.id;
      const recovered = snapshot.messages.find((m: SnapshotMessage) => m.client_id === id);
      if (recovered !== undefined) {
        this.lastSubmissionId = recovered.id; this.lastMessageState = recovered.state;
        await this.acknowledgeDraft(this.pendingSend.draftKey || this.draftKey(), this.pendingSend.hash, projectAtStart, threadAtStart);
        await this.identity.put('pendingSend', ''); this.pendingSend = undefined;
      }
    }
    const pending = snapshot.messages.find((m: SnapshotMessage) => m.id === this.lastSubmissionId);
    if (pending !== undefined) { this.lastMessageState = pending.state; }
    const history = snapshot.history;
    if (this.olderMessages.length === 0) { this.historyCursor = history.nextCursor || ''; }
    const latest: MessageView[] = this.historyMessages(history);
    const result: MessageView[] = [...this.olderMessages.filter((m: MessageView) => !latest.some((n: MessageView) => n.id === m.id)), ...latest];
    snapshot.progress.forEach((live: LiveProgress) => {
      // Persisted history is authoritative once a turn ends; old previews must not reappear below it.
      if (!snapshot.backend.turnId || live.turnId !== snapshot.backend.turnId) { return; }
      const existing = result.findIndex((m: MessageView) => m.id === live.id);
      if (existing < 0 && !['running', 'waiting', 'pending'].includes(live.status)) { return; }
      if (live.status === 'running' || existing < 0) {
        const view = new MessageView(live.id, live.role, live.text + (live.truncated ? '\n[较长输出仅显示末尾，完整内容请查看历史]' : ''), live.status);
        view.execution = live.execution;
        view.images = live.images?.length ? live.images : (existing >= 0 ? result[existing].images : []);
        view.itemId = existing >= 0 ? result[existing].itemId : live.id;
        view.turnId = view.images[0]?.turnId || (existing >= 0 ? result[existing].turnId : '');
        if (existing >= 0) { result[existing] = view; } else { result.push(view); }
      }
    });
    if (this.selectedProjectId === projectAtStart && this.selectedThreadId === threadAtStart) { this.messages = result; this.updateSuggestion(snapshot); }
  }
  private historyMessages(history: HistoryPage): MessageView[] {
    const result: MessageView[] = [];
    history.data.slice().reverse().forEach((turn: HistoryTurn) => {
      turn.items.forEach((item: HistoryItem) => {
        const before: number = result.length;
        if (item.type === 'userMessage' && item.content !== undefined) {
          const content = item.content.filter((c: TextInputItem) => c.type === 'text').map((c: TextInputItem) => c.text || '').join('\n');
          result.push(new MessageView(item.clientId || item.id, 'user', content));
        } else if (item.type === 'agentMessage' && item.text) {
          result.push(new MessageView(item.id, 'assistant', item.text));
        } else if (item.type === 'commandExecution') {
          result.push(new MessageView(item.id, 'tool', item.execution?.kind === 'image' ? '' : `${item.command || '工具执行'}\n${(item.aggregatedOutput || '').slice(0, 4000)}`));
        }
        if (result.length > before) { const view: MessageView = result[result.length - 1]; view.question = item.asyncQuestion ? this.asyncQuestions.find((q: ApprovalItem) => q.id === item.asyncQuestion?.id) || item.asyncQuestion : undefined; view.images = item.images || []; view.itemId = item.id || ''; view.turnId = turn.id; view.hasMore = item.truncated === true; view.execution = item.execution; if (item.execution) { view.status = item.execution.status; } }
      });
    });
    return result;
  }
  async loadOlder(): Promise<void> {
    if (this.busy || !this.historyCursor) { return; } this.busy = true;
    try {
      const page = await this.rpc.request<HistoryPage>('GET', '/v1/threads/' + this.selectedThreadId + '/history-page?projectId=' + encodeURIComponent(this.selectedProjectId) + '&cursor=' + encodeURIComponent(this.historyCursor), undefined, this.authorization());
      const older = this.historyMessages(page); this.historyCursor = page.nextCursor || '';
      this.olderMessages = [...older.filter((m: MessageView) => !this.olderMessages.some((n: MessageView) => n.id === m.id)), ...this.olderMessages];
      this.messages = [...older.filter((m: MessageView) => !this.messages.some((n: MessageView) => n.id === m.id)), ...this.messages];
    } finally { this.busy = false; }
  }
  async readMessage(message: MessageView): Promise<void> { this.readingMessage = message; this.readingChunks = []; this.readingOffset = 0; this.readingTotal = 0; this.readingMore = true; await this.readNextChunk(); }
  async readNextChunk(): Promise<void> {
    if (this.busy || !this.readingMessage || !this.readingMore) { return; } this.busy = true;
    try {
      const item: MessageView = this.readingMessage;
      const path: string = '/v1/threads/' + this.selectedThreadId + '/history-item?projectId=' + encodeURIComponent(this.selectedProjectId) + '&turnId=' + encodeURIComponent(item.turnId) + '&itemId=' + encodeURIComponent(item.itemId) + '&offset=' + this.readingOffset;
      const chunk = await this.rpc.request<HistoryChunk>('GET', path, undefined, this.authorization());
      this.readingChunks = [...this.readingChunks, chunk.text]; this.readingTotal = chunk.totalChars; this.readingMore = chunk.nextOffset !== undefined && chunk.nextOffset !== null; this.readingOffset = chunk.nextOffset || chunk.totalChars;
    } finally { this.busy = false; }
  }
  pauseConnection(): void { this.reconnectEnabled = false; this.disconnect(); }
  disconnect(): void { clearTimeout(this.retryTimer); this.recovering = false; ++this.generation; this.rpc.close(); this.clearConnection(); this.projects = []; this.queueMessages = []; this.status = '未连接'; this.detail = '草稿不会自动提交，重新连接后恢复身份'; }
}
export const mobileSession: MobileSession = new MobileSession();
