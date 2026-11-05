import { UiState, ExtensionItem, AgentCommand } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
import { ExtensionIcon } from './ExtensionIcon';
@Component
export struct MentionControls {
  @ObjectLink client: UiState;
  @Prop @Watch('draftChanged') draft: string = '';
  @Prop @Watch('draftChanged') catalogScope: string = '';
  @Prop @Watch('composerClicked') composerMenuVersion: number = 0;
  @State private open: boolean = false;
  @State private query: string = '';
  @State private error: string = '';
  private typing: boolean = false;
  @State private kind: string = 'plugin';
  private debounce: number = -1;
  private scroller: Scroller = new Scroller();
  private commands(): AgentCommand[] {
    if (this.kind !== 'skill') { return []; }
    return ['goal', 'plan', 'compact'].map((name: string): AgentCommand => this.client.agentCommands.find((c: AgentCommand) => c.name === name) || { name: name, description: '当前网关未提供此命令，请更新 Mac 网关' });
  }
  private commandLabel(name: string): string { return name === 'goal' ? '目标 /goal' : name === 'plan' ? '计划 /plan' : '压缩 /compact'; }
  private commandAvailable(name: string): boolean { return this.client.agentCommands.some((c: AgentCommand) => c.name === name); }
  private selectCommand(command: AgentCommand): void {
    const content: string = this.client.draft.replace(/\/[^\s/]*$/, '').trim().replace(/^\/(goal|plan|compact)(?:\s+|$)/, '').trim();
    this.client.updateDraft('/' + command.name + ' ' + content).then(() => { this.open = false; this.typing = false; }).catch((e: Error) => { this.error = this.client.userFacingError(e); });
  }
  private composerClicked(): void {
    const command = this.draft.trim().match(/^\/(goal|plan|compact)$/);
    if (command && this.client.canControlProject && !this.client.busy) { this.typing = true; this.kind = 'skill'; this.open = true; this.search(command[1]); }
    else { this.draftChanged(); }
  }
  private draftChanged(): void { const match = this.draft.match(/(^|\s)([@/])([^\s@/]*)$/); if (match && this.client.canControlProject && !this.client.busy) { this.typing = true; this.kind = match[2] === '/' ? 'skill' : 'plugin'; this.open = true; this.search(match[3]); } else if (this.typing) { this.open = false; this.typing = false; } }
  private search(value: string): void { this.query = value; clearTimeout(this.debounce); this.debounce = setTimeout(() => { this.scroller.scrollEdge(Edge.Top); this.error = ''; this.client.loadExtensions(value, this.kind).catch((e: Error) => { this.error = this.client.userFacingError(e); }); }, 150); }
  aboutToAppear(): void { this.draftChanged(); }
  aboutToDisappear(): void { clearTimeout(this.debounce); }
  @Builder
  private Menu() {
    Column({ space: 8 }) {
      Text(this.kind === 'skill' ? '/ 命令与技能' : '@ 插件').fontSize(13).fontColor(AppTheme.secondary).width('100%').padding({ left: 8 })
      Search({ value: this.query, placeholder: '搜索 Mac 已安装的扩展' }).id('extension-search').height(44).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).onChange((value: string) => { this.search(value); })
      if (!this.client.extensionLoading && this.client.extensionTotal > this.client.extensionItems.length) { Text('共 ' + this.client.extensionTotal + ' 项，输入关键词查找更多').fontSize(11).fontColor(AppTheme.secondary).width('100%').padding({ left: 8 }) }
      if (this.client.extensionLoading) { LoadingProgress().height(22).width(22).color(AppTheme.accent) }
      Scroll(this.scroller) {
        Column({ space: 2 }) {
          if (this.commands().length > 0) {
            Text('命令').fontSize(11).fontColor(AppTheme.secondary).width('100%').padding({ left: 10, top: 4, bottom: 4 })
            ForEach(this.commands(), (command: AgentCommand) => {
              Button() { Column({ space: 2 }) { Text(this.commandLabel(command.name)).fontSize(14).fontColor(AppTheme.text); Text(command.description).fontSize(11).fontColor(AppTheme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 10, right: 10, top: 4, bottom: 4 }) }
                .id('agent-command-' + command.name).type(ButtonType.Normal).width('100%').height(44).backgroundColor(Color.Transparent).borderRadius(10).enabled(!this.client.busy && this.commandAvailable(command.name)).opacity(this.commandAvailable(command.name) ? 1 : 0.5)
                .onClick(() => { this.selectCommand(command); })
            }, (command: AgentCommand) => command.name)
          }
          if (this.kind === 'skill' && this.client.extensionItems.length > 0) { Text('技能').fontSize(11).fontColor(AppTheme.secondary).width('100%').padding({ left: 10, top: 4, bottom: 4 }) }
          ForEach(this.client.extensionItems, (item: ExtensionItem) => {
            Button() { Row({ space: 10 }) { ExtensionIcon({ client: this.client, item: item, appearance: this.client.appearance, revision: this.client.extensionIconVersion }); Column({ space: 4 }) { Text(item.name).fontSize(14).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text((item.kind === 'browser' ? '浏览器 · ' : item.kind === 'plugin' ? '插件 · ' : 'Skill · ') + item.description).fontSize(11).fontColor(AppTheme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }.layoutWeight(1).alignItems(HorizontalAlign.Start); if (this.client.references.some((r: ExtensionItem) => r.id === item.id)) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(14).fontColor([AppTheme.accent]) } }.padding(10).height(58).width('100%') }
              .id('extension-' + item.id).type(ButtonType.Normal).height(58).width('100%').backgroundColor(Color.Transparent).borderRadius(10).enabled(!this.client.busy)
              .onClick(() => { this.client.toggleReference(item).then(async () => { await this.client.updateDraft(this.client.draft.replace(/[@/][^\s@/]*$/, '')); this.open = false; this.typing = false; }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
          }, (item: ExtensionItem) => JSON.stringify(item))
          if (!this.client.extensionLoading && this.client.extensionItems.length === 0 && this.commands().length === 0) { Text('没有可用的匹配项').fontSize(13).fontColor(AppTheme.secondary).padding(16) }
        }.width('100%')
      }.width('100%').constraintSize({ maxHeight: 290 }).scrollBar(BarState.Off).align(Alignment.TopStart)
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error) }
    }.padding(12).width(302).borderRadius(18)
  }
  build() {
    Row().width(1).height(1).backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .bindPopup(this.open, { builder: this.Menu, placement: Placement.TopLeft, popupColor: AppTheme.fallbackColor(this.client.reduceTransparency), backgroundBlurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), radius: 24, keyboardAvoidMode: KeyboardAvoidMode.DEFAULT, onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible) { this.open = false; } } })
  }
}
