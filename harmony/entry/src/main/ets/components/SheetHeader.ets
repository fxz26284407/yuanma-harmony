import { AppTheme } from '../theme/AppTheme';
@Component
export struct SheetHeader {
  @Prop title: string = '';
  @Prop icon: Resource | undefined = undefined;
  onClose: () => void = () => {};
  build() {
    Row({ space: 8 }) {
      if (this.icon) { SymbolGlyph(this.icon).fontSize(20).fontColor([AppTheme.secondary]) }
      Text(this.title).id('sheet-title').fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      Button() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([AppTheme.secondary]) }.id('sheet-close').width(44).height(44).padding(0).backgroundColor(Color.Transparent).accessibilityText('关闭' + this.title).onClick(() => { this.onClose(); })
    }.width('100%').height(44)
  }
}
