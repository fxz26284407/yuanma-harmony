import { AuthChallenge } from '../security/AuthTranscript';

export interface PairMaterial { profile: string; gatewayId: string; publicKey: string; pairingId: string; secret: string; expiresAt: number; relayUrl?: string; }
export interface KnownMac { gatewayId: string; publicKey: string; relayUrl?: string; }
export interface ClaimResult { claimId: string; claimToken: string; deviceId: string; expiresAt: number; challenge: AuthChallenge; }
export interface ClaimBody { pairingId: string; secret: string; name: string; signingPublicKey: string; }
export interface ProofBody { claimId: string; challengeId: string; signature: string; }
export interface LoginBody { deviceId: string; gatewayId: string; }
export interface LoginProof { challengeId: string; signature: string; }
export interface PairStatus { state: string; deviceId?: string; }
export interface LoginResult { accessToken: string; expiresAt: number; deviceId: string; }
export interface ProjectItem { id: string; name: string; capability: string; }
export interface ThreadItem { id: string; name: string; status: string; model?: string; }
export interface ThreadPage { data: ThreadItem[]; nextCursor?: string; }
export interface SnapshotBackend { name?: string; latestTurnId?: string; active: boolean; turnId: string | null; waiting: boolean; permissions?: PermissionState; }
export interface SnapshotMessage { id: string; state: string; client_id: string; preview?: string; previewTruncated?: boolean; error?: string; }
export interface ExecutionSummary { kind: string; label: string; status: string; durationMs?: number; exitCode?: number; }
export interface LiveProgress { turnId?: string; images?: ImageReference[]; execution?: ExecutionSummary; id: string; role: string; text: string; status: string; truncated: boolean; }
export interface ChangedFile { id: string; path: string; kind: string; added: number; removed: number; patches: number; }
export interface ChangeSummary { turnId: string; version: string; files: ChangedFile[]; added: number; removed: number; partial: boolean; }
export interface DiffChunk { fileId: string; version: string; text: string; nextOffset?: number; totalChars: number; }
export interface SuggestionView { sourceTurnId: string; state: string; text: string; }
export interface SuggestionBody { projectId: string; sourceTurnId: string; }
export interface Snapshot { suggestion?: SuggestionView; activityTitle?: string; asyncQuestions?: ApprovalItem[]; changes?: ChangeSummary; history: HistoryPage; approvals: ApprovalItem[]; progress: LiveProgress[]; backend: SnapshotBackend; messages: SnapshotMessage[]; }
export interface TextInputItem { type: string; text?: string; }
export interface HistoryItem { asyncQuestion?: ApprovalItem; images?: ImageReference[]; execution?: ExecutionSummary; truncated?: boolean; totalChars?: number; id: string; type: string; text?: string; clientId?: string; content?: TextInputItem[]; command?: string; aggregatedOutput?: string; }
export interface HistoryTurn { id: string; status: string; items: HistoryItem[]; }
export interface HistoryPage { activityTitle?: string; activityTurnId?: string; data: HistoryTurn[]; nextCursor?: string; }
export interface HistoryChunk { text: string; nextOffset?: number; totalChars: number; }
export class MessageView {
  question?: ApprovalItem;
  images: ImageReference[] = [];
  execution?: ExecutionSummary;
  itemId: string = ""; turnId: string = ""; hasMore: boolean = false;
  id: string; role: string; text: string; status: string;
  constructor(id: string, role: string, value: string, status: string = 'completed') { this.id = id; this.role = role; this.text = value; this.status = status; }
}
export interface DraftImage { id: string; path: string; uri: string; size: number; mime: string; }
export interface ImageUploadBody { projectId: string; imageId: string; offset: number; totalBytes: number; mime: string; data: string; }
export interface ImageUploadResult { imageId: string; nextOffset: number; }
export interface RemoveImagesBody { projectId: string; images: string[]; }
export interface MessagePayload { text: string; references?: string[]; images?: string[]; }
export interface PendingSend { draftKey?: string; id: string; projectId: string; threadId: string; hash: string; }
export interface SendBody { type: string; clientMessageId: string; projectId: string; threadId: string; payload: MessagePayload; }
export interface QueuedMessage { id: string; state: string; }
export interface SteerBody { type: string; clientOperationId: string; submissionId: string; expectedTurnId: string; }
export interface OperationResult { id: string; state: string; }
export interface QuestionOption { label: string; description: string; }
export interface QuestionItem { id: string; header: string; question: string; isSecret?: boolean; options?: QuestionOption[]; }
export interface QuestionAnswer { answers: string[]; }
export interface QuestionReplyBody { sourceTurnId?: string; projectId: string; threadId: string; id: string; answers: Record<string, QuestionAnswer>; }
export interface ApprovalItem { sourceItemId?: string; sourceTurnId?: string; answered?: boolean; answers?: string[]; questions: QuestionItem[]; id: string; kind: string; summary: string; cwd: string; reason: string; details: string; expiresAt: number; canAccept: boolean; }
export interface ApprovalReplyBody { projectId: string; threadId: string; id: string; decision: string; }
export interface ApprovalReplyResult { submitted: boolean; }
export interface InterruptBody { projectId: string; threadId: string; turnId: string; }
export interface InterruptResult { requested: boolean; turnId: string; }
export interface CancelBody { type: string; clientOperationId: string; submissionId: string; }
export interface NavigationThread extends ThreadItem { projectId: string; pinned?: boolean; sectionId?: string; sectionName?: string; }
export interface NavigationProject extends ProjectItem { threads: NavigationThread[]; }
export interface NavigationSection { id: string; name: string; projects: NavigationProject[]; threads?: NavigationThread[]; }
export interface NavigationData { newProjectCapability?: string; pinned?: NavigationThread[]; sections: NavigationSection[]; projects: NavigationProject[]; recent: NavigationThread[]; recentThreads?: NavigationThread[]; }
export interface ModelItem { model: string; name: string; defaultEffort: string; efforts: string[]; fastTier?: string; }
export interface ModelSettings { model: string; effort: string; serviceTier?: string; }
export interface ModelSettingsBody { projectId: string; threadId: string; model: string; effort: string; serviceTier?: string | null; }
export interface CreateThreadBody { approvalMode?: string; confirmFullAccess?: boolean; projectId: string; model?: string; effort?: string; serviceTier?: string | null; }
export interface BackendStatus { backendReady: boolean; }


export interface DisplaySettings { reduceTransparency: boolean; reduceMotion: boolean; appearance?: string; }

export interface ExtensionItem { id: string; kind: string; name: string; description: string; }
export interface ExtensionPage { items: ExtensionItem[]; total: number; }
export interface PermissionState { mode: string; mobileControl: boolean; approvalPolicy?: string; reviewer?: string; sandbox?: string; }
export interface PermissionBody { projectId: string; mode: string; confirmFullAccess: boolean; }
export interface ImageReference { id: string; threadId: string; turnId: string; itemId: string; index: number; label: string; }
export interface ImageChunk { data: string; mime: string; totalBytes: number; nextOffset?: number; version: string; }

export interface ThreadManagementRequest { action: string; name?: string; pinned?: boolean; targetProjectId?: string; sectionId?: string; }
export interface ThreadManagementBody extends ThreadManagementRequest { projectId: string; }
export interface ThreadManagementResult { id: string; projectId: string; name: string; displayName: string; pinned: boolean; sectionId: string; sectionName: string; archived?: boolean; permissionMode?: string; }
