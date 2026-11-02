import { AppTheme } from '../theme/AppTheme';
import { UiState, ChangedFile } from '../model/UiState';
import { DiffLine, diffLines } from '../model/DiffLines';
@Component
export struct DiffViewer {
  @ObjectLink client: UiState;
  @State private error: string = '';
  private select(id: string): void { this.error = ''; this.client.selectDiffFile(id).catch((e: Error) => { this.error = this.client.userFacingError(e); }); }
  build() {
    Column({ space: 12 }) {
      Scroll() { Row({ space: 6 }) {
        ForEach(this.client.diffReview?.files || [], (file: ChangedFile) => {
          Button(file.path.split('/').pop() || file.path).id('diff-file-' + file.id).height(44).fontSize(12).fontColor(file.id === this.client.diffFileId ? AppTheme.text : AppTheme.secondary).backgroundColor(file.id === this.client.diffFileId ? AppTheme.selected : Color.Transparent).padding({ left: 12, right: 12 }).borderRadius(12).enabled(!this.client.diffLoading).onClick(() => { this.select(file.id); })
        }, (file: ChangedFile) => JSON.stringify(file))
      } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height(44)
      Text(this.client.diffReview?.files.find((file: ChangedFile) => file.id === this.client.diffFileId)?.path || '代码变更').id('diff-path').fontSize(12).lineHeight(19).fontColor(AppTheme.secondary).width('100%').copyOption(CopyOptions.LocalDevice)
      if (this.error) { Text(this.error).fontSize(12).fontColor(AppTheme.error).width('100%') }
      Scroll() {
        Column({ space: 12 }) {
          Scroll() { Column({ space: 0 }) {
            ForEach(diffLines(this.client.diffText), (line: DiffLine, index: number) => {
              Row({ space: 6 }) {
                Text(line.oldNumber).width(28).fontSize(10).fontFamily('monospace').fontColor(AppTheme.muted).textAlign(TextAlign.End)
                Text(line.newNumber).width(28).fontSize(10).fontFamily('monospace').fontColor(AppTheme.muted).textAlign(TextAlign.End)
                Text(line.text || ' ').id('diff-line-' + index).fontSize(12).fontFamily('monospace').fontColor(line.kind === 'add' ? AppTheme.success : line.kind === 'remove' ? AppTheme.error : line.kind === 'hunk' ? AppTheme.accent : AppTheme.text).maxLines(1).copyOption(CopyOptions.LocalDevice).padding({ right: 12 })
              }.height(23).constraintSize({ minWidth: '100%' }).backgroundColor(line.kind === 'add' ? '#1237B76B' : line.kind === 'remove' ? '#12E35B67' : Color.Transparent)
            }, (line: DiffLine, index: number) => JSON.stringify([index, line]))
          }.alignItems(HorizontalAlign.Start).constraintSize({ minWidth: '100%' }) }.id('diff-code').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto).width('100%')
          if (!this.client.diffText && !this.client.diffLoading) { Text('此记录没有文本补丁').fontSize(13).fontColor(AppTheme.secondary).padding(16) }
          if (this.client.diffLoading) { LoadingProgress().width(24).height(24) }
          if (this.client.diffMore) { Button('继续加载变更').id('diff-more').height(44).fontSize(12).fontColor(AppTheme.secondary).backgroundColor(Color.Transparent).enabled(!this.client.diffLoading).onClick(() => { this.client.loadMoreDiff().catch((e: Error) => { this.error = this.client.userFacingError(e); }); }) }
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto).align(Alignment.TopStart)
    }.padding({ left: 14, right: 14, top: 8 }).height('100%').width('100%')
  }
}
