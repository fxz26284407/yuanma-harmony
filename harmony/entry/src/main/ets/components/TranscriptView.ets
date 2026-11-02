import { QuestionCard } from './QuestionCard';
import { AppTheme } from '../theme/AppTheme';
import { LengthMetrics } from '@kit.ArkUI';
import { UiState, ImageReference } from '../model/UiState';
import { MediaTile } from './MediaTile';
import { ExecutionLabel } from './ExecutionLabel';
import { MessageView } from '../model/UiState';
import { MarkdownBody } from './MarkdownBody';
class TranscriptGroup {
  id: string; tool: boolean; items: MessageView[];
  constructor(item: MessageView) { this.id = item.id; this.tool = item.role === 'tool'; this.items = [item]; }
}
@Component
export struct TranscriptView {
  @ObjectLink client: UiState;
  onViewImage: (ref: ImageReference) => void = () => {};
  @Prop reduceMotion: boolean = false;
  @Prop messages: MessageView[] = [];
  @Prop @Watch('resetExpansion') threadId: string = '';
  private resetExpansion(): void { this.expanded = ''; this.onChatChanged(); }
  aboutToAppear(): void { this.expanded = ''; this.onChatChanged(); }
  onChatChanged: () => void = () => {};
  onRead: (message: MessageView) => void = () => {};
  onChanges: (turnId: string) => void = () => {};
  @State private expanded: string = '';
  private summary(group: TranscriptGroup): string {
    const first = group.items[0]; const info = first.execution;
    if (!info) { return '执行记录'; }
    if (info.kind === 'image' && group.items.length > 1) { return (first.status === 'running' ? '正在查看 ' : '已查看 ') + group.items.length + ' 张图片'; }
    if (group.items.length > 1) { return info.label + '（' + group.items.length + ' 项）'; }
    return info.label + (info.durationMs !== undefined ? ' · ' + (info.durationMs < 1000 ? info.durationMs + 'ms' : (info.durationMs / 1000).toFixed(1) + 's') : '');
  }
  private icon(group: TranscriptGroup): Resource {
    const kind = group.items[0].execution?.kind;
    if (kind === 'image') { return $r('sys.symbol.ohos_photo'); }
    if (kind === 'read' || kind === 'fileChange') { return $r('sys.symbol.doc_text'); }
    if (kind === 'list') { return $r('sys.symbol.folder'); }
    if (kind === 'search' || kind === 'webSearch') { return $r('sys.symbol.magnifyingglass'); }
    if (kind === 'agent') { return $r('sys.symbol.person_2'); }
    if (kind === 'plan') { return $r('sys.symbol.list_bullet'); }
    return $r('sys.symbol.code_square');
  }
  private groups(): TranscriptGroup[] {
    const groups: TranscriptGroup[] = [];
    this.messages.forEach((m: MessageView) => { const prior = groups.length > 0 ? groups[groups.length - 1] : undefined; if (m.role === 'tool' && prior?.tool && prior.items[0].execution?.kind === m.execution?.kind && prior.items[0].status === m.status) { prior.items.push(m); } else { groups.push(new TranscriptGroup(m)); } }); return groups;
  }
  @Builder
  private Images(message: MessageView) {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) { ForEach(message.images, (ref: ImageReference) => { MediaTile({ client: this.client, reference: ref, onView: this.onViewImage }).width('47%') }, (ref: ImageReference) => ref.id) }.width('100%')
  }
  @Builder
  private ReadLink(message: MessageView) {
    Button() { Row({ space: 5 }) { SymbolGlyph($r('sys.symbol.doc_text')).fontSize(13).fontColor([AppTheme.secondary]); Text('查看全文').fontSize(12).fontColor(AppTheme.secondary); SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10).fontColor([AppTheme.secondary]) }.height(24) }
      .id('read-' + message.id).type(ButtonType.Normal).height(44).padding(0).backgroundColor(Color.Transparent).alignSelf(ItemAlign.Start).accessibilityText('查看完整内容').onClick(() => { this.onRead(message); })
  }
  build() {
    Column({ space: 6 }) {
      ForEach(this.groups(), (group: TranscriptGroup) => {
        if (group.tool) {
          Column({ space: 6 }) {
            Button() {
              Row({ space: 8 }) {
                SymbolGlyph(this.icon(group)).fontSize(16).fontColor([AppTheme.secondary])
                ExecutionLabel({ label: this.summary(group), running: group.items[0].status === 'running', failed: group.items[0].status === 'failed', reduceMotion: this.reduceMotion }).layoutWeight(1)
                SymbolGlyph(this.expanded === group.id ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppTheme.secondary])
              }.width('100%').height(28)
            }.id('execution-' + group.id).type(ButtonType.Normal).height(28).padding(0).width('100%').backgroundColor(Color.Transparent).accessibilityText(this.summary(group)).accessibilityDescription(this.expanded === group.id ? '点按收起执行内容' : '点按展开执行内容').onClick(() => { this.expanded = this.expanded === group.id ? '' : group.id; })
            if (this.expanded === group.id) {
              ForEach(group.items, (message: MessageView) => {
                Column({ space: 6 }) { if (message.execution?.kind === 'fileChange') { Button('查看代码变更').id('view-item-changes-' + message.id).height(44).fontSize(12).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).onClick(() => { this.onChanges(message.turnId); }) } else if (message.text) { Text(message.text).fontSize(12).lineHeight(18).fontFamily('monospace').fontColor(AppTheme.secondary).copyOption(CopyOptions.LocalDevice) } if (message.images.length > 0) { this.Images(message) } if (message.hasMore && message.execution?.kind !== 'fileChange') { this.ReadLink(message) } }.padding(message.text ? 12 : 0).width('100%').backgroundColor(message.text ? AppTheme.contentSurface : Color.Transparent).borderRadius(12).alignItems(HorizontalAlign.Start)
              }, (m: MessageView) => m.id)
            }
          }.width('100%')
        } else {
          ForEach(group.items, (message: MessageView) => {
            Row() {
              if (message.role === 'user') { Blank().width('10%') }
              Column({ space: 6 }) {
                if (message.question) { QuestionCard({ client: this.client, request: message.question, inline: true }) } else if (message.role === 'user' && message.text) { Text(message.text).fontSize(14).lineHeight(20).fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice) } else if (message.role !== 'user' && message.text) { MarkdownBody({ text: message.text }) }
                if (message.images.length > 0) { this.Images(message) }
                if (message.hasMore) { this.ReadLink(message) }
              }.padding(message.role === 'user' ? 12 : 0).layoutWeight(1).borderRadius(20).alignItems(HorizontalAlign.Start).backgroundColor(message.role === 'user' ? AppTheme.bubble : Color.Transparent)
            }.id('message-' + message.id).width('100%')
          }, (m: MessageView) => m.id)
        }
      }, (g: TranscriptGroup) => JSON.stringify(g))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
