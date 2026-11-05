import { UiState } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
import { SheetHeader } from './SheetHeader';

@Component
export struct RuntimeControls {
  @ObjectLink client: UiState;
  @State private open: boolean = false;
  @State private error: string = '';
  private label(): string { return [this.client.goalLabel, this.client.planLabel].filter((s: string) => !!s).join(' · ') || (this.client.runtime.goal === undefined && !this.client.runtime.plan ? '模式状态待同步' : '普通模式'); }
  private action(name: string): void { this.error = ''; this.client.runAgentCommand(name).catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  @Builder
  private Details() {
    Column({ space: 12 }) {
      SheetHeader({ title: '模式与上下文', onClose: () => { this.open = false; } })
      Text(this.label()).fontSize(14).fontColor(AppTheme.text).width('100%')
      if (this.client.runtime.goal) {
        Scroll() { Text(this.client.runtime.goal!.objective).fontSize(14).lineHeight(21).fontColor(AppTheme.text).width('100%').copyOption(CopyOptions.InApp) }.width('100%').constraintSize({ maxHeight: 180 })
        if (this.client.runtime.goal!.tokensUsed !== undefined) { Text('目标累计用量 ' + this.client.runtime.goal!.tokensUsed + (this.client.runtime.goal!.tokenBudget !== undefined ? ' / ' + this.client.runtime.goal!.tokenBudget : '') + ' tokens').fontSize(12).fontColor(AppTheme.secondary).width('100%') }
        if (this.client.capabilities.modeControl && !['complete', 'cancelled', 'unknown'].includes(this.client.runtime.goal!.status)) {
          Row({ space: 10 }) {
            if (this.client.runtime.goal!.status === 'active' && this.client.runtime.goal!.automatic !== false) {
              Button('暂停目标').id('pause-agent-goal').onClick(() => { this.action('goal.pause'); })
            } else { Button('继续目标').id('resume-agent-goal').onClick(() => { this.action('goal.resume'); }) }
            Button('取消目标').id('cancel-agent-goal').onClick(() => { this.action('goal.clear'); })
          }.enabled(this.client.canExecute && !this.client.busy).width('100%')
        }
      }
      if (this.client.runtime.plan?.active || this.client.runtime.plan?.pending) {
        if (this.client.capabilities.modeControl) {
          if (this.client.currentTurnId) {
            Button('停止本轮，保留计划模式').height(44).id('pause-agent-plan').enabled(this.client.canExecute && !this.client.busy).onClick(() => { this.client.stop().catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
          }
          Button('退出计划模式').height(44).id('exit-agent-plan').enabled(this.client.canExecute && !this.client.busy && !this.client.currentTurnId).onClick(() => { this.action('plan.off'); })
          if (this.client.currentTurnId) { Text('停止本轮后可退出计划模式').fontSize(12).fontColor(AppTheme.secondary).width('100%') }
        }
      }
      if (this.client.runtime.plan?.workflow) { Text('这是原生 /plan 请求；当前规划或实施阶段尚无可读取的状态。').fontSize(12).fontColor(AppTheme.secondary).width('100%') }
      if (this.client.runtime.context) {
        Text((this.client.runtime.context!.estimated ? '上下文估算已用 ' : '上下文已用 ') + this.client.contextPercent + '% · ' + this.client.runtime.context!.used + ' / ' + this.client.runtime.context!.limit + ' tokens').fontSize(13).fontColor(AppTheme.text).width('100%')
        Text('更新于 ' + new Date(this.client.runtime.context!.updatedAt).toLocaleTimeString()).fontSize(11).fontColor(AppTheme.secondary).width('100%')
      } else { Text('上下文用量暂不可用，收到原生数据后更新。').fontSize(12).fontColor(AppTheme.secondary).width('100%') }
      if (this.client.commandFeedback) { Text(this.client.commandFeedback).fontSize(12).fontColor(AppTheme.secondary).width('100%') }
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error).width('100%') }
    }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Row({ space: 0 }) {
      if (this.client.hasAgentMode) {
      Button() {
        Row({ space: 2 }) {
          if (this.client.hasGoalMode) { SymbolGlyph($r('sys.symbol.scope')).fontSize(this.client.planLabel ? 15 : 19).fontColor([this.client.runtime.goal!.status === 'active' ? AppTheme.accent : AppTheme.secondary]) }
          if (this.client.planLabel) { SymbolGlyph($r('sys.symbol.list_bullet')).fontSize(this.client.hasGoalMode ? 15 : 19).fontColor([this.client.runtime.plan?.pending ? AppTheme.warning : AppTheme.accent]) }
        }
      }.id('agent-runtime-status').type(ButtonType.Normal).width(36).height(44).padding(0).backgroundColor(Color.Transparent).accessibilityText(this.label() + '，查看模式与上下文').onClick(() => { this.open = true; })
      }
      Button() {
        if (this.client.contextPercent >= 0) { Progress({ value: this.client.contextPercent, total: 100, type: ProgressType.Ring }).width(18).height(18).color(AppTheme.secondary).backgroundColor(AppTheme.subtle).style({ strokeWidth: 2 }) }
        else { Circle().width(16).height(16).fill(Color.Transparent).stroke(AppTheme.secondary).strokeWidth(1.5) }
      }.id('context-usage').type(ButtonType.Normal).width(36).height(44).padding(0).backgroundColor(Color.Transparent).accessibilityText(this.client.contextPercent >= 0 ? '上下文已用百分之' + this.client.contextPercent : '上下文用量暂不可用').onClick(() => { this.open = true; })
    }.width(this.client.hasAgentMode ? 72 : 36).height(44).bindSheet(this.open, this.Details, { height: SheetSize.FIT_CONTENT, showClose: false, dragBar: true, backgroundColor: AppTheme.surface, onDisappear: () => { this.open = false; } })
  }
}
