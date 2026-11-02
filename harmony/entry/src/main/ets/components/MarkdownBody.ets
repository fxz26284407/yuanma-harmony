import { AppTheme } from '../theme/AppTheme';
import { LengthMetrics } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { BaseEngine, EMarkdownMode, Log, Markdown, Link, IMarkdownNodeClickEvent, ITextComponentSelectionOption, IMarkdownCodeComponentActionClickEvent, EContentBoxAction, IContentBoxBar } from 'fluid-markdown';

function markdownEngine(light: boolean = false): BaseEngine {
  // Conversation text must never be written to the renderer's diagnostic log.
  Log.on = () => false;
  const engine = new BaseEngine(); const theme = engine.theme.theme;
  theme.document!.font!.fontColor = AppTheme.text; theme.document!.font!.fontSize = LengthMetrics.vp(14); theme.document!.lineHeight = { height: LengthMetrics.vp(20) }; theme.document!.blockSpace = LengthMetrics.vp(8);
  theme.link!.font!.fontColor = AppTheme.accent; theme.quote!.font!.fontColor = AppTheme.secondary; theme.quote!.edgeColor = AppTheme.muted;
  theme.inlineCode!.font = { fontFamily: 'monospace', fontColor: AppTheme.text }; theme.inlineCode!.background!.color = AppTheme.codeInline;
  theme.contentBox!.headerFont!.fontColor = AppTheme.secondary; theme.contentBox!.headerBackgroundColor = AppTheme.codeSurface; theme.contentBox!.barFont!.fontColor = AppTheme.secondary; theme.contentBox!.barBackgroundColor = AppTheme.codeSurface; theme.contentBox!.border!.color = AppTheme.border;
  theme.table!.headerFont!.fontColor = AppTheme.text; theme.table!.headerBackgroundColor = AppTheme.rail; theme.table!.contentFont!.fontColor = AppTheme.text;
  theme.listItem!.contentTopBoxBackgroundColor = AppTheme.rail; theme.listItem!.contentTopBadgeBackgroundColor = AppTheme.secondary; theme.listItem!.contentBadgeBackgroundColor = AppTheme.secondary; theme.listItem!.taskFlagColor = AppTheme.accent;
  const css = engine.code.css; const dark = engine.css.parse(light ? '.hljs{color:#202B3D;background:#EBEFF5}.hljs-keyword,.hljs-selector-tag,.hljs-literal{color:#6C3BB4}.hljs-string,.hljs-attr{color:#2B7445}.hljs-title,.hljs-function{color:#285BA7}.hljs-number{color:#9E4C12}.hljs-comment{color:#667284}' : '.hljs{color:#D8DDE6;background:#252C38}.hljs-keyword,.hljs-selector-tag,.hljs-literal{color:#C5AEF2}.hljs-string,.hljs-attr{color:#99C9B0}.hljs-title,.hljs-function{color:#A9C7ED}.hljs-number{color:#EDBB91}.hljs-comment{color:#99A5B6}').data;
  if (css.type === 'StyleSheet' && dark?.type === 'StyleSheet') { css.children.appendList(dark.children); }
  return engine;
}

@Component
export struct MarkdownBody {
  @Prop text: string = '';
  @StorageLink('appAppearance') @Watch('appearanceChanged') private appearance: string = 'dark';
  @State private engine: BaseEngine = markdownEngine(this.appearance === 'light');
  private appearanceChanged(): void { this.engine = markdownEngine(this.appearance === 'light'); }
  private openLink(event: IMarkdownNodeClickEvent): void {
    if (!(event.node instanceof Link) || !event.node.href || !/^https?:\/\//i.test(event.node.href)) { return; }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData', uri: event.node.href }).catch(() => { this.getUIContext().getPromptAction().showToast({ message: '无法打开此链接' }); });
  }
  private copyCode(event: IMarkdownCodeComponentActionClickEvent): void {
    if (event.codeEvent.action.tag !== EContentBoxAction.Copy) { return; }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, event.codeEvent.bridge.codeContent);
    pasteboard.getSystemPasteboard().setData(data).then(() => { this.getUIContext().getPromptAction().showToast({ message: '代码已复制' }); }).catch(() => { this.getUIContext().getPromptAction().showToast({ message: '复制失败，请长按选择代码' }); });
  }
  build() {
    Markdown({ content: this.text, mode: EMarkdownMode.Normal, engine: this.engine,
      onMarkdownNodeClick: (event: IMarkdownNodeClickEvent) => { this.openLink(event); },
      onMarkdownTextComponentSelectionOption: (): ITextComponentSelectionOption => ({ enableSelection: true }),
      onMarkdownCodeComponentActionClick: (event: IMarkdownCodeComponentActionClickEvent) => { this.copyCode(event); },
      onMarkdownTableComponentContentBoxBar: (): IContentBoxBar => ({ title: '表格', actions: [] })
    }).width('100%')
  }
}
