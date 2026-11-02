import { SheetHeader } from './SheetHeader';
import { UiState } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct PermissionPanel {
  @ObjectLink client: UiState;
  onHandled: () => void = () => {};
  onClose: () => void = () => {};
  @State private confirming: string = '';
  @State private error: string = '';
  aboutToAppear(): void { this.client.loadPermissions().catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  private apply(mode: string): void { this.error = ''; this.client.applyPermissions(mode, mode === 'full').then(() => { this.onHandled(); }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  @Builder
  private ModeRow(mode: string, title: string, detail: string, color: ResourceColor) {
    Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.checkmark_shield')).fontSize(22).fontColor([color]); Column({ space: 5 }) { Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(color); Text(detail).fontSize(12).lineHeight(19).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start); if (this.client.permissionMode === mode) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([color]) } }.padding({ left: 12, right: 12, top: 12, bottom: 12 }).width('100%').constraintSize({ minHeight: 76 }) }
      .id('permission-' + mode).type(ButtonType.Normal).width('100%').backgroundColor(this.client.permissionMode === mode ? AppTheme.subtle : Color.Transparent).borderRadius(14).enabled(this.client.canControlProject && !this.client.busy)
      .onClick(() => { if (mode === 'ask') { this.apply(mode); } else { this.confirming = mode; } })
  }
  build() {
    Column({ space: 14 }) {
      SheetHeader({ title: '审批权限', onClose: this.onClose })
      Text(this.client.selectedThreadId ? '更改用于后续回合，不中断当前任务' : '用于这项新任务，不改变其他会话').fontSize(12).fontColor(AppTheme.secondary).width('100%')
      this.ModeRow('ask', '要求批准', '编辑项目外文件或访问网络前，先询问你', AppTheme.text)
      this.ModeRow('auto', '代我批准', '由 Codex 对需要提升权限的操作进行自动审核', AppTheme.text)
      this.ModeRow('full', '完整存取权', '可访问互联网及这台 Mac 上的文件', AppTheme.warning)
      if (!this.client.canControlProject) { Text('此项目只读，无法修改审批权限').fontSize(13).fontColor(AppTheme.secondary).width('100%') }
      else if (this.client.permissionMode === 'full' && !this.client.permissionMobileControl) { Text('当前会话已是完整存取权；确认后才允许这台手机控制该会话。').fontSize(12).lineHeight(20).fontColor(AppTheme.warningText).width('100%') }
      if (this.confirming) {
        Column({ space: 12 }) {
          Text(this.confirming === 'full' ? '确认允许这台手机以完整存取权控制此会话？这项授权不会扩展到其他项目或会话。' : '确认让 Codex 自动审核此会话后续的审批请求？').fontSize(14).lineHeight(23).fontColor(AppTheme.text)
          Row({ space: 12 }) { Button('取消').height(44).layoutWeight(1).backgroundColor(Color.Transparent).fontColor(AppTheme.secondary).onClick(() => { this.confirming = ''; }); Button(this.confirming === 'full' ? '确认完整存取权' : '确认代我批准').id('confirm-permission').height(44).layoutWeight(1).backgroundColor(this.confirming === 'full' ? AppTheme.warningSurface : AppTheme.primary).fontColor(AppTheme.primaryText).enabled(!this.client.busy).onClick(() => { this.apply(this.confirming); }) }.width('100%')
        }.padding(14).backgroundColor(AppTheme.subtle).borderRadius(14).width('100%')
      }
      if (this.error) { Text(this.error).fontSize(12).lineHeight(20).fontColor(AppTheme.error).width('100%') }
    }.padding({ left: 20, right: 20, top: 18, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
}
