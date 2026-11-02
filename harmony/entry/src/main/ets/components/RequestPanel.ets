import { SheetHeader } from './SheetHeader';
import { UiState, ApprovalItem } from '../model/UiState';
import { QuestionCard } from './QuestionCard';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct RequestPanel {
  @ObjectLink client: UiState;
  @Prop @Watch('resetDetails') request: ApprovalItem;
  private requestId: string = '';
  private resetDetails(): void { if (this.requestId !== this.request.id) { this.requestId = this.request.id; this.details = false; this.error = ''; } }
  aboutToAppear(): void { this.resetDetails(); }
  onHandled: () => void = () => {};
  onClose: () => void = () => {};
  @State private details: boolean = false;
  @State private error: string = '';
  build() {
    Column({ space: 16 }) {
      if (this.request.kind === 'question') {
        QuestionCard({ client: this.client, request: this.request, onHandled: this.onHandled, onClose: this.onClose })
      } else {
        SheetHeader({ title: '需要你的批准', icon: $r('sys.symbol.checkmark_shield'), onClose: this.onClose })
        Text(this.request.kind === 'command' ? '命令执行 · 仅本次' : '文件变更 · 仅本次').fontSize(12).fontColor(AppTheme.secondary).width('100%')
        Scroll() {
          Column({ space: 14 }) {
            Text(this.request.summary).fontSize(14).lineHeight(23).fontFamily('monospace').fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice).padding(14).width('100%').backgroundColor(AppTheme.subtle).borderRadius(12)
            if (this.request.cwd) { Row({ space: 12 }) { Text('工作目录').fontSize(12).fontColor(AppTheme.secondary).width(70); Text(this.request.cwd).fontSize(13).fontColor(AppTheme.text).layoutWeight(1).copyOption(CopyOptions.LocalDevice) }.width('100%') }
            if (this.request.reason) { Row({ space: 12 }) { Text('原因').fontSize(12).fontColor(AppTheme.secondary).width(70); Text(this.request.reason).fontSize(14).lineHeight(22).fontColor(AppTheme.text).layoutWeight(1) }.width('100%') }
            Button(this.details ? '收起完整请求' : '查看完整请求').width('100%').height(44).fontSize(14).fontColor(AppTheme.secondary).backgroundColor(AppTheme.subtle).borderRadius(12).onClick(() => { this.details = !this.details; })
            if (this.details) { Text(this.request.details).fontSize(12).lineHeight(20).fontFamily('monospace').fontColor(AppTheme.secondary).copyOption(CopyOptions.LocalDevice).width('100%') }
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ maxHeight: 330 }).align(Alignment.TopStart).scrollBar(BarState.Off)
        Text('不会授予后续命令权限').fontSize(12).fontColor(AppTheme.secondary).width('100%')
        if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error).width('100%') }
        Row({ space: 12 }) {
          Button('拒绝').height(48).layoutWeight(1).fontColor(AppTheme.text).backgroundColor(Color.Transparent).border({ width: 0.8, color: AppTheme.muted }).borderRadius(18).enabled(this.client.canExecute && !this.client.busy).onClick(() => { this.client.replyApproval(this.request.id, 'decline').then(() => { this.onHandled(); }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
          Button('允许这一次').height(48).layoutWeight(1).fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primary).borderRadius(18).enabled(this.client.canExecute && !this.client.busy && this.request.canAccept && this.request.expiresAt > Date.now()).onClick(() => { this.client.replyApproval(this.request.id, 'accept').then(() => { this.onHandled(); }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
        }.width('100%')
      }
    }.padding({ left: 20, right: 20, top: 16, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
}
