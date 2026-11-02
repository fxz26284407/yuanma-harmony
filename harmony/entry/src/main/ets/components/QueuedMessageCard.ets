import { SnapshotMessage } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';

@Component
export struct QueuedMessageCard {
  @Prop message: SnapshotMessage;
  @Prop preview: string = '';
  @Prop queuePosition: number = 1;
  @Prop canCancel: boolean = false;
  @Prop canSteer: boolean = false;
  onCancel: () => void = () => {};
  onSteer: () => void = () => {};
  private status(): string { return this.message.state === 'queued' ? (this.message.error ? '暂未发送' : '待发送 · ' + this.queuePosition) : this.message.state === 'unknown' ? '正在核对发送结果' : '已交给 Codex，正在核对回执'; }
  build() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Circle().width(5).height(5).fill(this.message.error ? AppTheme.warningText : AppTheme.secondary)
        Text(this.status()).fontSize(11).fontColor(AppTheme.secondary).layoutWeight(1)
        if (this.message.state === 'queued') {
          Button('撤回').id('queue-cancel-' + this.message.id).type(ButtonType.Normal).height(44).padding({ left: 10, right: 10 }).fontSize(12).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).borderRadius(10).enabled(this.canCancel).onClick(this.onCancel)
          Button() { Row({ space: 4 }) { SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(12).fontColor([AppTheme.text]); Text('现在引导').fontSize(12).fontColor(AppTheme.text) }.height(30).padding({ left: 10, right: 10 }).backgroundColor(AppTheme.subtle).borderRadius(15) }
            .id('queue-steer-' + this.message.id).type(ButtonType.Normal).height(44).padding(0).backgroundColor(Color.Transparent).enabled(this.canSteer).accessibilityText('现在引导：不中断当前任务，立即提交这条消息').onClick(this.onSteer)
        }
      }.width('100%').constraintSize({ minHeight: 28 })
      Text(this.preview || this.message.preview || '消息内容正在同步').fontSize(14).lineHeight(22).fontColor(AppTheme.text).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      if (this.message.state === 'unknown' || this.message.error) { Text(this.message.state === 'unknown' ? '确认结果前不会重复发送' : '请检查会话权限，或撤回后修改').fontSize(11).lineHeight(18).fontColor(this.message.error ? AppTheme.warningText : AppTheme.secondary).width('100%') }
    }.id('queue-card-' + this.message.id).padding({ left: 12, right: 12, top: 6, bottom: 12 }).width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.subtle }).borderRadius(14).alignItems(HorizontalAlign.Start)
  }
}
