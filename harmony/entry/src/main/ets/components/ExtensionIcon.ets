import { UiState, ExtensionItem } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct ExtensionIcon {
  @ObjectLink client: UiState;
  @Prop item: ExtensionItem;
  @Prop @Watch('reset') appearance: string = 'dark';
  @Prop @Watch('reset') revision: number = 0;
  @Prop iconSize: number = 22;
  @State private uri: string = '';
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  private visible: boolean = false;
  private generation: number = 0;
  private reset(): void { this.generation++; this.uri = ''; this.loading = false; this.failed = false; if (this.visible) { this.load(); } }
  private async load(): Promise<void> {
    if (this.loading || this.uri || this.failed || !this.item.iconId) { return; }
    const generation: number = ++this.generation; this.loading = true;
    try { const uri = await this.client.loadExtensionIcon(this.item); if (generation === this.generation) { this.uri = uri; } }
    catch (_) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; } }
  }
  aboutToDisappear(): void { this.generation++; this.visible = false; }
  build() {
    Stack() {
      if (this.uri) { Image(this.uri).width(this.iconSize).height(this.iconSize).objectFit(ImageFit.Contain).onError(() => { this.uri = ''; this.failed = true; }) }
      else { SymbolGlyph(this.item.kind === 'skill' ? $r('sys.symbol.doc_text') : $r('sys.symbol.rectangle_on_rectangle')).fontSize(this.iconSize).fontColor([AppTheme.accent]) }
    }.width(this.iconSize).height(this.iconSize).accessibilityText(this.item.name + '图标')
      .onVisibleAreaChange([0], (visible: boolean) => { this.visible = visible; if (visible) { this.load(); } })
  }
}
