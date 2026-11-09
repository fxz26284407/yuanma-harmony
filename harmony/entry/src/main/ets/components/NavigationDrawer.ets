import { SheetHeader } from './SheetHeader';
import { AppTheme } from '../theme/AppTheme';
import { UiState, ThreadAction, NavigationSection, NavigationProject, NavigationThread, ThreadManagementRequest, ProjectItem } from '../model/UiState';

@Component
export struct NavigationDrawer {
  @ObjectLink client: UiState;
  @Prop @Watch('agentChanged') agentKind: string = 'codex';
  @Prop reduceTransparency: boolean = false;
  @Prop embedded: boolean = false;
  onNavigate: (page: string) => void = () => {};
  @State private search: string = '';
  @State private collapsed: Map<string, boolean> = new Map<string, boolean>();
  @State private error: string = '';
  @State private panel: string = '';
  @State private contextThreadId: string = '';
  @State private contextProjectId: string = '';
  @State private editingThread: NavigationThread | undefined = undefined;
  @State private editingProject: NavigationProject | undefined = undefined;
  @State private editName: string = '';
  @State private targetProjectId: string = '';
  @State private targetSectionId: string = '';

  private agentChanged(): void { this.search = ''; this.collapsed = new Map<string, boolean>(); this.error = ''; this.panel = ''; this.contextThreadId = ''; this.contextProjectId = ''; this.editingThread = undefined; this.editingProject = undefined; this.editName = ''; this.targetProjectId = ''; this.targetSectionId = ''; }
  private toggle(id: string, current: boolean): void { this.collapsed.set(id, !current); this.collapsed = new Map(this.collapsed); }
  private sectionClosed(section: NavigationSection): boolean { return this.collapsed.get(section.id) ?? !(section.projects.some((p: NavigationProject) => p.id === this.client.selectedProjectId || p.capability === 'control') || (section.threads || []).some((t: NavigationThread) => t.id === this.client.selectedThreadId)); }
  private projectClosed(project: NavigationProject): boolean { return this.collapsed.get(project.id) ?? true; }
  private sections(): NavigationSection[] { return this.client.navigation?.sections || []; }
  private searchResults(): NavigationThread[] {
    const list: NavigationThread[] = [...(this.client.navigation?.pinned || []), ...(this.client.navigation?.recent || [])];
    this.client.navigation?.sections.forEach((section: NavigationSection) => { list.push(...(section.threads || [])); });
    const projects: NavigationProject[] = [...(this.client.navigation?.projects || [])];
    this.client.navigation?.sections.forEach((s: NavigationSection) => { projects.push(...s.projects); });
    projects.forEach((p: NavigationProject) => { list.push(...p.threads); });
    const seen: Set<string> = new Set<string>();
    return list.filter((t: NavigationThread) => { if (seen.has(t.id) || !t.name.toLowerCase().includes(this.search.toLowerCase())) { return false; } seen.add(t.id); return true; });
  }
  private async newChat(): Promise<void> {
    if (this.client.navigation?.sections.some((s: NavigationSection) => !!s.workspaceId)) { this.onNavigate('new-conversation'); return; }
    if (!this.client.canCreateThread) { this.onNavigate('threads'); return; }
    const all: NavigationProject[] = [...(this.client.navigation?.projects || [])];
    this.client.navigation?.sections.forEach((s: NavigationSection) => { all.push(...s.projects); });
    const p = all.find((p: NavigationProject) => p.id === this.client.selectedProjectId && p.capability === 'control');
    if (!p) { this.onNavigate(this.client.authenticated ? 'projects' : 'connect'); return; }
    this.client.selectedProjectId = p.id; await this.client.createThread(); this.onNavigate('chat');
  }
  private threadKey(thread: NavigationThread): string { return JSON.stringify(thread); }
  // Builder rows capture their group data; refresh their key when children or fold state change.
  private projectKey(project: NavigationProject): string { return JSON.stringify([project, this.collapsed.get(project.id) ?? true]); }
  private sectionKey(section: NavigationSection): string { return JSON.stringify([section, this.collapsed.get(section.id), section.projects.map((p: NavigationProject) => this.collapsed.get(p.id) ?? true)]); }
  private canManage(thread: NavigationThread): boolean { return this.client.authenticated && this.client.projects.some((p) => p.id === thread.projectId && p.capability === 'control'); }
  private edit(thread: NavigationThread, panel: string): void { this.editingProject = undefined; this.editingThread = thread; this.editName = thread.name; this.targetProjectId = thread.projectId; this.targetSectionId = thread.pinned ? '' : thread.sectionId || ''; this.error = ''; this.panel = panel; }
  private editProject(project: NavigationProject, panel: string): void { this.contextProjectId = ''; this.editingThread = undefined; this.editingProject = project; this.editName = project.name; this.targetSectionId = this.sections().find((s: NavigationSection) => s.projects.some((p: NavigationProject) => p.id === project.id))?.id || ''; this.error = ''; this.panel = panel; }
  private async perform(thread: NavigationThread, request: ThreadManagementRequest): Promise<void> { this.error = ''; try { await this.client.manageThread(thread, request); this.panel = ''; } catch (error) { this.error = this.client.userFacingError(error as Error); } }
  private async saveProject(): Promise<void> { const project: NavigationProject | undefined = this.editingProject; if (!project) { return; } this.error = ''; try { await this.client.manageProject(project, this.panel === 'projectRename' ? { action: 'rename', name: this.editName.trim() } : { action: 'section', sectionId: this.targetSectionId }); this.panel = ''; } catch (error) { this.error = this.client.userFacingError(error as Error); } }
  private async createProject(): Promise<void> { this.error = ''; try { await this.client.createProject(this.editName); this.panel = ''; this.search = ''; this.onNavigate('chat'); } catch (error) { this.error = this.client.userFacingError(error as Error); } }
  private savePanel(): void { if (this.panel === 'create') { this.createProject(); return; } if (this.panel === 'projectRename' || this.panel === 'projectSection') { this.saveProject(); return; } const thread: NavigationThread | undefined = this.editingThread; if (!thread) { return; } this.perform(thread, this.panel === 'rename' ? { action: 'rename', name: this.editName.trim() } : this.panel === 'project' ? { action: 'project', targetProjectId: this.targetProjectId } : { action: 'section', sectionId: this.targetSectionId }); }
  @Builder
  private ProjectMenu(project: NavigationProject) {
    Column({ space: 2 }) {
      Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([AppTheme.secondary]); Text('重新命名').fontSize(14).fontColor(AppTheme.text).layoutWeight(1) }.padding({ left: 12, right: 12 }).height(44).width('100%') }
        .id('project-menu-rename').type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).borderRadius(10).enabled(project.capability === 'control' && !this.client.busy).onClick(() => { this.editProject(project, 'projectRename'); })
      if (this.client.projectActions.some((a: ThreadAction) => a.action === 'section')) {
      Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.list_bullet')).fontSize(18).fontColor([AppTheme.secondary]); Text('分区').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([AppTheme.muted]) }.padding({ left: 12, right: 12 }).height(44).width('100%') }
        .id('project-menu-section').type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).borderRadius(10).enabled(project.capability === 'control' && !this.client.busy).onClick(() => { this.editProject(project, 'projectSection'); })
      }
      if (project.capability !== 'control') { Text('此项目只读或未授权，不能修改').fontSize(12).fontColor(AppTheme.secondary).padding(12) }
    }.id('project-actions-' + project.id).accessibilityText('项目操作：' + project.name).padding(6).width(196)
  }
  @Builder
  private ActionRow(thread: NavigationThread, key: string, title: string, icon: Resource) {
    Button() { Row({ space: 12 }) { SymbolGlyph(icon).fontSize(18).fontColor([AppTheme.secondary]); Text(title).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (key === 'project' || key === 'section') { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([AppTheme.muted]) } }.padding({ left: 12, right: 12 }).height(44).width('100%') }
      .id('thread-menu-' + key).type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).borderRadius(10).enabled(this.canManage(thread) && !this.client.busy && (key !== 'archive' || thread.status !== 'active'))
      .onClick(() => { this.contextThreadId = ''; if (key === 'rename' || key === 'project' || key === 'section') { this.edit(thread, key); } else { this.perform(thread, key === 'pin' ? { action: 'pin', pinned: !thread.pinned } : { action: key }); } })
  }
  @Builder
  private ThreadMenu(thread: NavigationThread) {
    Column({ space: 2 }) {
      ForEach(this.client.threadActions, (action: ThreadAction) => { this.ActionRow(thread, action.action, action.action === 'pin' && thread.pinned ? (action.activeLabel || action.label) : action.label, action.action === 'rename' ? $r('sys.symbol.square_and_pencil') : action.action === 'pin' ? $r('sys.symbol.pin') : action.action === 'project' ? $r('sys.symbol.folder') : action.action === 'section' ? $r('sys.symbol.list_bullet') : $r('sys.symbol.archivebox')) }, (action: ThreadAction) => action.action)
    }.id('thread-actions-' + thread.id).accessibilityText('会话操作：' + thread.name).padding(6).width(196)
  }
  @Builder
  private Editor() {
    Column({ space: 14 }) {
      SheetHeader({ title: this.panel === 'create' ? '新建' + this.client.containerName : this.panel === 'rename' || this.panel === 'projectRename' ? '重新命名' : this.panel === 'projectSection' ? '分区' : this.panel === 'project' ? '移动到项目' : '移动到分区', onClose: () => { this.panel = ''; } })
      if (this.panel === 'create') {
        Text(this.client.containerName + '目录位于电脑的 ' + this.client.projectCreationPath + ' 下，创建后自动授权此设备执行。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        TextInput({ text: this.editName, placeholder: '输入' + this.client.containerName + '名称' }).id('new-project-name').height(48).fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).maxLength(80).onChange((value: string) => { this.editName = value; })
      } else if (this.panel === 'rename' || this.panel === 'projectRename') { TextInput({ text: this.editName, placeholder: this.panel === 'projectRename' ? '输入项目名称' : '输入会话名称' }).id(this.panel === 'projectRename' ? 'project-name-input' : 'thread-name-input').height(48).fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).maxLength(80).onChange((value: string) => { this.editName = value; }) }
      else if (this.panel === 'project') {
        Text('移动后，后续任务会在该项目目录工作，审批模式保持不变。请先完成当前任务并处理待发送消息。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        Scroll() { Column({ space: 2 }) { ForEach(this.client.projects, (project: ProjectItem) => {
          Button() { Row() { Text(project.name).fontSize(14).fontColor(project.capability === 'control' ? AppTheme.text : AppTheme.muted).layoutWeight(1); if (project.id === this.targetProjectId) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([AppTheme.accent]) } }.padding({ left: 12, right: 12 }).height(48).width('100%') }.id('move-project-' + project.id).type(ButtonType.Normal).height(48).width('100%').backgroundColor(project.id === this.targetProjectId ? AppTheme.selected : Color.Transparent).borderRadius(12).enabled(project.capability === 'control').onClick(() => { this.targetProjectId = project.id; })
        }, (project: ProjectItem) => JSON.stringify([project.id, project.name, project.capability])) }.width('100%') }.width('100%').constraintSize({ maxHeight: 360 }).scrollBar(BarState.Off)
      } else {
        Text(this.panel === 'projectSection' ? '手机立即更新。完全退出桌面应用后，待侧栏提示已同步，再重新打开桌面即可生效。' : this.editingThread?.pinned ? '移动到分区后会取消固定。' : '会话将显示在所选分区中。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        Scroll() { Column({ space: 2 }) {
          Button('不分区').id('move-section-none').height(48).width('100%').fontSize(14).fontColor(AppTheme.text).backgroundColor(this.targetSectionId === '' ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.targetSectionId = ''; })
          ForEach(this.sections(), (section: NavigationSection) => { Button() { Row() { Text(section.name).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (this.targetSectionId === section.id) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([AppTheme.accent]) } }.padding({ left: 12, right: 12 }).height(48).width('100%') }.id('move-section-' + section.id).type(ButtonType.Normal).height(48).width('100%').backgroundColor(this.targetSectionId === section.id ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.targetSectionId = section.id; }) }, (section: NavigationSection) => JSON.stringify([section.id, section.name]))
        }.width('100%') }.width('100%').constraintSize({ maxHeight: 360 }).scrollBar(BarState.Off)
      }
      if (this.error) { Text(this.error).fontSize(12).lineHeight(20).fontColor(AppTheme.error).width('100%') }
      Button(this.panel === 'create' ? '创建并授权' : this.panel === 'rename' || this.panel === 'projectRename' ? '保存名称' : '确认移动').id('thread-editor-save').height(44).width('100%').fontSize(14).fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primary).borderRadius(14).enabled(!this.client.busy && (this.panel === 'rename' || this.panel === 'projectRename' || this.panel === 'create' ? this.editName.trim().length > 0 : this.panel !== 'project' || this.targetProjectId !== this.editingThread?.projectId)).onClick(() => { this.savePanel(); })
    }.id('thread-editor-' + (this.editingProject?.id || this.editingThread?.id || '')).padding({ left: 20, right: 20, top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  private ThreadRow(thread: NavigationThread, indented: boolean = true) {
    Button() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.message')).fontSize(18).fontColor([AppTheme.text])
        Text(thread.name).fontSize(14).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        if (thread.status === 'active') { LoadingProgress().width(15).height(15).color(AppTheme.secondary) }
      }.padding({ left: indented ? 32 : 12, right: 12 }).height(44).width('100%')
    }.id('thread-' + thread.id).type(ButtonType.Normal).width('100%').height(44).borderRadius(12)
      .backgroundColor(thread.id === this.client.selectedThreadId ? AppTheme.subtle : Color.Transparent)
      .priorityGesture(LongPressGesture({ duration: 450, repeat: false }).onAction(() => { if (!this.client.threadActions.length || !this.canManage(thread)) { return; } this.contextProjectId = ''; this.contextThreadId = thread.id; }))
      .bindPopup(this.contextThreadId === thread.id, { builder: () => { this.ThreadMenu(thread); }, placement: Placement.BottomLeft, enableArrow: false, radius: 18, systemMaterial: AppTheme.material(this.client.reduceTransparency), popupColor: AppTheme.fallbackColor(this.client.reduceTransparency), backgroundBlurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible && this.contextThreadId === thread.id) { this.contextThreadId = ''; } } })
      .enabled(this.client.authenticated).onClick(() => { if (this.client.busy || this.contextThreadId === thread.id) { return; } this.error = ''; this.client.openNavigationThread(thread).then(() => { this.search = ''; this.onNavigate('chat'); }).catch((e: Error) => { this.error = e.message.slice(0, 140); }); })
  }
  @Builder
  private ProjectRow(project: NavigationProject) {
    Column({ space: 1 }) {
      Button() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.folder')).fontSize(20).fontColor([AppTheme.text])
          Text(project.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).layoutWeight(1).maxLines(1)
          if (project.capability === 'none') { Text('未授权').id('project-ungranted-' + project.id).fontSize(10).fontColor(AppTheme.muted) }
          SymbolGlyph(this.projectClosed(project) ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down')).fontSize(13).fontColor([AppTheme.secondary])
        }.padding({ left: 12, right: 12 }).height(44).width('100%')
      }.id('navigation-project-' + project.id).type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent)
        .priorityGesture(LongPressGesture({ duration: 450, repeat: false }).onAction(() => { if (!this.client.projectActions.length) { return; } this.contextThreadId = ''; this.contextProjectId = project.id; }))
        .bindPopup(this.contextProjectId === project.id, { builder: () => { this.ProjectMenu(project); }, placement: Placement.BottomLeft, enableArrow: false, radius: 18, systemMaterial: AppTheme.material(this.client.reduceTransparency), popupColor: AppTheme.fallbackColor(this.client.reduceTransparency), backgroundBlurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible && this.contextProjectId === project.id) { this.contextProjectId = ''; } } })
        .enabled(this.client.authenticated).onClick(() => { if (this.contextProjectId !== project.id) { this.toggle(project.id, this.projectClosed(project)); } })
      if (!this.projectClosed(project)) {
        ForEach(project.threads.filter((t: NavigationThread) => t.name.toLowerCase().includes(this.search.toLowerCase())), (t: NavigationThread) => { this.ThreadRow(t) }, (t: NavigationThread) => this.threadKey(t))
        if (project.nextCursor) {
          Button(project.loading ? '正在加载…' : '加载更多').height(40).width('100%').fontSize(12).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent)
            .onClick(() => { this.client.loadNavigationProject(project).catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
            .onVisibleAreaChange([0], (visible: boolean) => { if (visible && !this.error) { this.client.loadNavigationProject(project).catch((e: Error) => { this.error = this.client.userFacingError(e); }); } })
        }
        if (project.threads.length === 0 && !project.nextCursor) { Text(project.capability === 'none' ? '在电脑上授权后查看会话' : '暂无会话').id('project-empty-' + project.id).fontSize(12).fontColor(AppTheme.secondary).padding({ left: 42, top: 8, bottom: 8 }).width('100%') }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Image($r('app.media.yuanma_logo_transparent')).id('navigation-logo').width(34).height(34).objectFit(ImageFit.Contain).colorFilter(AppTheme.text).draggable(false).accessibilityLevel('no')
        Text('远码').id('navigation-brand').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
        Button() { SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(18).fontColor([AppTheme.secondary]) }
          .width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('刷新电脑导航')
          .onClick(() => { this.client.refreshNavigation().catch((e: Error) => { this.error = e.message; }); })
      }.height(44).width('100%')
      Row({ space: 8 }) {
        Search({ value: this.search, placeholder: '搜索会话…' }).id('navigation-search').height(44).textFont({ size: 14 }).searchIcon({ size: 16, color: AppTheme.secondary }).fontColor(AppTheme.text).placeholderColor(AppTheme.secondary)
          .backgroundColor(AppTheme.subtle).borderRadius(16).border({ width: 0.6, color: AppTheme.subtle }).layoutWeight(1).onChange((v: string) => { this.search = v; })
        if (this.client.canCreateThread) {
        Button() { Row({ space: 6 }) { SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(17).fontColor([AppTheme.text]); Text('新对话').fontSize(13).fontColor(AppTheme.text) } }
          .type(ButtonType.Normal).height(44).padding({ left: 10, right: 10 }).backgroundColor(AppTheme.subtle).borderRadius(16).border({ width: 0.6, color: AppTheme.subtle }).borderRadius(16)
          .enabled(!this.client.busy).onClick(() => { this.newChat().catch((e: Error) => { this.error = e.message; }); })
        }
      }.width('100%')
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.warningText).width('100%') }
      if (this.client.navigation?.desktopSync?.pending) {
        Text(this.client.navigation.desktopSync.error || '桌面有待同步变更：请完全退出桌面应用，稍后刷新此处；显示已同步后再重新打开桌面。').id('desktop-sync-pending').fontSize(12).lineHeight(18).fontColor(AppTheme.warningText).width('100%')
      } else if (this.client.navigation?.desktopSync?.appliedAt) {
        Text('已同步到桌面，重新打开桌面应用后生效。').id('desktop-sync-complete').fontSize(12).lineHeight(18).fontColor(AppTheme.secondary).width('100%')
      }
      Scroll() {
        Column({ space: 14 }) {
          if (this.search.length > 0) {
            Text('搜索结果').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12 })
            if (this.searchResults().length === 0) { Text('没有匹配的会话').fontSize(14).fontColor(AppTheme.secondary).padding(12) }
            ForEach(this.searchResults(), (t: NavigationThread) => { this.ThreadRow(t, false) }, (t: NavigationThread) => this.threadKey(t))
          } else if (this.client.navigation) {
            if ((this.client.navigation.pinned || []).length > 0) {
              Button() { Row({ space: 8 }) { Text('固定').fontSize(13).fontColor(AppTheme.secondary).layoutWeight(1); Text((this.client.navigation.pinned || []).length.toString()).fontSize(11).fontColor(AppTheme.muted); SymbolGlyph(this.client.pinnedCollapsed ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down')).fontSize(12).fontColor([AppTheme.secondary]) }.padding({ left: 12, right: 12 }).height(44).width('100%') }.id('pinned-section-toggle').type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).accessibilityText(this.client.pinnedCollapsed ? '展开固定会话' : '收起固定会话').onClick(() => { this.client.pinnedCollapsed = !this.client.pinnedCollapsed; })
              if (!this.client.pinnedCollapsed) { ForEach(this.client.navigation.pinned || [], (thread: NavigationThread) => { this.ThreadRow(thread, false) }, (thread: NavigationThread) => this.threadKey(thread)) }
            }
            ForEach(this.sections(), (s: NavigationSection) => {
              Column({ space: 2 }) {
                Button() {
                  Row({ space: 8 }) { Text(s.name).fontSize(13).fontColor(AppTheme.secondary).layoutWeight(1); if (s.capability === 'none') { Text('未授权').fontSize(10).fontColor(AppTheme.muted) } SymbolGlyph(this.sectionClosed(s) ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down')).fontSize(12).fontColor([AppTheme.secondary]) }.padding({ left: 12, right: 12 }).height(44).width('100%')
                }.id('navigation-section-' + s.id).type(ButtonType.Normal).width('100%').height(44).backgroundColor(Color.Transparent).onClick(() => { this.toggle(s.id, this.sectionClosed(s)); })
                if (!this.sectionClosed(s)) { if (s.capability === 'none') { Text('在电脑上授权后查看会话').fontSize(12).fontColor(AppTheme.secondary).padding({ left: 12, top: 8, bottom: 8 }) } ForEach(s.projects, (p: NavigationProject) => { this.ProjectRow(p) }, (p: NavigationProject) => this.projectKey(p)); ForEach(s.threads || [], (thread: NavigationThread) => { this.ThreadRow(thread, false) }, (thread: NavigationThread) => this.threadKey(thread)) }
              }.width('100%')
            }, (s: NavigationSection) => this.sectionKey(s))
            if (this.client.canCreateProject || this.client.navigation.projects.length > 0) {
            Divider().color(AppTheme.subtle).margin({ top: 4, bottom: 4 })
            Row() {
              Text(this.client.containerName).fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1)
              if (this.client.canCreateProject) {
              Button('新建' + this.client.containerName).id('new-project-button').height(44).fontSize(12).fontColor(AppTheme.text).backgroundColor(Color.Transparent).enabled(this.client.authenticated && !this.client.busy).onClick(() => { this.error = ''; if (this.client.newProjectCapability !== 'control') { this.error = '请先在电脑将此设备的新' + this.client.containerName + '权限设为自动可执行'; return; } this.editName = ''; this.panel = 'create'; })
              }
            }.padding({ left: 12 }).width('100%')
            ForEach(this.client.navigation.projects, (p: NavigationProject) => { this.ProjectRow(p) }, (p: NavigationProject) => this.projectKey(p))
            }
            if (this.client.navigation.recent.length > 0) {
            Divider().color(AppTheme.subtle).margin({ top: 4, bottom: 4 })
            Text('最近会话').fontSize(12).fontColor(AppTheme.secondary).padding({ left: 12 }).width('100%')
            ForEach(this.client.navigation.recent.filter((t: NavigationThread) => t.name.toLowerCase().includes(this.search.toLowerCase())), (t: NavigationThread) => { this.ThreadRow(t, false) }, (t: NavigationThread) => this.threadKey(t))
            }
          } else { Text(this.client.authenticated ? '正在同步电脑导航…' : '连接电脑后同步会话').fontSize(14).fontColor(AppTheme.secondary) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart).initialOffset({ xOffset: 0, yOffset: 0 })
      Row({ space: 8 }) {
        Circle().width(7).height(7).fill(this.client.authenticated ? AppTheme.success : AppTheme.secondary)
        Text(this.client.authenticated ? '已连接  ·  电脑' : this.client.status).fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1).id('navigation-connection-status').accessibilityText('查看电脑连接状态').onClick(() => { this.onNavigate('connect'); })
        Button() { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(21).fontColor([AppTheme.text]) }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('连接与设置').onClick(() => { this.onNavigate('settings'); })
      }.width('100%').height(44)
    }.padding({ left: 14, right: 14, top: 16, bottom: 12 }).height('100%').width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor(this.embedded || this.reduceTransparency ? AppTheme.surface : Color.Transparent)
      .backgroundEffect({ radius: this.embedded || this.reduceTransparency ? 0 : 18, saturation: 1.3, brightness: 1.08, color: this.embedded || this.reduceTransparency ? AppTheme.surface : AppTheme.drawerTint })
      .border({ width: this.embedded ? 0 : 1, color: AppTheme.glassRim }).borderRadius({ topRight: this.embedded ? 0 : 22, bottomRight: this.embedded ? 0 : 22 }).shadow({ radius: this.embedded ? 0 : 22, color: AppTheme.shadow, offsetX: this.embedded ? 0 : 6 })
      .bindSheet(this.panel.length > 0, this.Editor, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: AppTheme.fallbackColor(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), blurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onDisappear: () => { this.panel = ''; } })
  }
}
