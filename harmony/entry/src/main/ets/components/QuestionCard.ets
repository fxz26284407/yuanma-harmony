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
  @State private choices: Map<string, string> = new Map<string, string>();
  @State private notes: Map<string, string> = new Map<string, string>();
  @State private errorText: string = '';
  private requestChanged(): void { if (this.currentRequestId !== this.request.id) { this.currentRequestId = this.request.id; this.choices = new Map<string, string>(); this.notes = new Map<string, string>(); this.errorText = ''; this.request.questions.forEach((q: QuestionItem, i: number) => { const answer: string = this.request.answers?.[i] || ''; if (answer) { if (q.options?.some((o: QuestionOption) => o.label === answer)) { this.choices.set(q.id, answer); } else { this.notes.set(q.id, answer); } } }); } }
  aboutToAppear(): void { this.requestChanged(); }
  private answers(): Map<string, string> {
    const values = new Map<string, string>();
    this.request.questions.forEach((q: QuestionItem) => { const choice: string = this.choices.get(q.id) || ''; const note: string = (this.notes.get(q.id) || '').trim(); values.set(q.id, choice && note ? choice + '\n补充：' + note : choice || note); }); return values;
  }
  private complete(): boolean { const values = this.answers(); return this.request.questions.every((q: QuestionItem) => (values.get(q.id) || '').trim().length > 0); }
  build() {
    Column({ space: 16 }) {
      if (this.inline) { Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.message')).fontSize(16).fontColor([AppTheme.secondary]); Text(this.request.answered ? '已回答' : '需要你选择').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text) }.id('async-question-' + (this.request.sourceItemId || this.request.id)).height(36).width('100%') } else { SheetHeader({ title: this.request.answered ? '已回答' : '需要你确认', icon: $r('sys.symbol.message'), onClose: this.onClose }) }
      Scroll() {
        Column({ space: 24 }) {
          ForEach(this.request.questions, (q: QuestionItem) => {
            Column({ space: 12 }) {
              Text(q.header).fontSize(12).fontColor(AppTheme.secondary)
              Text(q.question).fontSize(16).lineHeight(25).fontColor(AppTheme.text)
              if (q.options && !q.isSecret) {
                ForEach(q.options, (option: QuestionOption) => {
                  Button() {
                    Row({ space: 12 }) {
                      SymbolGlyph(this.choices.get(q.id) === option.label ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle')).fontSize(22).fontColor([this.choices.get(q.id) === option.label ? AppTheme.accent : AppTheme.secondary])
                      Column({ space: 5 }) { Text(option.label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text); Text(option.description).fontSize(13).lineHeight(20).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    }.padding(14).width('100%').constraintSize({ minHeight: 60 })
                  }.id('question-option-' + q.id + '-' + option.label).enabled(!this.request.answered && !this.client.busy).type(ButtonType.Normal).width('100%').borderRadius(14).backgroundColor(this.choices.get(q.id) === option.label ? AppTheme.subtle : AppTheme.subtle)
                    .accessibilityText(option.label + (this.choices.get(q.id) === option.label ? '，已选择' : ''))
                    .onClick(() => { this.choices.set(q.id, option.label); this.choices = new Map(this.choices); })
                }, (option: QuestionOption) => JSON.stringify(option))
              }
              TextInput({ text: this.notes.get(q.id) || '', placeholder: q.options && !q.isSecret ? '补充说明，或直接输入回答' : '输入回答' })
                .id('question-note-' + q.id).enabled(!this.request.answered).type(q.isSecret ? InputType.Password : InputType.Normal).maxLength(4096).height(48).fontSize(14).fontColor(AppTheme.text).placeholderColor(AppTheme.muted).backgroundColor(AppTheme.subtle).borderRadius(12)
                .onChange((value: string) => { this.notes.set(q.id, value); this.notes = new Map(this.notes); })
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (q: QuestionItem) => JSON.stringify(q))
        }.width('100%')
      }.width('100%').constraintSize({ maxHeight: 420 }).scrollBar(BarState.Off).align(Alignment.TopStart)
      if (this.errorText) { Text(this.errorText).fontSize(13).fontColor(AppTheme.error) }
      Button(this.request.answered ? '已提交回答' : '提交回答并继续').id('question-submit-' + this.request.id).height(48).width('100%').backgroundColor(AppTheme.primary).fontColor(AppTheme.primaryText).borderRadius(18).enabled(!this.request.answered && this.client.canExecute && !this.client.busy && this.complete())
        .onClick(() => { this.errorText = ''; this.client.answerQuestion(this.request, this.answers()).then(() => { this.choices = new Map<string, string>(); this.notes = new Map<string, string>(); this.onHandled(); }).catch((error: Error) => { this.errorText = this.client.userFacingError(error); }); })
    }.padding(this.inline ? 14 : 0).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(this.inline ? AppTheme.subtle : Color.Transparent).borderRadius(16)
  }
}
