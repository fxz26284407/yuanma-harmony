import { UiState, ModelItem } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct ModelControls {
  @ObjectLink client: UiState;
  @State private showEffort: boolean = false;
  @State private showModels: boolean = false;
  @State private selectedStep: number = 0;
  @State private error: string = '';
  private model(): ModelItem | undefined { return this.client.selectedModel ? this.client.models.find((m: ModelItem) => m.model === this.client.selectedModel) : this.client.models[0]; }
  private fast(): boolean { return this.client.selectedServiceTier === 'priority' || this.client.selectedServiceTier === 'fast'; }
  private async toggleFast(): Promise<void> { const m = this.model(); if (!m?.fastTier) { return; } this.error = ''; try { await this.client.applyModel(m.model, this.client.selectedEffort || m.defaultEffort, this.fast() ? '' : m.fastTier); } catch (e) { this.error = this.client.userFacingError(e as Error); } }
  private effortLabel(value: string): string {
    switch (value) { case 'low': return '低'; case 'medium': return '中'; case 'high': return '高'; case 'xhigh': return '超高'; case 'max': return '最大'; case 'ultra': return 'Ultra'; default: return value || '默认'; }
  }
  private async apply(model: string, effort: string): Promise<void> { this.error = ''; try { await this.client.applyModel(model, effort); } catch (e) { this.error = this.client.userFacingError(e as Error); } }
  @Builder
  private ModelMenu() {
    Column({ space: 8 }) {
      Text('选择模型').fontSize(13).fontColor(AppTheme.secondary).width('100%').padding({ left: 10, top: 4 })
      if (!this.client.models.length) { Text('当前没有可用模型').fontSize(14).fontColor(AppTheme.secondary).padding(16) }
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.client.models, (m: ModelItem) => {
            Button() { Row({ space: 10 }) { Text(m.name).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (m.model === this.client.selectedModel) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([AppTheme.text]) } }.padding({ left: 12, right: 12 }).height(44).width('100%') }
              .type(ButtonType.Normal).width('100%').height(44).borderRadius(12).backgroundColor(m.model === this.client.selectedModel ? AppTheme.subtle : Color.Transparent)
              .enabled(!this.client.busy && this.client.projects.some((p) => p.id === this.client.selectedProjectId && p.capability === 'control')).onClick(() => { this.apply(m.model, m.defaultEffort).then(() => { if (!this.error) { this.showModels = false; } }); })
          }, (m: ModelItem) => JSON.stringify(m))
        }.width('100%')
      }.constraintSize({ maxHeight: 352 }).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error).width('100%') }
    }.padding(10).width(292).borderRadius(20)
  }
  @Builder
  private EffortMenu() {
    Column({ space: 4 }) {
      Row() {
        Button() { SymbolGlyph($r('sys.symbol.bolt_fill')).fontSize(21).fontColor([this.fast() ? AppTheme.accent : AppTheme.secondary]) }
          .id('fast-mode-toggle').width(44).height(44).backgroundColor(this.fast() ? AppTheme.chip : Color.Transparent).borderRadius(14)
          .accessibilityText(this.fast() ? '关闭高速模式' : '开启高速模式').accessibilityDescription('更快响应，增加额度用量；用于后续回合')
          .enabled(!this.client.busy && this.client.canControlProject && !!this.model()?.fastTier).onClick(() => { this.toggleFast(); })
        Text(this.effortLabel(this.model()?.efforts[this.selectedStep] || '')).fontSize(19).fontWeight(FontWeight.Medium).fontColor(AppTheme.accent).layoutWeight(1).textAlign(TextAlign.Center)
        Button() { SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(17).fontColor([AppTheme.secondary]) }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('恢复默认推理强度').onClick(() => { const m = this.model(); if (m) { this.selectedStep = Math.max(0, m.efforts.indexOf(m.defaultEffort)); this.apply(m.model, m.defaultEffort); } })
      }.width('100%')
      Button(this.model()?.name || '选择模型').height(44).fontSize(13).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).onClick(() => { this.showEffort = false; this.showModels = true; })
      if (this.model() && this.model()!.efforts.length > 1) {
        Stack() {
          Stack({ alignContent: Alignment.Start }) { Row().width('100%').height(30).backgroundColor(AppTheme.rail).borderRadius(18); Row().width((this.selectedStep * 100 / Math.max(1, this.model()!.efforts.length - 1)) + '%').height(30).backgroundColor(AppTheme.accent).borderRadius(18) }.height(30).width('100%').padding({ left: 18, right: 18 })
          // Native Slider retains focus, hit testing and discrete values; the rail supplies the requested capsule style.
          Slider({ value: this.selectedStep, min: 0, max: this.model()!.efforts.length - 1, step: 1 }).id('reasoning-slider').width('100%').height(44).blockSize({ width: 36, height: 36 }).enabled(!this.client.busy).showSteps(true).stepColor(AppTheme.muted).stepSize(4).trackColor(Color.Transparent).selectedColor(Color.Transparent).blockColor(AppTheme.thumb)
            .onChange((value: number, mode: SliderChangeMode) => { this.selectedStep = Math.round(value); if (mode === SliderChangeMode.End) { const m = this.model(); if (m) { this.apply(m.model, m.efforts[this.selectedStep]); } } })
        }.height(44).width('100%')
        Row() { ForEach(this.model()!.efforts, (effort: string) => { Text(this.effortLabel(effort)).fontSize(10).fontColor(AppTheme.secondary).layoutWeight(1).textAlign(TextAlign.Center) }, (effort: string) => effort) }.width('100%')
      }
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error) }
      Text(this.model()?.fastTier ? (this.fast() ? '高速模式已开启 · 用量更高' : '高速模式已关闭') : '此模型未提供高速模式').id('fast-mode-status').fontSize(11).fontColor(this.fast() ? AppTheme.accent : AppTheme.secondary)
      Text('用于后续回合，不打断当前任务').fontSize(11).fontColor(AppTheme.secondary).padding({ top: 10, bottom: 6 })
    }.padding(14).width(286).borderRadius(20)
  }
  @Builder
  private ActiveMenu() { if (this.showModels) { this.ModelMenu() } else { this.EffortMenu() } }
  build() {
    Stack() {
      Row().width('100%').height(30).backgroundColor(AppTheme.chip).borderRadius(14).hitTestBehavior(HitTestMode.None)
      Row({ space: 0 }) {
      Button() { Text(this.client.selectedModel ? (this.model()?.name || this.client.selectedModel) : '默认模型').fontSize(12).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }.height(44).layoutWeight(1).backgroundColor(Color.Transparent).padding({ left: 10, right: 6 }).id('model-selector').accessibilityText('选择模型').enabled(this.client.authenticated)
        .onClick(() => { this.error = ''; this.showEffort = false; this.showModels = !this.showModels; this.client.loadModelSettings().catch((e: Error) => { this.error = this.client.userFacingError(e); }); })
      Button() { Row({ space: 4 }) { if (this.fast()) { SymbolGlyph($r('sys.symbol.bolt_fill')).fontSize(12).fontColor([AppTheme.accent]) } Text(this.effortLabel(this.client.selectedEffort)).fontSize(12).fontColor(AppTheme.secondary); SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(10).fontColor([AppTheme.secondary]) } }
        .height(44).constraintSize({ minWidth: 44 }).padding({ left: 4, right: 10 }).backgroundColor(Color.Transparent).id('effort-selector').accessibilityText('选择推理强度').enabled(this.client.authenticated && this.client.selectedModel.length > 0 && this.client.projects.some((p) => p.id === this.client.selectedProjectId && p.capability === 'control'))
        .onClick(() => { const m = this.model(); this.selectedStep = Math.max(0, m?.efforts.indexOf(this.client.selectedEffort || m.defaultEffort) ?? 0); this.error = ''; this.showModels = false; this.showEffort = !this.showEffort; if (this.showEffort) { this.client.loadModelSettings().then(() => { const actual = this.model(); this.selectedStep = Math.max(0, actual?.efforts.indexOf(this.client.selectedEffort || actual.defaultEffort) ?? 0); }).catch((e: Error) => { this.error = this.client.userFacingError(e); }); } })
      }.height(44).width('100%')
    }.height(44).width('100%')
      .bindPopup(this.showEffort || this.showModels, { builder: this.ActiveMenu, placement: Placement.TopRight, popupColor: AppTheme.fallbackColor(this.client.reduceTransparency), backgroundBlurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), radius: 24, keyboardAvoidMode: KeyboardAvoidMode.DEFAULT, onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible) { this.showEffort = false; this.showModels = false; } } })
  }
}
