import { AGENTS, AgentInfo } from '../model/Agents';
import { UiState } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';

@Component
export struct AgentSwitcher {
  @ObjectLink client: UiState;
  onChanging: () => void = () => {};
  onChanged: () => void = () => {};
  onError: (error: Error) => void = () => {};
  @State private expanded: boolean = false;

  private async select(kind: string): Promise<void> {
    this.expanded = false;
    if (kind === this.client.selectedAgent) { return; }
    this.onChanging();
    try { await this.client.switchAgent(kind); }
    catch (error) { this.onError(error as Error); }
    finally { this.onChanged(); }
  }
  @Builder
  private AgentRow(kind: string, name: string, logo: Resource) {
    Button() {
      Row({ space: 12 }) {
        Image(logo).width(32).height(32).objectFit(ImageFit.Contain).accessibilityText(name + ' Logo')
        Text(name).fontSize(15).fontColor(AppTheme.text).layoutWeight(1)
        if (this.client.selectedAgent === kind) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([AppTheme.accent]) }
      }.height(52).padding({ left: 10, right: 12 }).width('100%')
    }.id('switch-agent-' + kind).type(ButtonType.Normal).width('100%').height(52).borderRadius(12)
      .backgroundColor(this.client.selectedAgent === kind ? AppTheme.subtle : Color.Transparent)
      .enabled(this.client.initialized && !this.client.busy && !this.client.extensionSyncing && !this.client.imageLoading && !this.client.diffLoading)
      .accessibilityText('切换到 ' + name).onClick(() => { this.select(kind); })
  }
  @Builder
  private Menu() {
    Column({ space: 4 }) {
      Text('选择智能体').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 10, top: 6, bottom: 4 })
      ForEach(AGENTS, (agent: AgentInfo) => { this.AgentRow(agent.id, agent.name, agent.logo) }, (agent: AgentInfo) => agent.id)
    }.padding(8).width(224)
  }
  build() {
    Button() {
      Row({ space: 3 }) {
        Image(this.client.agent.logo).width(28).height(28).objectFit(ImageFit.Contain)
        SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(9).fontColor([AppTheme.secondary])
      }
    }.id('agent-switcher').height(44).width(52).padding(0).backgroundColor(Color.Transparent)
      .accessibilityText('切换智能体，当前 ' + this.client.agentName).enabled(this.client.initialized && !this.client.busy && !this.client.extensionSyncing && !this.client.imageLoading && !this.client.diffLoading)
      .onClick(() => { this.expanded = !this.expanded; })
      .bindPopup(this.expanded, { builder: this.Menu, placement: Placement.BottomRight, popupColor: AppTheme.fallbackColor(this.client.reduceTransparency), backgroundBlurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), radius: 18, onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible) { this.expanded = false; } } })
  }
}
