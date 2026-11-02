import { ChangesCard } from './ChangesCard';
import { DiffViewer } from './DiffViewer';
import { ExecutionLabel } from './ExecutionLabel';
import { SheetHeader } from './SheetHeader';
import { PermissionPanel } from './PermissionPanel';
import { QueuedMessageCard } from './QueuedMessageCard';
import { MentionControls } from './MentionControls';
import { ImageViewer } from './ImageViewer';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { RequestPanel } from './RequestPanel';
import { SettingsPanel } from './SettingsPanel';
import { AppTheme } from '../theme/AppTheme';
import { ModelControls } from './ModelControls';
import { TranscriptView } from './TranscriptView';
import { NavigationDrawer } from './NavigationDrawer';
import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { UiState, ProjectItem, ThreadItem, NavigationThread, MessageView, ApprovalItem, SnapshotMessage, ImageReference, ExtensionItem, DraftImage } from '../model/UiState';

@Component
export struct WorkspaceView {
  @ObjectLink client: UiState;
  @State private page: string = 'connect';
  @State private showPermissions: boolean = false;
  @State private showProjects: boolean = false;
  @State private workTab: number = 0;
  @State private material: string = '';
  @State private showPairMaterial: boolean = false;
  @State private showConnectionInfo: boolean = false;
  @State private errorText: string = '';
  @State private showRequest: boolean = false;
  @State private activeRequestId: string = '';
  @State private scanning: boolean = false;
  @State private submitting: boolean = false;
  @State private threadSearch: string = '';
  @State private sidebarOpen: boolean = false;
  @State private wideScreen: boolean = false;
  @State private viewportWidth: number = 390;
  private chatScroll: Scroller = new Scroller();
  private contentHeight: number = 0;
  private chatHeight: number = 0;
  @State private followLatest: boolean = true;
  private scrollLatest(): void { if (this.page !== 'chat' || this.chatHeight <= 0 || this.contentHeight <= 0) { return; } this.chatScroll.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.contentHeight - this.chatHeight), animation: false }); }
  private refreshTimer: number = -1;
  private connectionVersion: number = -1;

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.client.initialize(context).then(async () => { if (this.client.reconnectEnabled && this.client.hasKnownMac && !this.client.authenticated && !this.client.busy) { await this.client.reconnect(); } if (this.client.authenticated) { await this.client.refreshNavigation(); this.page = 'chat'; if (!this.client.selectedProjectId) { this.showProjects = true; } } }).catch((error: Error) => { this.errorText = this.safeError(error); });
    this.refreshTimer = setInterval(() => {
      if (this.client.authenticated && this.client.connectionVersion !== this.connectionVersion) { this.connectionVersion = this.client.connectionVersion; this.errorText = ''; if (this.page === 'connect') { this.page = 'chat'; this.showProjects = !this.client.selectedProjectId; } }
      if (this.page === 'chat' && this.client.authenticated && !this.client.busy) { this.client.refresh().catch((error: Error) => { this.errorText = this.safeError(error); }); }
    }, 2000);
  }
  aboutToDisappear(): void { clearInterval(this.refreshTimer); }
  private safeError(error: Error): string {
    if (!this.client.userFacingError(error)) { return ''; }
    if (error.message.includes('UNSAFE_THREAD')) { return '该会话权限过宽，Mac 网关当前拒绝控制。请选择受限会话。'; }
    if (error.message.includes('AUTH_')) { return '设备鉴权已失效，请重新连接或在 Mac 检查授权。'; }
    return error.message.slice(0, 220);
  }
  private setSidebar(show: boolean): void { this.getUIContext().animateTo({ duration: this.client.reduceMotion ? 0 : 220, curve: Curve.EaseOut }, () => { this.sidebarOpen = show; }); }
  private changePage(page: string): void {
    this.getUIContext().animateTo({ duration: this.client.reduceMotion ? 0 : 160, curve: Curve.EaseOut }, () => { this.page = page; });
  }
  private openChanges(turnId: string): void { this.client.openChanges(turnId).then(() => { this.changePage('diff'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); }
  private async pair(): Promise<void> {
    this.errorText = ''; const value: string = this.material; this.material = '';
    try { await this.client.pair(value); this.changePage('chat'); this.showProjects = !this.client.selectedProjectId; }
    catch (error) { this.errorText = this.safeError(error as Error); }
  }
  private async scan(): Promise<void> {
    if (this.scanning || this.client.busy) { return; } this.scanning = true; this.errorText = '';
    const resumeConnection: boolean = this.client.reconnectEnabled;
    if (this.client.hasKnownMac) { this.client.pauseConnection(); }
    try {
      const result = await scanBarcode.startScanForResult(this.getUIContext().getHostContext() as common.UIAbilityContext,
        { scanTypes: [scanCore.ScanType.QR_CODE], enableMultiMode: false, enableAlbum: true });
      this.material = result.originalValue; await this.pair();
    } catch (_) { this.errorText = '扫码未完成，可重新扫码或使用配对材料。'; }
    finally { this.scanning = false; if (resumeConnection && this.client.hasKnownMac && !this.client.authenticated) { this.client.reconnect().catch((error: Error) => { this.errorText = this.safeError(error); }); } }
  }

  @Builder
  private Header() {
    Row({ space: 10 }) {
      Button() { SymbolGlyph(this.page === 'settings' || this.page === 'connect' || (this.page === 'message' || this.page === 'image' || this.page === 'diff') ? $r('sys.symbol.chevron_left') : $r('sys.symbol.line_3_horizontal')).fontSize(21).fontColor([AppTheme.text]) }
        .id(this.page === 'settings' || this.page === 'connect' || (this.page === 'message' || this.page === 'image' || this.page === 'diff') ? 'back-button' : 'navigation-toggle').width(44).height(44).backgroundColor(Color.Transparent).accessibilityText(this.page === 'settings' || this.page === 'connect' || (this.page === 'message' || this.page === 'image' || this.page === 'diff') ? '返回会话' : '打开侧栏')
        .onClick(() => { if (this.page === 'settings' || this.page === 'connect' || (this.page === 'message' || this.page === 'image' || this.page === 'diff')) { this.changePage('chat'); } else { this.setSidebar(!this.sidebarOpen); if (this.sidebarOpen) { this.client.refreshNavigation().catch((e: Error) => { this.errorText = this.safeError(e); }); } } })
      Column({ space: 3 }) {
        Row({ space: 6 }) { Text(this.page === 'settings' ? '设置' : this.page === 'connect' ? '连接 Mac' : this.page === 'diff' ? '代码变更' : this.page === 'image' ? (this.client.imageLabel || '图片') : this.page === 'message' ? '完整内容' : this.page === 'chat' ? (this.client.projects.find((p: ProjectItem) => p.id === this.client.selectedProjectId)?.name || '新任务') : '远码').fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); if (this.page === 'chat' && this.client.authenticated) { SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(10).fontColor([AppTheme.secondary]) } }

        if (this.page === 'chat' || this.page === 'projects' || this.page === 'threads') { Text(this.client.selectedThreadName || (this.client.authenticated ? '已连接 Mac' : this.client.status)).fontSize(11).fontColor(AppTheme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }
      }.layoutWeight(1).alignItems(HorizontalAlign.Center).constraintSize({ minHeight: 44 }).id('project-selector').accessibilityText('选择项目或最近会话').onClick(() => { if (this.page === 'chat' && this.client.authenticated) { this.showProjects = true; this.client.refreshNavigation().catch((e: Error) => { this.errorText = this.safeError(e); }); } })
      if (this.page !== 'settings') { Button() { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(20).fontColor([AppTheme.secondary]) }.id('settings-button').width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('连接与设置').onClick(() => { this.changePage('settings'); }) } else { Blank().width(44) }
    }.id('connection-version-' + this.client.connectionVersion).height(52).width('100%')
  }

  @Builder
  private Connect() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 14 }) {
          SymbolGlyph(this.client.authenticated ? $r('sys.symbol.checkmark_shield') : this.client.hasKnownMac ? $r('sys.symbol.link') : $r('sys.symbol.qrcode')).fontSize(58).fontColor([AppTheme.accent]).margin({ bottom: 8 })
          Text(this.client.authenticated ? 'Mac 已连接' : this.client.hasKnownMac ? (this.client.recovering ? '正在恢复连接' : this.client.recoveryIssue ? this.client.status : '连接已暂停') : '连接一次，随时接续').fontSize(23).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
          Text(this.client.authenticated ? '可以从侧栏选择项目和会话，继续你的工作。' : this.client.hasKnownMac ? (this.client.recoveryIssue || '已保存 Mac 身份，网络恢复后自动连接，无需重新扫码。') : '在 Mac 上生成配对码，然后用手机扫描。').fontSize(14).lineHeight(24).fontColor(AppTheme.secondary).textAlign(TextAlign.Center)
        }.width('100%').padding({ top: 32, bottom: 12 })
        if (this.client.authenticated) {
          Column({ space: 12 }) {
            Row({ space: 10 }) { SymbolGlyph($r('sys.symbol.link')).fontSize(22).fontColor([AppTheme.text]); Text('Mac').fontSize(17).fontColor(AppTheme.text).layoutWeight(1); Text('端到端加密').fontSize(12).fontColor(AppTheme.accent) }.height(44).width('100%')
            Text(this.client.projects.length + ' 个授权项目').fontSize(13).fontColor(AppTheme.secondary).width('100%')
            Button('返回工作').width('100%').height(48).fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primary).borderRadius(16).onClick(() => { this.changePage(this.client.selectedProjectId ? 'chat' : 'projects'); })
          }.padding(20).width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(20)
        } else if (this.client.hasKnownMac) {
          Column({ space: 14 }) {
            if (this.client.recovering) { LoadingProgress().width(28).height(28).color(AppTheme.accent) }
            Text(this.client.recoveryIssue || (this.client.recovering ? '正在重新建立安全连接并同步会话，草稿不会丢失。' : '点按恢复连接，接着处理原来的任务。')).fontSize(14).lineHeight(23).fontColor(AppTheme.secondary).width('100%')
            Button('重新连接已配对的 Mac').id('reconnect-mac').height(48).width('100%').backgroundColor(AppTheme.surface).fontColor(AppTheme.text).enabled(!this.client.busy).onClick(() => { this.client.reconnect().then(() => { this.errorText = ''; this.changePage('chat'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); })
          }.padding(20).width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(20)
        } else {
          Column({ space: 16 }) {
            Text('在 Mac 终端生成配对码').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%')
            Text('npm run pairing:qr').fontFamily('monospace').fontSize(14).fontColor(AppTheme.link).copyOption(CopyOptions.LocalDevice).padding(14).width('100%').backgroundColor(AppTheme.contentSurface).borderRadius(12)
            Divider().color(AppTheme.contentSurface)
            Text('扫描配对二维码').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%')
            Button('扫码连接 Mac').width('100%').height(50).fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primary).borderRadius(16).enabled(this.client.initialized && !this.client.busy).onClick(() => { this.scan(); })
          }.padding(20).width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(20)
          if (this.client.hasKnownMac) { Button('重新连接已配对的 Mac').height(48).width('100%').backgroundColor(AppTheme.contentSurface).fontColor(AppTheme.text).onClick(() => { this.client.reconnect().then(() => { this.changePage('chat'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); }) }
          Text('端到端加密 · 扫码后自动完成设备配对').fontSize(12).fontColor(AppTheme.secondary).textAlign(TextAlign.Center).width('100%')
        }
        if (this.client.hasKnownMac) { Button('扫码更新连接地址').id('update-relay-address').height(44).width('100%').fontSize(14).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).enabled(this.client.initialized && !this.client.busy && !this.scanning).onClick(() => { this.scan(); }) }
        Button(this.showPairMaterial ? '收起配对材料输入' : '使用配对材料').id('pair-material-toggle').height(44).fontSize(14).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).onClick(() => { this.showPairMaterial = !this.showPairMaterial; })
        if (this.showPairMaterial) {
          Column({ space: 12 }) {
            TextInput({ placeholder: '粘贴短时配对材料', text: this.material }).id('pair-material-input').type(InputType.Password).height(48).fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.contentSurface).borderRadius(14).maxLength(8192).onChange((v: string) => { this.material = v; })
            Button('确认身份并连接').id('pair-material-connect').width('100%').height(48).enabled(this.client.initialized && !this.client.busy && this.material.trim().length > 0).backgroundColor(AppTheme.primary).fontColor(AppTheme.primaryText).onClick(() => { this.pair(); })
          }.width('100%')
        }
        if (this.client.busy) { LoadingProgress().width(28).height(28).color(AppTheme.accent); Text(this.client.detail).fontSize(13).fontColor(AppTheme.secondary).width('100%') }
        Button(this.showConnectionInfo ? '收起连接信息' : '查看连接信息').height(44).fontSize(13).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).onClick(() => { this.showConnectionInfo = !this.showConnectionInfo; })
        if (this.showConnectionInfo) { Column({ space: 8 }) { Text('Mac 身份指纹').fontSize(12).fontColor(AppTheme.secondary); Text(this.client.fingerprint || '尚未固定身份').fontSize(12).fontFamily('monospace').fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice); Text(this.client.detail).fontSize(12).lineHeight(20).fontColor(AppTheme.secondary) }.padding(16).width('100%').backgroundColor(AppTheme.surface).borderRadius(14).alignItems(HorizontalAlign.Start) }
      }.padding({ top: 8, bottom: 24 }).width('100%')
    }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
  }

  @Builder
  private ProjectRows() {
    Scroll() {
      Column({ space: 4 }) {
        // ForEach caches by key; replaced snapshots must invalidate the captured row data.
        ForEach(this.client.projects, (project: ProjectItem) => {
          Button() {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.folder')).fontSize(20).fontColor([AppTheme.secondary])
              Column({ space: 4 }) { Text(project.name).fontSize(16).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(project.capability === 'control' ? '可执行' : '只读').fontSize(12).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.client.selectedProjectId === project.id) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([AppTheme.accent]) }
            }.height(64).padding({ left: 12, right: 12 }).width('100%')
          }.id('project-' + project.id).type(ButtonType.Normal).width('100%').height(64).backgroundColor(this.client.selectedProjectId === project.id ? AppTheme.selected : Color.Transparent).borderRadius(12).enabled(!this.client.busy)
            .onClick(() => { this.errorText = ''; this.client.selectProject(project.id).then(async () => { this.showProjects = false; if (project.capability === 'control') { await this.client.createThread(); this.changePage('chat'); } else { this.changePage('threads'); } }).catch((e: Error) => { this.errorText = this.safeError(e); }); })
        }, (project: ProjectItem) => JSON.stringify([project.id, project.name, project.capability]))
        if (!this.client.projects.length) { Text(this.client.authenticated ? 'Mac 尚未授权项目' : '连接 Mac 后选择项目').fontSize(14).fontColor(AppTheme.secondary).padding(24) }
      }.width('100%')
    }.width('100%').constraintSize({ maxHeight: 420 }).scrollBar(BarState.Off).align(Alignment.TopStart)
  }
  @Builder
  private WorkTab(title: string, index: number) {
    Text(title).id(index === 0 ? 'work-tab-projects' : 'work-tab-recent').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.workTab === index ? AppTheme.text : AppTheme.secondary).textAlign(TextAlign.Center).height(36).width('100%').backgroundColor(this.workTab === index ? AppTheme.subtle : Color.Transparent).borderRadius(12)
  }
  @Builder
  private RecentRows() {
    Scroll() {
      Column({ space: 2 }) {
        ForEach(this.client.navigation?.recentThreads || [], (thread: NavigationThread) => {
          Button() {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.message')).fontSize(18).fontColor([AppTheme.secondary])
              Column({ space: 3 }) {
                Text(thread.name).fontSize(14).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.client.projects.find((p: ProjectItem) => p.id === thread.projectId)?.name || '项目会话').fontSize(11).fontColor(AppTheme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (thread.status === 'active') { LoadingProgress().width(14).height(14).color(AppTheme.accent) }
              SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([AppTheme.muted])
            }.padding({ left: 12, right: 12 }).height(56).width('100%')
          }.id('recent-thread-' + thread.id).type(ButtonType.Normal).height(56).width('100%').padding(0).borderRadius(12).backgroundColor(thread.id === this.client.selectedThreadId ? AppTheme.selected : Color.Transparent).enabled(this.client.authenticated && !this.client.busy)
            .onClick(() => { this.errorText = ''; this.client.openNavigationThread(thread).then(() => { this.showProjects = false; this.changePage('chat'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); })
        }, (thread: NavigationThread) => JSON.stringify(thread))
        if (!(this.client.navigation?.recentThreads || []).length) { Text(this.client.busy ? '正在同步最近会话…' : this.client.authenticated ? '暂无可访问的最近会话' : '连接 Mac 后查看最近会话').fontSize(13).fontColor(AppTheme.secondary).padding(24).width('100%').textAlign(TextAlign.Center) }
      }.width('100%')
    }.id('recent-threads-list').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
  }
  @Builder
  private ProjectSheet() {
    Column({ space: 10 }) {
      SheetHeader({ title: '开始工作', onClose: () => { this.showProjects = false; } })
      Tabs({ index: this.workTab }) {
        TabContent() { this.ProjectRows() }.tabBar(this.WorkTab('项目', 0))
        TabContent() { this.RecentRows() }.tabBar(this.WorkTab('最近会话', 1))
      }.id('work-picker-tabs').barMode(BarMode.Fixed).barHeight(44).height(420).width('100%').animationDuration(this.client.reduceMotion ? 0 : 160).onChange((index: number) => { this.workTab = index; })
    }.padding({ left: 20, right: 20, top: 18, bottom: 24 }).width('100%')
  }
  @Builder
  private Projects() { Column({ space: 16 }) { Text('项目').fontSize(20).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%'); this.ProjectRows() }.layoutWeight(1).width('100%') }
  @Builder
  private Threads() {
    Column({ space: 12 }) {
      Row() {
        Text(this.client.projects.find((p: ProjectItem) => p.id === this.client.selectedProjectId)?.name || '会话').fontSize(20).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).layoutWeight(1)
        if (this.client.projects.some((p: ProjectItem) => p.id === this.client.selectedProjectId && p.capability === 'control')) { Button('新任务').height(44).fontSize(14).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).enabled(!this.client.busy).onClick(() => { this.client.createThread().then(() => { this.changePage('chat'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); }) }
      }.width('100%')
      Search({ value: this.threadSearch, placeholder: '搜索当前项目会话' }).height(44).fontColor(AppTheme.text).backgroundColor(AppTheme.surface).borderRadius(14).onChange((v: string) => { this.threadSearch = v; })
      Scroll() {
        Column({ space: 2 }) {
          if (this.client.threads.length === 0) { Text('还没有会话').fontSize(14).fontColor(AppTheme.secondary).padding({ top: 32 }) }
          ForEach(this.client.threads.filter((t: ThreadItem) => t.name.toLowerCase().includes(this.threadSearch.toLowerCase())), (thread: ThreadItem) => {
            Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.message')).fontSize(18).fontColor([AppTheme.secondary]); Text(thread.name).fontSize(14).fontColor(AppTheme.text).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1); if (thread.status === 'active') { LoadingProgress().height(16).width(16).color(AppTheme.accent) } }.padding(12).width('100%').constraintSize({ minHeight: 56 }) }
              .type(ButtonType.Normal).width('100%').backgroundColor(thread.id === this.client.selectedThreadId ? AppTheme.selected : Color.Transparent).borderRadius(12).enabled(!this.client.busy).onClick(() => { this.errorText = ''; this.client.selectThread(thread).then(() => { this.changePage('chat'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); })
          }, (thread: ThreadItem) => JSON.stringify(thread))
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
    }.layoutWeight(1).width('100%')
  }

  @Builder
  private Chat() {
    Column({ space: 12 }) {
      if (!this.client.authenticated) { Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.wifi_slash')).fontSize(16).fontColor([AppTheme.secondary]); Text(this.client.recovering ? '正在恢复连接 · 草稿已保留' : '离线 · 草稿保留在本机').fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1); Button('连接 Mac').height(44).fontSize(13).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).onClick(() => { this.changePage('connect'); }) }.width('100%') }
      if (this.client.approvals.length > 0) { Button('等待你处理 · ' + this.client.approvals.length + ' 项').height(44).width('100%').fontSize(13).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).borderRadius(12).onClick(() => { this.activeRequestId = this.client.approvals[0].id; this.showRequest = true; }) }
      Scroll(this.chatScroll) {
        Column({ space: 10 }) {
          if (this.client.messages.length === 0) { Column({ space: 12 }) { Text(this.client.projects.some((p: ProjectItem) => p.id === this.client.selectedProjectId && p.capability === 'read') ? '查看项目会话' : '开始一项任务').fontSize(28).fontWeight(FontWeight.Medium).fontColor(AppTheme.text); Text(this.client.projects.some((p: ProjectItem) => p.id === this.client.selectedProjectId && p.capability === 'read') ? '此项目只读，可从侧栏选择已有会话。' : '描述目标、提供上下文，Codex 会在 Mac 上执行。').fontSize(14).lineHeight(25).fontColor(AppTheme.secondary) }.padding({ top: 56, bottom: 36 }).width('100%').alignItems(HorizontalAlign.Start) }
          if (this.client.historyCursor.length > 0) { Button('加载较早消息').id('older-messages').height(44).width('100%').fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).enabled(!this.client.busy).onClick(() => { this.client.loadOlder().catch((e: Error) => { this.errorText = this.safeError(e); }); }) }
          TranscriptView({ client: this.client, onViewImage: (ref: ImageReference) => { this.changePage('image'); this.client.readImage(ref).catch((e: Error) => { this.errorText = this.safeError(e); }); }, messages: this.client.messages, reduceMotion: this.client.reduceMotion, threadId: this.client.selectedThreadId, onChanges: (turnId: string) => { this.openChanges(turnId); }, onChatChanged: () => { this.followLatest = true; this.scrollLatest(); }, onRead: (message: MessageView) => { this.client.readMessage(message).then(() => { this.changePage('message'); }).catch((e: Error) => { this.errorText = this.safeError(e); }); } })
          if (this.client.authenticated && this.client.currentTurnId && this.client.activityTitle) { ExecutionLabel({ label: this.client.activityTitle, running: true, reduceMotion: this.client.reduceMotion }).id('activity-title').width('100%').padding({ top: 4, bottom: 8 }) }
          if (this.client.changes && (this.client.changes.files.length > 0 || this.client.changes.partial)) { ChangesCard({ review: this.client.changes, compact: !!this.client.currentTurnId, onOpen: () => { this.openChanges(this.client.changes!.turnId); } }) }
          ForEach(this.client.queueMessages, (message: SnapshotMessage, index: number) => {
            QueuedMessageCard({ message: message, queuePosition: index + 1, preview: message.preview || (message.id === this.client.lastSubmissionId ? this.client.lastPendingText : ''), canCancel: this.client.canExecute && !this.client.busy, canSteer: this.client.canExecute && !this.client.busy && !!this.client.currentTurnId && !this.client.waiting,
              onCancel: () => { this.client.cancelQueued(message.id).catch((e: Error) => { this.errorText = this.safeError(e); }); }, onSteer: () => { this.client.steer(this.client.currentTurnId, message.id).catch((e: Error) => { this.errorText = this.safeError(e); }); } })
          }, (message: SnapshotMessage, index: number) => JSON.stringify([message.id, message.state, message.error, message.preview, index, this.client.currentTurnId, this.client.canExecute, this.client.busy]))
          if (this.client.lastMessageState === 'unknown' && !this.client.queueMessages.some((m: SnapshotMessage) => m.id === this.client.lastSubmissionId || m.client_id === this.client.lastSubmissionId)) { Text('发送结果待核对，请保留草稿。恢复连接后按原消息确认，不会自动重发。').fontSize(13).lineHeight(22).fontColor(AppTheme.secondary).padding(14).width('100%').backgroundColor(AppTheme.surface).borderRadius(14) }
        }.padding({ bottom: 10 }).width('100%').onAreaChange((_old: Area, area: Area) => { this.contentHeight = Number(area.height); if (this.followLatest) { this.scrollLatest(); } })
      }.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart).width('100%')
        .onAreaChange((_old: Area, area: Area) => { this.chatHeight = Number(area.height); if (this.followLatest) { this.scrollLatest(); } })
        .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) { this.followLatest = false; } })
        .onScrollStop(() => { this.followLatest = this.chatScroll.isAtEnd(); })
        .onDisAppear(() => { this.chatHeight = 0; this.contentHeight = 0; })
      if (!this.followLatest && this.client.messages.length > 0) { Button('回到最新').id('latest-message').height(44).fontSize(13).fontColor(AppTheme.text).backgroundColor(AppTheme.surface).onClick(() => { this.followLatest = true; this.scrollLatest(); }) }
      Column({ space: 4 }) {
        if (this.submitting) { Text('正在提交…').id('submission-feedback').fontSize(11).fontColor(AppTheme.secondary).padding({ left: 6 }).width('100%') }
        else if (this.client.lastMessageState === 'unknown') { Text('发送结果待确认 · 正在核对，请勿重复发送').id('submission-feedback').fontSize(11).fontColor(AppTheme.secondary).padding({ left: 6 }).width('100%') }
        else if (this.client.queueMessages.length > 0) { Text('已提交 · ' + this.client.queueMessages.length + ' 条等待处理，点此查看').id('submission-feedback').fontSize(11).fontColor(AppTheme.secondary).padding({ left: 6 }).width('100%').onClick(() => { this.followLatest = true; this.scrollLatest(); }) }
        if (this.client.attachments.length > 0) {
          Scroll() { Row({ space: 8 }) { ForEach(this.client.attachments, (item: DraftImage) => {
            Stack({ alignContent: Alignment.BottomStart }) {
              Button() { Image(item.uri).width(80).height(80).objectFit(ImageFit.Cover).borderRadius(10).border({ width: 0.6, color: AppTheme.subtle }) }.id('draft-image-' + item.id).type(ButtonType.Normal).width(80).height(80).padding(0).backgroundColor(AppTheme.codeSurface).borderRadius(10).accessibilityText('预览待发送图片').onClick(() => { this.client.imageUri = item.uri; this.client.imageLabel = '待发送图片'; this.client.imageLoading = false; this.changePage('image'); })
              Button() { Stack() { Circle().fill(AppTheme.text).width(22).height(22); SymbolGlyph($r('sys.symbol.xmark')).fontSize(11).fontColor([AppTheme.contentSurface]) } }.id('remove-draft-image-' + item.id).type(ButtonType.Normal).width(44).height(44).padding(0).position({ x: 58, y: 0 }).backgroundColor(Color.Transparent).accessibilityText('移除这张待发送图片').enabled(!this.client.busy).onClick(() => { this.client.removeImage(item.id).catch((e: Error) => { this.errorText = this.safeError(e); }); })
            }.width(96).height(96)
          }, (item: DraftImage) => item.id) }.constraintSize({ minWidth: '100%' }).justifyContent(FlexAlign.Start) }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(96).width('100%').align(Alignment.Start)
          if (this.client.uploadProgress >= 0) { Text('正在上传图片 · ' + this.client.uploadProgress + '%').fontSize(11).fontColor(AppTheme.secondary).width('100%') }
        }
        if (this.client.permissionNotice) {
          Button() { Row({ space: 8 }) { Text(this.client.permissionNotice).fontSize(12).lineHeight(18).fontColor(AppTheme.warningText).layoutWeight(1); Text('设置权限').fontSize(12).fontColor(AppTheme.text) }.width('100%') }
            .id('composer-permission-notice').type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 44 }).padding({ left: 4, right: 4 }).backgroundColor(Color.Transparent).enabled(!this.client.busy).onClick(() => { this.showPermissions = true; })
        }
        if (this.client.references.length > 0) { Scroll() { Row({ space: 8 }) { ForEach(this.client.references, (ref: ExtensionItem) => { Button() { Row({ space: 6 }) { Text('@' + ref.name).fontSize(12).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); SymbolGlyph($r('sys.symbol.xmark')).fontSize(10).fontColor([AppTheme.secondary]) }.padding({ left: 10, right: 10 }).height(32) }.id('remove-reference-' + ref.id).type(ButtonType.Normal).height(44).constraintSize({ maxWidth: 190 }).padding(0).backgroundColor(AppTheme.contentSurface).borderRadius(12).enabled(!this.client.busy).onClick(() => { this.client.toggleReference(ref).catch((e: Error) => { this.errorText = this.safeError(e); }); }) }, (ref: ExtensionItem) => JSON.stringify(ref)) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(44).width('100%') }
        Stack({ alignContent: Alignment.TopStart }) {
        TextArea({ text: this.client.draft, placeholder: this.client.projects.some((p: ProjectItem) => p.id === this.client.selectedProjectId && p.capability === 'read') ? '只读项目 · 可保留草稿' : this.client.showSuggestion ? this.client.suggestionText : '与 Codex 协作' }).id('composer-draft').onChange((value: string) => { this.client.updateDraft(value).catch(() => { this.errorText = '草稿保存失败，请保留输入内容'; }); })
          .height(48).fontSize(14).fontStyle(FontStyle.Normal).lineHeight(20).placeholderFont({ size: 14, style: this.client.showSuggestion ? FontStyle.Italic : FontStyle.Normal }).fontColor(AppTheme.text).placeholderColor(this.client.showSuggestion ? AppTheme.suggestionInk : AppTheme.secondary).backgroundColor(Color.Transparent).padding({ left: 6, right: this.client.showSuggestion ? 54 : 6, top: 4, bottom: 4 })
          MentionControls({ client: this.client, draft: this.client.draft }).position({ x: 0, y: 0 })
          if (this.client.showSuggestion) { Row() { Blank().layoutWeight(1); Button('采用').id('accept-suggestion').width(44).height(44).padding(0).fontSize(11).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).accessibilityText('采用 CLI 建议并填入草稿').enabled(!this.client.busy).onClick(() => { this.client.acceptSuggestion().catch((e: Error) => { this.errorText = this.safeError(e); }); }) }.width('100%').height(48).hitTestBehavior(HitTestMode.Transparent) }
        }.height(48).width('100%')
        if (this.client.nextSuggestionEnabled && this.client.selectedThreadId && !this.client.currentTurnId && !this.client.hasDraftContent && this.client.canExecute && (this.client.suggestionState === 'generating' || this.client.suggestionState === 'unavailable')) { Text(this.client.suggestionState === 'generating' ? 'CLI 正在准备下一步建议…' : 'CLI 暂未提供建议').id('prediction-status').fontSize(10).fontColor(AppTheme.muted).padding({ left: 6 }).width('100%') }
        Row() {
          Row({ space: 2 }) {
          Button() { SymbolGlyph($r('sys.symbol.ohos_photo')).fontSize(20).fontColor([AppTheme.secondary]) }.id('attach-image').width(44).height(44).padding(0).backgroundColor(Color.Transparent).accessibilityText('从相册添加图片').enabled(this.client.canControlProject && !this.client.busy && this.client.attachments.length < 4).onClick(() => { this.errorText = ''; this.client.pickImages().catch((e: Error) => { this.errorText = this.safeError(e); }); })
          Button() { Row({ space: 4 }) { SymbolGlyph($r('sys.symbol.checkmark_shield')).fontSize(17).fontColor([this.client.permissionMode === 'full' ? AppTheme.warning : AppTheme.secondary]); Text(this.client.permissionMode === 'full' ? '完整存取' : this.client.permissionMode === 'auto' ? '代我批准' : this.client.permissionMode === 'ask' ? '要求批准' : '自定义').fontSize(10).fontColor(this.client.permissionMode === 'full' ? AppTheme.warning : AppTheme.secondary) } }.id('permission-selector').height(44).width(68).padding({ left: 0, right: 0 }).accessibilityText('修改审批权限').backgroundColor(Color.Transparent).enabled(this.client.authenticated).onClick(() => { this.showPermissions = true; })
          }.height(44)
          Blank().layoutWeight(1)
          Row({ space: 4 }) {
          ModelControls({ client: this.client }).width(Math.min(156, Math.max(88, this.viewportWidth - 252)))
          if (this.client.currentTurnId.length > 0 && !this.client.hasDraftContent) {
            Button() { Stack() { Circle().width(32).height(32).fill(AppTheme.text); SymbolGlyph($r('sys.symbol.square_fill')).fontSize(12).fontColor([AppTheme.contentSurface]) } }.width(44).height(44).padding(0).backgroundColor(Color.Transparent).id('stop-turn').accessibilityText('停止当前任务').enabled(this.client.canExecute && !this.client.busy).onClick(() => { this.client.stop().catch((e: Error) => { this.errorText = this.safeError(e); }); })
          } else {
            Button() { Stack() { Circle().width(32).height(32).fill(AppTheme.text); SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(16).fontColor([AppTheme.contentSurface]) } }.width(44).height(44).padding(0).backgroundColor(Color.Transparent).id('send-message').accessibilityText('发送任务').enabled(this.client.canExecute && !this.client.busy && this.client.hasDraftContent)
              .onClick(() => { if (this.submitting) { return; } this.errorText = ''; this.submitting = true; this.client.send(this.client.selectedProjectId, this.client.selectedThreadId, this.client.draft).then(() => { this.followLatest = true; this.scrollLatest(); }).catch((e: Error) => { this.errorText = this.safeError(e) || '连接正在恢复，草稿或发送结果已保留，正在核对'; }).finally(() => { this.submitting = false; }); })
          }
          }.height(44)
        }.width('100%')
      }.padding(10).width('100%').backgroundColor(this.client.reduceTransparency ? AppTheme.inputSurface : AppTheme.inputGlass).backgroundBlurStyle(this.client.reduceTransparency ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR).border({ width: 0.7, color: AppTheme.subtle }).borderRadius(24)
    }.id('chat-context-' + this.client.selectedThreadId).width('100%').layoutWeight(1)
  }

  @Builder
  private ActiveSheet() { if (this.showPermissions) { PermissionPanel({ client: this.client, onClose: () => { this.showPermissions = false; }, onHandled: () => { this.showPermissions = false; } }) } else if (this.showProjects) { this.ProjectSheet() } else { this.RequestSheet() } }

  @Builder
  private RequestSheet() {
    Column() {
      ForEach(this.client.approvals.filter((a: ApprovalItem) => a.id === this.activeRequestId), (a: ApprovalItem) => { RequestPanel({ client: this.client, request: a, onClose: () => { this.showRequest = false; }, onHandled: () => { this.showRequest = false; } }) }, (a: ApprovalItem) => JSON.stringify(a))
      if (!this.client.approvals.some((a: ApprovalItem) => a.id === this.activeRequestId)) { SheetHeader({ title: '请求已处理', onClose: () => { this.showRequest = false; } }); Text('请求已处理或已失效').fontSize(14).fontColor(AppTheme.secondary).padding(24); Button('返回会话').height(44).onClick(() => { this.showRequest = false; }) }
    }.width('100%')
  }

  @Builder
  private Settings() { SettingsPanel({ client: this.client, onNavigate: (page: string) => { this.changePage(page); } }) }

  @Builder
  private MainContent() {
    Column({ space: 10 }) {
      this.Header()
      if (this.errorText.length > 0) { Row({ space: 8 }) { Text(this.errorText).fontSize(13).fontColor(AppTheme.error).lineHeight(21).layoutWeight(1); Button() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([AppTheme.error]) }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('关闭错误提示').onClick(() => { this.errorText = ''; }) }.id('error-banner').padding({ left: 14, right: 4 }).width('100%').backgroundColor(AppTheme.errorSurface).borderRadius(14) }
      if (this.page === 'connect') { this.Connect() }
      else if (this.page === 'projects') { this.Projects() }
      else if (this.page === 'threads') { this.Threads() }
      else if (this.page === 'chat') { this.Chat() }
      else if (this.page === 'diff') { DiffViewer({ client: this.client }) }
      else if (this.page === 'image') { ImageViewer({ uri: this.client.imageUri, loading: this.client.imageLoading, progress: this.client.imageProgress, reduceMotion: this.client.reduceMotion }) }
      else if (this.page === 'message') {
        Column({ space: 12 }) {
          Row() { Text(this.client.readingMore ? '已加载部分内容' : '已加载全部内容').fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1); Text(this.client.readingOffset + ' / ' + this.client.readingTotal + ' 字符').fontSize(12).fontColor(AppTheme.secondary) }.height(32).width('100%')
          Scroll() { Column({ space: 0 }) { ForEach(this.client.readingChunks, (chunk: string, index: number) => { Text(chunk).fontSize(14).lineHeight(20).fontFamily('monospace').fontColor(AppTheme.text).width('100%').copyOption(CopyOptions.LocalDevice) }, (_chunk: string, index: number) => String(index)) }.width('100%').padding(14).backgroundColor(AppTheme.contentSurface).borderRadius(14) }.layoutWeight(1).align(Alignment.TopStart).width('100%')
          Text('长按选中并复制已加载内容').fontSize(12).fontColor(AppTheme.muted).width('100%')
          if (this.client.readingMore) { Button(this.client.busy ? '正在加载…' : '继续加载').id('continue-reading').height(48).width('100%').fontColor(AppTheme.text).backgroundColor(AppTheme.surface).borderRadius(16).enabled(!this.client.busy).onClick(() => { this.client.readNextChunk().catch((e: Error) => { this.errorText = this.safeError(e); }); }) }
        }.layoutWeight(1).width('100%')
      }
      else { this.Settings() }
    }.padding({ left: 20, right: 20, top: 8, bottom: 10 }).height('100%').width('100%').backgroundColor(AppTheme.background)
  }
  build() {
    SideBarContainer(this.wideScreen ? SideBarContainerType.Embed : SideBarContainerType.Overlay) {
      NavigationDrawer({ client: this.client, reduceTransparency: this.client.reduceTransparency, onNavigate: (page: string) => { this.setSidebar(false); this.changePage(page); } }).zIndex(1)
      Stack({ alignContent: Alignment.TopStart }) {
        this.MainContent()
        if (!this.wideScreen && this.sidebarOpen) {
          // The native sidebar paints an opaque backing; overlay the mobile drawer after the page so blur samples real content.
          Blank().width('100%').height('100%').backgroundColor(AppTheme.scrim).transition(TransitionEffect.OPACITY).onClick(() => { this.setSidebar(false); })
          NavigationDrawer({ client: this.client, reduceTransparency: this.client.reduceTransparency, onNavigate: (page: string) => { this.setSidebar(false); this.changePage(page); } })
            .width(Math.min(340, Math.max(280, this.viewportWidth * 0.76))).height('100%').transition(TransitionEffect.move(TransitionEdge.START))
        }
      }.width('100%').height('100%')
    }.showSideBar(this.wideScreen).showControlButton(false).sideBarWidth(300).minSideBarWidth(260).maxSideBarWidth(340)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); this.wideScreen = this.viewportWidth >= 840; })
      .height('100%').width('100%')
      .bindSheet(this.showProjects || this.showRequest || this.showPermissions, this.ActiveSheet, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: AppTheme.fallbackColor(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), blurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onDisappear: () => { this.showProjects = false; this.showRequest = false; this.showPermissions = false; } })
  }

}
