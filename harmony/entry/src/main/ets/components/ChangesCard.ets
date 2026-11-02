import { AppTheme } from '../theme/AppTheme';
import { ChangeSummary, ChangedFile } from '../model/UiState';
@Component
export struct ChangesCard {
  @Prop review: ChangeSummary = { turnId: '', version: '', files: [], added: 0, removed: 0, partial: false };
  @Prop compact: boolean = false;
  onOpen: () => void = () => {};
  @State private expanded: boolean = false;
  build() {
    if (this.compact) {
      Button() {
        Row({ space: 6 }) {
          Text((this.review.partial ? '部分变更 · ' : '已更改 ') + this.review.files.length + ' 个文件').fontSize(12).fontColor(AppTheme.secondary).maxLines(1)
          Text('+' + this.review.added).fontSize(12).fontColor(AppTheme.success)
          Text('−' + this.review.removed).fontSize(12).fontColor(AppTheme.error)
        }.padding({ left: 12, right: 12 }).height(32).backgroundColor(AppTheme.subtle).border({ width: 0.7, color: AppTheme.border }).borderRadius(12)
      }.id('changes-compact-' + this.review.turnId).type(ButtonType.Normal).height(44).padding(0).backgroundColor(Color.Transparent).alignSelf(ItemAlign.Start).accessibilityText('查看本轮代码变更').onClick(() => { this.onOpen(); })
    } else {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.doc_text')).fontSize(20).fontColor([AppTheme.secondary])
        Column({ space: 4 }) {
          Text(this.review.partial ? '部分变更记录' : '已编辑 ' + this.review.files.length + ' 个文件').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
          Row({ space: 8 }) { Text('+' + this.review.added).fontSize(12).fontColor(AppTheme.success); Text('−' + this.review.removed).fontSize(12).fontColor(AppTheme.error) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('查看变更').id('open-changes').height(44).fontSize(12).padding({ left: 10, right: 10 }).fontColor(AppTheme.text).backgroundColor(Color.Transparent).onClick(() => { this.onOpen(); })
      }.padding({ left: 14, right: 8, top: 8, bottom: 8 }).width('100%')
      Divider().color(AppTheme.border)
      ForEach(this.review.files.slice(0, this.expanded ? this.review.files.length : 3), (file: ChangedFile) => {
        Row({ space: 8 }) { Text(file.path).fontSize(12).lineHeight(18).fontColor(AppTheme.secondary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1); Text('+' + file.added).fontSize(11).fontColor(AppTheme.success); Text('−' + file.removed).fontSize(11).fontColor(AppTheme.error) }.id('changed-file-' + file.id).padding({ left: 14, right: 14, top: 8, bottom: 8 }).width('100%')
      }, (file: ChangedFile) => JSON.stringify(file))
      if (this.review.files.length > 3) { Button(this.expanded ? '收起文件' : '显示另外 ' + (this.review.files.length - 3) + ' 个文件').id('expand-changes').height(44).width('100%').fontSize(12).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).onClick(() => { this.expanded = !this.expanded; }) }
    }.id('changes-card-' + this.review.turnId).width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.7, color: AppTheme.border }).borderRadius(16).clip(true)
    }
  }
}
