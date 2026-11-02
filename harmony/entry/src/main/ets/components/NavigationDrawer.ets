import { SheetHeader } from './SheetHeader';
import { AppTheme } from '../theme/AppTheme';
import { UiState, NavigationSection, NavigationProject, NavigationThread, ThreadManagementRequest, ProjectItem } from '../model/UiState';

@Component
export struct NavigationDrawer {
  @ObjectLink client: UiState;
  reduceTransparency: boolean = false;
  onNavigate: (page: string) => void = () => {};
  @State private search: string = '';
  @State private collapsed: Map<string, boolean> = new Map<string, boolean>();
  @State private error: string = '';
  @State private panel: string = '';
  @State private contextThreadId: string = '';
  @State private editingThread: NavigationThread | undefined = undefined;
  @State private editName: string = '';
  @State private targetProjectId: string = '';
  @State private targetSectionId: string = '';

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
    const all: NavigationProject[] = [...(this.client.navigation?.projects || [])];
    this.client.navigation?.sections.forEach((s: NavigationSection) => { all.push(...s.projects); });
    const p = all.find((p: NavigationProject) => p.id === this.client.selectedProjectId && p.capability === 'control');
    if (!p) { this.onNavigate(this.client.authenticated ? 'projects' : 'connect'); return; }
    this.client.selectedProjectId = p.id; await this.client.createThread(); this.onNavigate('chat');
  }
  private threadKey(thread: NavigationThread): string { return JSON.stringify([thread.id, thread.name, thread.status, thread.pinned || false, thread.sectionId || '']); }
  // Builder rows capture their group data; refresh their key when children or fold state change.
  private projectKey(project: NavigationProject): string { return JSON.stringify([project, this.collapsed.get(project.id) ?? true]); }
  private sectionKey(section: NavigationSection): string { return JSON.stringify([section, this.collapsed.get(section.id), section.projects.map((p: NavigationProject) => this.collapsed.get(p.id) ?? true)]); }
  private canManage(thread: NavigationThread): boolean { return this.client.authenticated && this.client.projects.some((p) => p.id === thread.projectId && p.capability === 'control'); }
  private edit(thread: NavigationThread, panel: string): void { this.editingThread = thread; this.editName = thread.name; this.targetProjectId = thread.projectId; this.targetSectionId = thread.pinned ? '' : thread.sectionId || ''; this.error = ''; this.panel = panel; }
  private async perform(thread: NavigationThread, request: ThreadManagementRequest): Promise<void> { this.error = ''; try { await this.client.manageThread(thread, request); this.panel = ''; } catch (error) { this.error = this.client.userFacingError(error as Error); } }
  private savePanel(): void { const thread: NavigationThread | undefined = this.editingThread; if (!thread) { return; } this.perform(thread, this.panel === 'rename' ? { action: 'rename', name: this.editName.trim() } : this.panel === 'project' ? { action: 'project', targetProjectId: this.targetProjectId } : { action: 'section', sectionId: this.targetSectionId }); }
  @Builder
  private ActionRow(thread: NavigationThread, key: string, title: string, icon: Resource) {
    Button() { Row({ space: 12 }) { SymbolGlyph(icon).fontSize(18).fontColor([AppTheme.secondary]); Text(title).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (key === 'project' || key === 'section') { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([AppTheme.muted]) } }.padding({ left: 12, right: 12 }).height(44).width('100%') }
      .id('thread-menu-' + key).type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).borderRadius(10).enabled(this.canManage(thread) && !this.client.busy && (key !== 'archive' || thread.status !== 'active'))
      .onClick(() => { this.contextThreadId = ''; if (key === 'rename' || key === 'project' || key === 'section') { this.edit(thread, key); } else { this.perform(thread, key === 'pin' ? { action: 'pin', pinned: !thread.pinned } : { action: 'archive' }); } })
  }
  @Builder
  private ThreadMenu(thread: NavigationThread) {
    Column({ space: 2 }) {
      this.ActionRow(thread, 'rename', '重新命名', $r('sys.symbol.square_and_pencil'))
      this.ActionRow(thread, 'pin', thread.pinned ? '取消固定' : '固定', $r('sys.symbol.pin'))
      this.ActionRow(thread, 'project', '项目', $r('sys.symbol.folder'))
      this.ActionRow(thread, 'section', '区段', $r('sys.symbol.list_bullet'))
      Divider().color(AppTheme.border).margin({ top: 4, bottom: 4 })
      this.ActionRow(thread, 'archive', '封存', $r('sys.symbol.archivebox'))
    }.id('thread-actions-' + thread.id).accessibilityText('会话操作：' + thread.name).padding(6).width(196)
  }
  @Builder
  private Editor() {
    Column({ space: 14 }) {
      SheetHeader({ title: this.panel === 'rename' ? '重新命名' : this.panel === 'project' ? '移动到项目' : '移动到区段', onClose: () => { this.panel = ''; } })
      if (this.panel === 'rename') { TextInput({ text: this.editName, placeholder: '输入会话名称' }).id('thread-name-input').height(48).fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).maxLength(80).onChange((value: string) => { this.editName = value; }) }
      else if (this.panel === 'project') {
        Text('移动后，后续任务会在该项目目录工作，审批模式保持不变。请先完成当前任务并处理待发送消息。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        Scroll() { Column({ space: 2 }) { ForEach(this.client.projects, (project: ProjectItem) => {
          Button() { Row() { Text(project.name).fontSize(14).fontColor(project.capability === 'control' ? AppTheme.text : AppTheme.muted).layoutWeight(1); if (project.id === this.targetProjectId) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([AppTheme.accent]) } }.padding({ left: 12, right: 12 }).height(48).width('100%') }.id('move-project-' + project.id).type(ButtonType.Normal).height(48).width('100%').backgroundColor(project.id === this.targetProjectId ? AppTheme.selected : Color.Transparent).borderRadius(12).enabled(project.capability === 'control').onClick(() => { this.targetProjectId = project.id; })
        }, (project: ProjectItem) => project.id) }.width('100%') }.width('100%').constraintSize({ maxHeight: 360 }).scrollBar(BarState.Off)
      } else {
        Text(this.editingThread?.pinned ? '移动到区段后会取消固定。' : '会话将显示在所选区段中。').fontSize(12).fontColor(AppTheme.secondary).width('100%')
        Scroll() { Column({ space: 2 }) {
          Button('不分区段').id('move-section-none').height(48).width('100%').fontSize(14).fontColor(AppTheme.text).backgroundColor(this.targetSectionId === '' ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.targetSectionId = ''; })
          ForEach(this.sections(), (section: NavigationSection) => { Button() { Row() { Text(section.name).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (this.targetSectionId === section.id) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([AppTheme.accent]) } }.padding({ left: 12, right: 12 }).height(48).width('100%') }.id('move-section-' + section.id).type(ButtonType.Normal).height(48).width('100%').backgroundColor(this.targetSectionId === section.id ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.targetSectionId = section.id; }) }, (section: NavigationSection) => section.id)
        }.width('100%') }.width('100%').constraintSize({ maxHeight: 360 }).scrollBar(BarState.Off)
      }
      if (this.error) { Text(this.error).fontSize(12).lineHeight(20).fontColor(AppTheme.error).width('100%') }
      Button(this.panel === 'rename' ? '保存名称' : '确认移动').id('thread-editor-save').height(44).width('100%').fontSize(14).fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primary).borderRadius(14).enabled(!this.client.busy && (this.panel === 'rename' ? this.editName.trim().length > 0 : this.panel !== 'project' || this.targetProjectId !== this.editingThread?.projectId)).onClick(() => { this.savePanel(); })
    }.id('thread-editor-' + (this.editingThread?.id || '')).padding({ left: 20, right: 20, top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
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
      .priorityGesture(LongPressGesture({ duration: 450, repeat: false }).onAction(() => { this.contextThreadId = thread.id; }))
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
      }.id('navigation-project-' + project.id).type(ButtonType.Normal).height(44).width('100%').backgroundColor(Color.Transparent).onClick(() => { this.toggle(project.id, this.projectClosed(project)); })
      if (!this.projectClosed(project)) {
        ForEach(project.threads.filter((t: NavigationThread) => t.name.toLowerCase().includes(this.search.toLowerCase())), (t: NavigationThread) => { this.ThreadRow(t) }, (t: NavigationThread) => this.threadKey(t))
        if (project.threads.length === 0) { Text(project.capability === 'none' ? '在 Mac 上授权后查看会话' : '暂无会话').id('project-empty-' + project.id).fontSize(12).fontColor(AppTheme.secondary).padding({ left: 42, top: 8, bottom: 8 }).width('100%') }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Column({ space: 16 }) {
      Row({ space: 4 }) {
        Text('远码').id('navigation-brand').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
        Button() { SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(18).fontColor([AppTheme.secondary]) }
          .width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('刷新 Mac 导航')
          .onClick(() => { this.client.refreshNavigation().catch((e: Error) => { this.error = e.message; }); })
      }.height(44).width('100%')
      Row({ space: 8 }) {
        Search({ value: this.search, placeholder: '搜索会话…' }).id('navigation-search').height(44).textFont({ size: 14 }).searchIcon({ size: 16, color: AppTheme.secondary }).fontColor(AppTheme.text).placeholderColor(AppTheme.secondary)
          .backgroundColor(AppTheme.subtle).borderRadius(16).border({ width: 0.6, color: AppTheme.subtle }).layoutWeight(1).onChange((v: string) => { this.search = v; })
        Button() { Row({ space: 6 }) { SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(17).fontColor([AppTheme.text]); Text('新对话').fontSize(13).fontColor(AppTheme.text) } }
          .type(ButtonType.Normal).height(44).padding({ left: 10, right: 10 }).backgroundColor(AppTheme.subtle).borderRadius(16).border({ width: 0.6, color: AppTheme.subtle }).borderRadius(16)
          .enabled(!this.client.busy).onClick(() => { this.newChat().catch((e: Error) => { this.error = e.message; }); })
      }.width('100%')
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.warningText).width('100%') }
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
                  Row({ space: 8 }) { Text(s.name).fontSize(13).fontColor(AppTheme.secondary).layoutWeight(1); SymbolGlyph(this.sectionClosed(s) ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down')).fontSize(12).fontColor([AppTheme.secondary]) }.padding({ left: 12, right: 12 }).height(44).width('100%')
                }.id('navigation-section-' + s.id).type(ButtonType.Normal).width('100%').height(44).backgroundColor(Color.Transparent).onClick(() => { this.toggle(s.id, this.sectionClosed(s)); })
                if (!this.sectionClosed(s)) { ForEach(s.projects, (p: NavigationProject) => { this.ProjectRow(p) }, (p: NavigationProject) => this.projectKey(p)); ForEach(s.threads || [], (thread: NavigationThread) => { this.ThreadRow(thread, false) }, (thread: NavigationThread) => this.threadKey(thread)) }
              }.width('100%')
            }, (s: NavigationSection) => this.sectionKey(s))
            Divider().color(AppTheme.subtle).margin({ top: 4, bottom: 4 })
            Text('项目').fontSize(12).fontColor(AppTheme.secondary).padding({ left: 12 }).width('100%')
            ForEach(this.client.navigation.projects, (p: NavigationProject) => { this.ProjectRow(p) }, (p: NavigationProject) => this.projectKey(p))
            Divider().color(AppTheme.subtle).margin({ top: 4, bottom: 4 })
            Text('最近会话').fontSize(12).fontColor(AppTheme.secondary).padding({ left: 12 }).width('100%')
            ForEach(this.client.navigation.recent.filter((t: NavigationThread) => t.name.toLowerCase().includes(this.search.toLowerCase())), (t: NavigationThread) => { this.ThreadRow(t, false) }, (t: NavigationThread) => this.threadKey(t))
          } else { Text(this.client.authenticated ? '正在同步 Mac 导航…' : '连接 Mac 后同步会话').fontSize(14).fontColor(AppTheme.secondary) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart).initialOffset({ xOffset: 0, yOffset: 0 })
      Row({ space: 8 }) {
        Circle().width(7).height(7).fill(this.client.authenticated ? AppTheme.success : AppTheme.secondary)
        Text(this.client.authenticated ? '已连接  ·  Mac' : this.client.status).fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1)
        Button() { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(21).fontColor([AppTheme.text]) }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('连接与设置').onClick(() => { this.onNavigate('settings'); })
      }.width('100%').height(44)
    }.padding({ left: 14, right: 14, top: 16, bottom: 12 }).height('100%').width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor(this.reduceTransparency ? AppTheme.surface : Color.Transparent)
      .backgroundEffect({ radius: this.reduceTransparency ? 0 : 18, saturation: 1.3, brightness: 1.08, color: this.reduceTransparency ? AppTheme.surface : AppTheme.drawerTint })
      .border({ width: 1, color: AppTheme.glassRim }).borderRadius({ topRight: 22, bottomRight: 22 }).shadow({ radius: 22, color: AppTheme.shadow, offsetX: 6 })
      .bindSheet(this.panel.length > 0, this.Editor, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: AppTheme.fallbackColor(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), blurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onDisappear: () => { this.panel = ''; } })
  }
}
