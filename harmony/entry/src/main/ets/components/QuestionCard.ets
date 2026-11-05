import { SheetHeader } from './SheetHeader';
import { UiState, ApprovalItem, QuestionItem, QuestionOption } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct QuestionCard {
  @Prop @Watch('requestChanged') request: ApprovalItem;
  @ObjectLink client: UiState;
  @Prop inline: boolean = false;
  onHandled: () => void = () => {};
  onClose: () => void = () => {};
  private currentRequestId: string = '';
  @State private choices: Map<string, string[]> = new Map<string, string[]>();
  @State private notes: Map<string, string> = new Map<string, string>();
  @State private errorText: string = '';
  private resolvedLabel(): string { return this.request.resolution === 'cancelled' ? '问题已取消' : this.request.resolution === 'closed' ? '问题已结束' : '已回答'; }
  private requestChanged(): void { if (this.currentRequestId !== this.request.id || this.request.answered) { this.currentRequestId = this.request.id; this.choices = new Map<string, string[]>(); this.notes = new Map<string, string>(); this.errorText = ''; this.request.questions.forEach((q: QuestionItem, i: number) => { const native = this.request.answerValues?.[i]; const answer: string = this.request.answers?.[i] || ''; if (q.nativeOptions && native) { this.choices.set(q.id, native.selectedOptionIds || []); this.notes.set(q.id, native.writeInResponse || ''); } else if (answer) { if (q.options?.some((o: QuestionOption) => o.label === answer)) { this.choices.set(q.id, [answer]); } else { this.notes.set(q.id, answer); } } }); } }
  private selected(q: QuestionItem, option: QuestionOption): boolean { return (this.choices.get(q.id) || []).includes(option.id || option.label); }
  private choose(q: QuestionItem, option: QuestionOption): void { const id: string = option.id || option.label; const prior: string[] = this.choices.get(q.id) || []; this.choices.set(q.id, q.multiSelect ? (prior.includes(id) ? prior.filter((v: string) => v !== id) : [...prior, id]) : [id]); this.choices = new Map(this.choices); }
  aboutToAppear(): void { this.requestChanged(); }
  private answers(): Map<string, string> {
    const values = new Map<string, string>();
    this.request.questions.forEach((q: QuestionItem) => { const choice: string = (q.options || []).filter((o: QuestionOption) => this.selected(q, o)).map((o: QuestionOption) => o.label).join('、'); const note: string = (this.notes.get(q.id) || '').trim(); values.set(q.id, choice && note ? choice + '\n补充：' + note : choice || note); }); return values;
  }
  private complete(): boolean { const values = this.answers(); return this.request.questions.every((q: QuestionItem) => (values.get(q.id) || '').trim().length > 0); }
  @Builder
  private QuestionFields() {
    Column({ space: 24 }) {
      ForEach(this.request.questions, (q: QuestionItem) => {
        Column({ space: 12 }) {
          Text(q.header + (q.multiSelect ? ' · 可多选' : '')).fontSize(12).fontColor(AppTheme.secondary)
          Text(q.question).fontSize(16).lineHeight(25).fontColor(AppTheme.text)
          if (q.options && !q.isSecret) {
            ForEach(q.options, (option: QuestionOption) => {
              Button() {
                Row({ space: 12 }) {
                  SymbolGlyph(this.selected(q, option) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle')).fontSize(22).fontColor([this.selected(q, option) ? AppTheme.accent : AppTheme.secondary])
                  Column({ space: 5 }) { Text(option.label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text); Text(option.description).fontSize(13).lineHeight(20).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.padding(14).width('100%').constraintSize({ minHeight: 60 })
              }.id('question-option-' + q.id + '-' + (option.id || option.label)).enabled(!this.request.answered && this.request.canAccept && !this.client.busy).type(ButtonType.Normal).width('100%').borderRadius(14).backgroundColor(AppTheme.subtle)
                .accessibilityText(option.label + (this.selected(q, option) ? '，已选择' : ''))
                .onClick(() => { this.choose(q, option); })
            }, (option: QuestionOption) => JSON.stringify(option))
          }
          TextInput({ text: this.notes.get(q.id) || '', placeholder: q.options && !q.isSecret ? '补充说明，或直接输入回答' : '输入回答' })
            .id('question-note-' + q.id).enabled(!this.request.answered && this.request.canAccept).type(q.isSecret ? InputType.Password : InputType.Normal).maxLength(4096).height(48).fontSize(14).fontColor(AppTheme.text).placeholderColor(AppTheme.muted).backgroundColor(AppTheme.subtle).borderRadius(12)
            .onChange((value: string) => { this.notes.set(q.id, value); this.notes = new Map(this.notes); })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }, (q: QuestionItem) => JSON.stringify(q))
    }.width('100%')
  }
  build() {
    Column({ space: 16 }) {
      if (this.inline) { Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.message')).fontSize(16).fontColor([AppTheme.secondary]); Text(this.request.answered ? this.resolvedLabel() : '需要你选择').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text) }.id('async-question-' + (this.request.sourceItemId || this.request.id)).height(36).width('100%') } else { SheetHeader({ title: this.request.answered ? this.resolvedLabel() : '需要你确认', icon: $r('sys.symbol.message'), onClose: this.onClose }) }
      if (this.inline) { this.QuestionFields() } else {
        Scroll() { this.QuestionFields() }.width('100%').constraintSize({ maxHeight: 420 }).scrollBar(BarState.Auto).nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST }).align(Alignment.TopStart)
      }
      if (this.errorText) { Text(this.errorText).fontSize(13).fontColor(AppTheme.error) }
      Button(this.request.answered ? this.resolvedLabel() : '提交回答并继续').id('question-submit-' + this.request.id).height(48).width('100%').backgroundColor(AppTheme.primary).fontColor(AppTheme.primaryText).borderRadius(18).enabled(!this.request.answered && this.request.canAccept && this.client.canExecute && !this.client.busy && this.complete())
        .onClick(() => { this.errorText = ''; this.client.answerQuestion(this.request, this.answers(), this.choices, this.notes).then(() => { this.choices = new Map<string, string[]>(); this.notes = new Map<string, string>(); this.onHandled(); }).catch((error: Error) => { this.errorText = this.client.userFacingError(error); }); })
    }.padding(this.inline ? 14 : 0).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(this.inline ? AppTheme.subtle : Color.Transparent).borderRadius(16)
  }
}
