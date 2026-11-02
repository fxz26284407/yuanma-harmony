import { UiState, ImageReference } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct MediaTile {
  @ObjectLink client: UiState;
  @Prop reference: ImageReference;
  onView: (ref: ImageReference) => void = () => {};
  @State private uri: string = '';
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  private generation: number = 0;
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }
  private async load(): Promise<void> { const generation: number = ++this.generation; this.loading = true; this.failed = false; try { const uri: string = await this.client.loadImage(this.reference); if (generation === this.generation) { this.uri = uri; } } catch (_) { if (generation === this.generation) { this.failed = true; } } finally { if (generation === this.generation) { this.loading = false; } } }
  build() {
    Button() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.uri) { Image(this.uri).id('media-thumb-' + this.reference.id).onError(() => { this.uri = ''; this.failed = true; }).width('100%').height(116).objectFit(ImageFit.Contain).borderRadius(12) }
        else if (this.loading) { LoadingProgress().height(24).width(24).color(AppTheme.accent) }
        else { Column({ space: 6 }) { SymbolGlyph($r('sys.symbol.ohos_photo')).fontSize(24).fontColor([AppTheme.secondary]); Text(this.failed ? '图片暂不可用，点按重试' : this.reference.label).fontSize(11).fontColor(AppTheme.secondary).textAlign(TextAlign.Center) }.padding(8) }
      }.width('100%').height(116)
    }.id('media-' + this.reference.id).type(ButtonType.Normal).width('100%').height(116).padding(0).backgroundColor(AppTheme.contentSurface).borderRadius(12).border({ width: 0.6, color: AppTheme.border }).accessibilityText('查看' + this.reference.label)
      .onClick(() => { if (this.uri) { this.onView(this.reference); } else if (!this.loading) { this.load(); } })
  }
}
