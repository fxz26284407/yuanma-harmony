import { QuestionCard } from './QuestionCard';
import { AppTheme } from '../theme/AppTheme';
import { LengthMetrics } from '@kit.ArkUI';
import { UiState, ImageReference } from '../model/UiState';
import { MediaTile } from './MediaTile';
import { ExecutionLabel } from './ExecutionLabel';
import { MessageView } from '../model/UiState';
import { ExtensionIcon } from './ExtensionIcon';
import { ExtensionItem } from '../model/UiTypes';
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
  private resetExpansion(): void { this.expanded = ''; this.detail = ''; this.onChatChanged(); }
  aboutToAppear(): void { this.expanded = ''; this.detail = ''; this.onChatChanged(); }
  onChatChanged: () => void = () => {};
  onRead: (message: MessageView) => void = () => {};
  onChanges: (turnId: string) => void = () => {};
  @State private expanded: string = '';
  @State private detail: string = '';
  private latest(group: TranscriptGroup): MessageView { return group.items[group.items.length - 1]; }
  private summary(message: MessageView): string {
    const info = message.execution;
    if (!info) { return '执行记录'; }
    return info.label + (info.durationMs !== undefined ? ' · ' + (info.durationMs < 1000 ? info.durationMs + 'ms' : (info.durationMs / 1000).toFixed(1) + 's') : '');
  }
  private icon(group: TranscriptGroup): Resource {
    const kind = this.latest(group).execution?.kind;
    if (kind === 'image') { return $r('sys.symbol.ohos_photo'); }
    if (kind === 'read' || kind === 'write' || kind === 'edit' || kind === 'fileChange') { return $r('sys.symbol.doc_text'); }
    if (kind === 'list') { return $r('sys.symbol.folder'); }
    if (kind === 'search' || kind === 'webSearch') { return $r('sys.symbol.magnifyingglass'); }
    if (kind === 'agent') { return $r('sys.symbol.person_2'); }
    if (kind === 'plan') { return $r('sys.symbol.list_bullet'); }
    return $r('sys.symbol.code_square');
  }
  private groups(): TranscriptGroup[] {
    const groups: TranscriptGroup[] = [];
    for (const message of this.messages) {
      if (!this.client.showReasoning && message.execution?.kind === 'reasoning') { continue; }
      const prior = groups[groups.length - 1];
      if (message.role === 'tool' && prior?.tool && prior.items[0].turnId === message.turnId &&
        message.execution?.kind !== 'compaction' && prior.items[0].execution?.kind !== 'compaction') {
        prior.items.push(message);
      } else {
        groups.push(new TranscriptGroup(message));
      }
    }
    return groups;
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
        if (group.tool && group.items[0].execution?.kind === 'compaction') {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.doc_text')).fontSize(16).fontColor([AppTheme.secondary])
            ExecutionLabel({ label: this.summary(this.latest(group)), running: this.latest(group).status === 'running', failed: this.latest(group).status === 'failed', reduceMotion: this.reduceMotion }).layoutWeight(1)
          }.id('compaction-' + group.id).height(28).width('100%').accessibilityText(this.summary(this.latest(group)))
        } else if (group.tool) {
          Column({ space: 6 }) {
            Button() {
              Row({ space: 8 }) {
                SymbolGlyph(this.icon(group)).fontSize(16).fontColor([AppTheme.secondary])
                ExecutionLabel({ label: this.summary(this.latest(group)), running: this.latest(group).status === 'running', failed: this.latest(group).status === 'failed', reduceMotion: this.reduceMotion }).layoutWeight(1)
                if (group.items.length > 1) {
                  Text('+' + group.items.length).fontSize(11).fontColor(AppTheme.secondary)
                    .padding({ left: 6, right: 6 }).backgroundColor(AppTheme.contentSurface).borderRadius(8)
                }
                SymbolGlyph(this.expanded === group.id ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppTheme.secondary])
              }.width('100%').height(28)
            }.id('execution-' + group.id).type(ButtonType.Normal).height(28).padding(0).width('100%').backgroundColor(Color.Transparent).accessibilityText(this.summary(this.latest(group))).accessibilityDescription(this.expanded === group.id ? '点按收起执行内容' : '点按展开执行内容').onClick(() => { this.expanded = this.expanded === group.id ? '' : group.id; this.detail = ''; })
            if (this.expanded === group.id) {
              ForEach(group.items, (message: MessageView) => {
                Column({ space: 4 }) {
                  if (group.items.length > 1) {
                    Button() {
                      Row({ space: 6 }) {
                        ExecutionLabel({ label: this.summary(message), running: message.status === 'running', failed: message.status === 'failed', reduceMotion: this.reduceMotion }).layoutWeight(1)
                        SymbolGlyph(this.detail === message.id ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppTheme.secondary])
                      }.width('100%')
                    }.width('100%').height(32).backgroundColor(Color.Transparent)
                      .onClick(() => { this.detail = this.detail === message.id ? '' : message.id; })
                  }
                  if (group.items.length === 1 || this.detail === message.id) {
                Column({ space: 6 }) { if (message.execution?.kind === 'fileChange') { Button('查看代码变更').id('view-item-changes-' + message.id).height(44).fontSize(12).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).onClick(() => { this.onChanges(message.turnId); }) } else if (message.text && message.execution?.kind === 'reasoning') { MarkdownBody({ text: message.text }) } else if (message.text) { Text(message.text).fontSize(12).lineHeight(18).fontFamily('monospace').fontColor(AppTheme.secondary).copyOption(CopyOptions.LocalDevice) } if (message.images.length > 0) { this.Images(message) } if (message.hasMore && message.execution?.kind !== 'fileChange') { this.ReadLink(message) } }.padding(message.text ? 12 : 0).width('100%').backgroundColor(message.text ? AppTheme.contentSurface : Color.Transparent).borderRadius(12).alignItems(HorizontalAlign.Start)
                  }
                }.width('100%')
              }, (m: MessageView) => JSON.stringify(m))
            }
          }.width('100%')
        } else {
          ForEach(group.items, (message: MessageView) => {
            Row() {
              Column({ space: 6 }) {
                if (this.client.selectedAgent === 'antigravity' && message.role === 'user' && message.references.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
                    ForEach(message.references, (ref: ExtensionItem) => {
                      Row({ space: 6 }) { ExtensionIcon({ client: this.client, item: ref, appearance: this.client.appearance, revision: this.client.extensionIconVersion, iconSize: 18 }); Text(ref.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.text) }.padding({ left: 10, right: 10, top: 6, bottom: 6 }).backgroundColor(AppTheme.contentSurface).borderRadius(18)
                    }, (ref: ExtensionItem) => ref.id)
                  }.width('100%')
                }
                if (message.question) { QuestionCard({ client: this.client, request: message.question, inline: true }) } else if (message.role === 'user' && message.text) { Text(message.text.trimEnd()).fontSize(14).lineHeight(20).fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice) } else if (message.role !== 'user' && message.text) { MarkdownBody({ text: message.text }) }
                if (message.images.length > 0) { this.Images(message) }
                if (message.hasMore) { this.ReadLink(message) }
              }.padding(message.role === 'user' && !(this.client.selectedAgent === 'antigravity' && message.references.length > 0 && !message.text && !message.images.length) ? 12 : 0).width(message.role === 'user' ? (message.images.length > 0 ? '90%' : LayoutPolicy.wrapContent) : '100%').constraintSize({ maxWidth: message.role === 'user' ? '90%' : '100%' }).borderRadius(20).alignItems(HorizontalAlign.Start).backgroundColor(message.role === 'user' && !(this.client.selectedAgent === 'antigravity' && message.references.length > 0 && !message.text && !message.images.length) ? AppTheme.bubble : Color.Transparent)
                .onVisibleAreaChange([0], (visible: boolean) => { if (visible && message.role === 'assistant' && message.hasMore) { this.client.loadAssistantText(message).catch(() => {}); } })
            }.id('message-' + message.id).width('100%').justifyContent(FlexAlign.End)
          }, (m: MessageView) => m.id)
        }
      }, (g: TranscriptGroup) => JSON.stringify(g))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
