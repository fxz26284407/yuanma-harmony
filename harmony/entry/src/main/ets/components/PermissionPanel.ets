import { SheetHeader } from './SheetHeader';
import { UiState, PermissionOption } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct PermissionPanel {
  @ObjectLink client: UiState;
  onHandled: () => void = () => {};
  onClose: () => void = () => {};
  @State private confirming: string = '';
  @State private error: string = '';
  aboutToAppear(): void { this.client.loadPermissions().catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  private apply(mode: string): void { this.error = ''; this.client.applyPermissions(mode, this.client.permissionConfirmation(mode)).then(() => { this.onHandled(); }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  @Builder
  private ModeRow(mode: string, title: string, detail: string, color: ResourceColor) {
    Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.checkmark_shield')).fontSize(22).fontColor([color]); Column({ space: 5 }) { Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(color); Text(detail).fontSize(12).lineHeight(19).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start); if (this.client.permissionMode === mode) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([color]) } }.padding({ left: 12, right: 12, top: 12, bottom: 12 }).width('100%').constraintSize({ minHeight: 76 }) }
      .id('permission-' + mode).type(ButtonType.Normal).width('100%').backgroundColor(this.client.permissionMode === mode ? AppTheme.subtle : Color.Transparent).borderRadius(14).enabled(this.client.canControlProject && !this.client.busy)
      .onClick(() => { if (this.client.permissionConfirmation(mode)) { this.confirming = mode; } else { this.apply(mode); } })
  }
  build() {
    Column({ space: 14 }) {
      SheetHeader({ title: '执行策略', onClose: this.onClose })
      Text(this.client.permissionScope === 'desktop-global' ? '要求审查和 Turbo 会修改 Antigravity 桌面全局策略，影响后续任务' : this.client.selectedThreadId ? '更改用于后续回合，不中断当前任务' : '用于这项新任务，不改变其他会话').fontSize(12).fontColor(AppTheme.secondary).width('100%')
      ForEach(this.client.permissionChoices, (option: PermissionOption) => { this.ModeRow(option.value, option.label, option.description || '', option.requiresConfirmation ? AppTheme.warning : AppTheme.text) }, (option: PermissionOption) => JSON.stringify(option))
      if (!this.client.permissionChoices.length) { Text(this.client.selectedThreadId ? '正在读取执行策略…' : '请先选择已有会话').fontSize(13).fontColor(AppTheme.secondary).width('100%') }
      if (!this.client.canControlProject) { Text('此项目只读，无法修改审批权限').fontSize(13).fontColor(AppTheme.secondary).width('100%') }
      else if (this.client.permissionConfirmation(this.client.permissionMode) && !this.client.permissionMobileControl) { Text('确认当前执行策略后，允许这台手机控制该会话。').fontSize(12).lineHeight(20).fontColor(AppTheme.warningText).width('100%') }
      if (this.confirming) {
        Column({ space: 12 }) {
          Text('确认让 ' + this.client.agentName + ' 使用“' + (this.client.permissionChoices.find((o: PermissionOption) => o.value === this.confirming)?.label || this.confirming) + '”处理此会话？').fontSize(14).lineHeight(23).fontColor(AppTheme.text)
          Row({ space: 12 }) { Button('取消').height(44).layoutWeight(1).backgroundColor(Color.Transparent).fontColor(AppTheme.secondary).onClick(() => { this.confirming = ''; }); Button('确认切换').id('confirm-permission').height(44).layoutWeight(1).backgroundColor(this.confirming === 'full' ? AppTheme.warningSurface : AppTheme.primary).fontColor(AppTheme.primaryText).enabled(!this.client.busy).onClick(() => { this.apply(this.confirming); }) }.width('100%')
        }.padding(14).backgroundColor(AppTheme.subtle).borderRadius(14).width('100%')
      }
      if (this.error) { Text(this.error).fontSize(12).lineHeight(20).fontColor(AppTheme.error).width('100%') }
    }.padding({ left: 20, right: 20, top: 18, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
}
