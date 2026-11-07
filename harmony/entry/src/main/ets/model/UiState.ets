import { MIN_GATEWAY_VERSION } from './GatewayCompatibility';
import { AgentRuntime, AgentCommand } from './UiTypes';
import { DEFAULT_AGENT, findAgent, AgentInfo } from './Agents';
import { UploadLimits, BackendCapabilities, ThreadAction, PermissionOption, ChangeSummary, DraftImage, ExtensionItem, PermissionState, ImageReference, ThreadManagementRequest, ProjectManagementRequest } from './UiTypes';
import { common } from '@kit.AbilityKit';
import { PairMaterial, KnownMac, ClaimResult, ClaimBody, ProofBody, LoginBody, LoginProof, PairStatus, LoginResult, ProjectItem, ThreadItem, ThreadPage, SnapshotBackend, SnapshotMessage, ExecutionSummary, LiveProgress, Snapshot, TextInputItem, HistoryItem, HistoryTurn, HistoryPage, HistoryChunk, MessageView, MessagePayload, PendingSend, SendBody, QueuedMessage, SteerBody, OperationResult, QuestionOption, QuestionItem, QuestionAnswer, QuestionReplyBody, ApprovalItem, ApprovalReplyBody, ApprovalReplyResult, InterruptBody, InterruptResult, CancelBody, NavigationThread, NavigationProject, NavigationSection, NavigationData, ModelItem, ModelSettings, ModelSettingsBody, CreateThreadBody, BackendStatus } from './UiTypes';
export * from './UiTypes';

@Observed
export abstract class UiState {
  runtime: AgentRuntime = {};
  commandFeedback: string = '';
  commandPending: boolean = false;
  get agentCommands(): AgentCommand[] { return this.capabilities.commands || []; }
  get contextPercent(): number { const c = this.runtime.context; return c && Number.isFinite(c.used) && c.used >= 0 && Number.isFinite(c.limit) && c.limit > 0 ? Math.min(100, Math.round(c.used / c.limit * 100)) : -1; }
  get goalLabel(): string {
    const goal = this.runtime.goal;
    if (!goal) { return ''; }
    if (goal.status === 'active') { return goal.automatic === false ? '目标已设置 · 未自动推进' : '目标进行中'; }
    if (goal.status === 'paused') { return '目标已暂停'; }
    if (goal.status === 'blocked') { return '目标受阻'; }
    if (goal.status === 'complete') { return '目标已完成'; }
    if (goal.status === 'cancelled') { return '目标已取消'; }
    if (goal.status === 'budgetLimited') { return '目标预算已用尽'; }
    if (goal.status === 'usageLimited') { return '目标用量受限'; }
    return '目标状态待同步';
  }
  get planLabel(): string {
    const plan = this.runtime.plan;
    if (!plan) { return ''; }
    if (plan.workflow) { return '本次计划请求 · 阶段待同步'; }
    return plan.pending ? (plan.active ? '计划模式 · 待退出' : '计划模式 · 待启用') : plan.active ? '计划模式' : '';
  }
  get hasGoalMode(): boolean { return !!this.runtime.goal && !['complete', 'cancelled'].includes(this.runtime.goal.status); }
  get hasAgentMode(): boolean { return this.hasGoalMode || !!this.planLabel; }
  abstract runAgentCommand(action: string, argument?: string, fromDraft?: boolean): Promise<void>;
  selectedAgent: string = DEFAULT_AGENT.id;
  get agent(): AgentInfo { return findAgent(this.selectedAgent) || DEFAULT_AGENT; }
  get containerName(): string { return this.agent.containerName; }
  get agentName(): string { return this.agent.name; }
  abstract switchAgent(kind: string): Promise<void>;
  get activeContainerName(): string {
    const current = this.navigation?.recentThreads?.find((t: NavigationThread) => t.id === this.selectedThreadId);
    const section = this.navigation?.sections.find((s: NavigationSection) => (s.threads || []).some((t: NavigationThread) => t.id === this.selectedThreadId) || (s.id === current?.sectionId && s.projects.length === 0));
    return section?.name || this.projects.find((p: ProjectItem) => p.id === this.selectedProjectId)?.name || '';
  }
  gatewayVersion: string = '';
  readonly minimumGatewayVersion: string = MIN_GATEWAY_VERSION;
  backendKind: string = '';
  uploadLimits: UploadLimits = { fileBytes: 8388608, imageBytes: 8388608, messageBytes: 8388608, maxAttachments: 4, chunkBytes: 131072 };
  get threadActions(): ThreadAction[] {
    return this.capabilities.threadActions || (this.selectedAgent === 'codex' ? [{ action: 'rename', label: '重新命名' }, { action: 'pin', label: '固定', activeLabel: '取消固定' }, { action: 'project', label: '项目' }, { action: 'section', label: '分区' }, { action: 'archive', label: '封存' }] : []);
  }
  capabilities: BackendCapabilities = { modelSettings: false, permissions: false, suggestions: false, steer: false, images: false, extensions: false, changes: false };
  activityTitle: string = '';
  runtimeStatusKnown: boolean = true;
  permissionScope: string = 'conversation';
  projectCreationPath: string = '~/workspace';
  abstract saveProjectCreationPath(path: string): Promise<void>;
  newProjectCapability: string = 'none';
  nextSuggestionEnabled: boolean = true;
  suggestionText: string = '';
  suggestionState: string = 'idle';
  get showSuggestion(): boolean { return this.capabilities.suggestions && this.nextSuggestionEnabled && this.suggestionState === 'ready' && this.suggestionText.length > 0 && !!this.selectedThreadId && !this.currentTurnId && !this.hasDraftContent && this.canExecute; }
  abstract saveSuggestionSetting(enabled: boolean): Promise<void>;
  abstract acceptSuggestion(): Promise<void>;
  changes?: ChangeSummary;
  diffReview?: ChangeSummary;
  diffFileId: string = '';
  diffText: string = '';
  diffOffset: number = 0;
  diffMore: boolean = false;
  diffLoading: boolean = false;
  abstract openChanges(turnId: string): Promise<void>;
  abstract selectDiffFile(fileId: string): Promise<void>;
  abstract loadMoreDiff(): Promise<void>;
  recovering: boolean = false;
  recoveryIssue: string = '';
  connectionVersion: number = 0;
  permissionOptions: PermissionOption[] = [];
  get permissionChoices(): PermissionOption[] {
    if (this.permissionOptions.length || this.selectedAgent !== 'codex') { return this.permissionOptions; }
    return [{ value: 'ask', label: '要求批准', description: '编辑项目外文件或访问网络前，先询问你' }, { value: 'auto', label: '代我批准', description: '由 Codex 对需要提升权限的操作进行自动审核', requiresConfirmation: true }, { value: 'full', label: '完整存取权', description: '可访问互联网及这台电脑上的文件', requiresConfirmation: true }];
  }
  get permissionLabel(): string { const option = this.permissionChoices.find((o: PermissionOption) => o.value === this.permissionMode); return option?.shortLabel || option?.label || '自定义'; }
  permissionConfirmation(mode: string): boolean { return this.permissionChoices.find((o: PermissionOption) => o.value === mode)?.requiresConfirmation === true; }
  permissionMode: string = 'ask';
  permissionMobileControl: boolean = true;
  fullAccessConfirmed: boolean = false;
  references: ExtensionItem[] = [];
  attachments: DraftImage[] = [];
  uploadProgress: number = -1;
  get hasDraftContent(): boolean { return this.draft.trim().length > 0 || this.references.length > 0 || this.attachments.length > 0; }
  abstract pickImages(): Promise<void>;
  abstract pickFiles(): Promise<void>;
  abstract removeImage(id: string): Promise<void>;
  extensionItems: ExtensionItem[] = [];
  extensionTotal: number = 0;
  extensionLoading: boolean = false;
  extensionSyncing: boolean = false;
  extensionSyncStatus: string = '';
  extensionIconVersion: number = 0;
  imageUri: string = '';
  imageLabel: string = '';
  imageLoading: boolean = false;
  imageProgress: number = 0;
  userFacingError(error: Error): string { if (error.name === 'GatewayVersionError') { return error.message; } if (error.name === 'LinkError' || (!this.authenticated && this.recovering)) { return this.hasKnownMac ? '' : '暂时无法连接电脑，请检查网络后重试'; } return error.message.slice(0, 200); }
  get canControlProject(): boolean { return this.authenticated && this.projects.some((p: ProjectItem) => p.id === this.selectedProjectId && p.capability === 'control'); }
  get canCreateProject(): boolean { return this.capabilities.createProjects ?? this.selectedAgent === 'codex'; }
  get projectActions(): ThreadAction[] { return this.capabilities.projectActions || (this.selectedAgent === 'codex' ? [{ action: 'rename', label: '重命名' }, { action: 'section', label: '分区' }] : []); }
  get canCreateThread(): boolean { return this.capabilities.createThreads !== undefined ? this.capabilities.createThreads : this.selectedAgent === 'codex'; }
  get requiresWorkspaceThread(): boolean { return !this.selectedThreadId && (this.navigation?.sections.some((s: NavigationSection) => !!s.workspaceId) || false); }
  get canExecute(): boolean { return this.canControlProject && (!!this.selectedThreadId || (this.canCreateThread && !this.requiresWorkspaceThread)) && (!this.selectedThreadId || this.permissionMobileControl); }
  get permissionNotice(): string {
    if (!this.canControlProject || !this.selectedThreadId || this.permissionMobileControl) { return ''; }
    if (this.permissionConfirmation(this.permissionMode)) { return '请确认以“' + this.permissionLabel + '”控制此会话'; }
    return this.permissionMode === 'full' ? '此会话使用完整存取权，请先确认手机控制权限' : '此会话使用自定义权限，请先选择审批权限';
  }
  abstract loadPermissions(): Promise<void>;
  abstract applyPermissions(mode: string, confirmFullAccess: boolean): Promise<void>;
  abstract loadExtensions(query: string, kind?: string): Promise<void>;
  abstract syncExtensions(): Promise<void>;
  abstract loadExtensionIcon(item: ExtensionItem): Promise<string>;
  abstract toggleReference(item: ExtensionItem): Promise<void>;
  abstract loadImage(ref: ImageReference): Promise<string>;
  abstract readImage(ref: ImageReference): Promise<void>;
  pinnedCollapsed: boolean = true;
  appearance: string = 'dark';
  reduceTransparency: boolean = false;
  reduceMotion: boolean = false;
  showReasoning: boolean = false;

  initialized: boolean = false;
  reconnectEnabled: boolean = true;
  models: ModelItem[] = [];
  navigation?: NavigationData;
  selectedModel: string = '';
  selectedEffort: string = '';
  selectedServiceTier: string = '';
  modelDetail: string = '沿用会话模型';
  draft: string = '';
  status: string = '未连接';
  detail: string = 'HTTP/WS 中继 · 端到端加密';
  busy: boolean = false;
  refreshing: boolean = false;
  encrypted: boolean = false;
  authenticated: boolean = false;
  hasKnownMac: boolean = false;
  fingerprint: string = '';
  deviceId: string = '';
  projects: ProjectItem[] = [];
  threads: ThreadItem[] = [];
  messages: MessageView[] = [];
  queueMessages: SnapshotMessage[] = [];
  approvals: ApprovalItem[] = [];
  historyCursor: string = "";
  readingMarkdown: boolean = false;
  readingChunks: string[] = [];
  readingOffset: number = 0;
  readingTotal: number = 0;
  readingMore: boolean = false;
  selectedProjectId: string = '';
  selectedThreadId: string = '';
  selectedThreadName: string = '';
  currentTurnId: string = '';
  waiting: boolean = false;
  lastPendingText: string = '';
  lastSubmissionId: string = '';
  lastMessageState: string = '';

  abstract saveDisplaySettings(reduceTransparency: boolean, reduceMotion: boolean, appearance?: string, showReasoning?: boolean): Promise<void>;
  abstract initialize(context: common.Context): Promise<void>;
  abstract pair(materialText: string, switchComputer?: boolean): Promise<void>;
  abstract reconnect(): Promise<void>;
  abstract send(projectId: string, threadId: string, content: string): Promise<void>;
  abstract answerQuestion(request: ApprovalItem, values: Map<string, string>, selections?: Map<string, string[]>, notes?: Map<string, string>): Promise<void>;
  abstract replyApproval(id: string, decision: string): Promise<void>;
  abstract stop(): Promise<void>;
  abstract cancelQueued(submissionId?: string): Promise<void>;
  abstract steer(turnId: string, submissionId?: string): Promise<void>;
  abstract manageThread(thread: NavigationThread, request: ThreadManagementRequest): Promise<void>;
  abstract manageProject(project: ProjectItem, request: ProjectManagementRequest): Promise<void>;
  abstract refreshNavigation(): Promise<void>;
  abstract openNavigationThread(thread: NavigationThread): Promise<void>;
  abstract loadModelSettings(): Promise<void>;
  abstract applyModel(model: string, effort: string, serviceTier?: string): Promise<void>;
  abstract updateDraft(value: string): Promise<void>;
  abstract createProject(name: string): Promise<void>;
  abstract createThread(section?: NavigationSection): Promise<void>;
  abstract selectProject(projectId: string): Promise<void>;
  abstract selectThread(thread: ThreadItem): Promise<void>;
  abstract refresh(): Promise<void>;
  abstract loadOlder(): Promise<void>;
  abstract readMessage(message: MessageView): Promise<void>;
  abstract readNextChunk(): Promise<void>;
  abstract pauseConnection(): void;
  abstract disconnect(): void;
}
