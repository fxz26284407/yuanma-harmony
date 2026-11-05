import { AppTheme } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Markdown, MarkdownController, MarkdownPlugin, PluginNode } from '@luvi/lv-markdown-in';
import { MermaidBlock } from './MermaidBlock';

@Builder
function mermaidBlock(node: PluginNode) {
  MermaidBlock({ encodedSource: node.groups?.[0] || '' })
}

const MERMAID_PLUGINS: MarkdownPlugin[] = [{ key: 'yuanma-mermaid', display: 'block',
  pattern: '^<yuanma-mermaid ([^<>\\s]*)>$', matchMode: 'full-line', render: wrapBuilder(mermaidBlock) }];

function mermaidBlocks(text: string): string {
  const lines = text.split('\n'); const result: string[] = [];
  let fence: string = ''; let length: number = 0; let start: number = -1; let mermaid: boolean = false;
  let prefix: string = ''; let contentPrefix: string = '';
  for (let index: number = 0; index < lines.length; index++) {
    const marker = /^((?:[ \t]*>[ \t]?)*[ \t]*(?:(?:[-+*]|\d+[.)])[ \t]+)?)(`{3,}|~{3,})(.*)$/.exec(lines[index]);
    if (!fence && marker && !(marker[2][0] === '`' && marker[3].includes('`'))) {
      fence = marker[2][0]; length = marker[2].length; start = index; prefix = marker[1];
      contentPrefix = prefix.replace(/(?:[-+*]|\d+[.)])[ \t]+$/, (bullet: string): string => ' '.repeat(bullet.length));
      mermaid = marker[3].trim().toLowerCase() === 'mermaid';
    } else if (fence && marker && marker[2][0] === fence && marker[2].length >= length && !marker[3].trim() &&
      marker[1].replace(/[ \t]/g, '') === contentPrefix.replace(/[ \t]/g, '')) {
      if (mermaid) {
        const source = lines.slice(start + 1, index).map((line: string): string => line.startsWith(contentPrefix) ? line.slice(contentPrefix.length) : /^[ >\t]*$/.test(line) ? '' : line).join('\n');
        result.push(prefix + '<yuanma-mermaid ' + encodeURIComponent(source) + '>');
      } else { result.push(...lines.slice(start, index + 1)); }
      fence = ''; continue;
    }
    if (!fence) { result.push(lines[index]); }
  }
  // Preserve incomplete streaming blocks and fences containing Markdown examples.
  if (fence) { result.push(...lines.slice(start)); }
  return result.join('\n');
}

function displayMarkdown(text: string): string {
  let fence: string = ''; let fenceLength: number = 0; let codeLength: number = 0;
  return text.split('\n').map((line: string): string => {
    const marker = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
    if (fence) {
      if (marker && marker[1][0] === fence && marker[1].length >= fenceLength && !marker[2].trim()) { fence = ''; }
      return line;
    }
    if (marker && !codeLength) { fence = marker[1][0]; fenceLength = marker[1].length; return line; }
    if (/^( {4}|\t)/.test(line) && !codeLength) { return line; }
    let result: string = '';
    for (let index: number = 0; index < line.length;) {
      if (line[index] === '\\') { result += line.slice(index, index + 2); index += 2; continue; }
      if (line[index] === '`') {
        let end: number = index + 1; while (line[end] === '`') { end++; }
        const length: number = end - index;
        if (!codeLength) { codeLength = length; } else if (length === codeLength) { codeLength = 0; }
        result += line.slice(index, end); index = end; continue;
      }
      if (!codeLength && line[index] === ']') {
        const link = /^\]\(([ \t]*<?)file:(?=\/\/)/i.exec(line.slice(index));
        const labelStart: number = line.lastIndexOf('[', index);
        if (link && labelStart >= 0 && line[labelStart - 1] !== '!') {
          // Render Mac file references as labels; the click handler still only opens HTTP(S).
          result += '](' + link[1] + 'yuanma-file:'; index += link[0].length; continue;
        }
      }
      result += line[index++];
    }
    return result;
  }).join('\n');
}

@Component
export struct MarkdownBody {
  @Prop text: string = '';
  @StorageLink('appAppearance') @Watch('appearanceChanged') private appearance: string = 'dark';
  private controller: MarkdownController = new MarkdownController();

  aboutToAppear(): void {
    this.controller.setMermaidEnable(true).setMermaidSecurityLevel('strict')
      .setHtmlPreviewEnable(false).setHtmlPreviewJavaScriptEnable(false)
      // ponytail: use UI-thread parsing; configure a Worker if long messages cause visible stalls.
      .setThreadRenderEnable(false).setTextSelectionEnable(true)
      .setCodeCopyListener((text: string) => { this.copyText(text); })
      .setTextSelectionCopyListener((text: string) => { this.copyText(text); })
      .setHyperlinkClickListener((_title: string, href: string): boolean => { this.openLink(href); return true; });
    this.appearanceChanged();
  }
  private appearanceChanged(): void {
    const light: boolean = this.appearance === 'light';
    this.controller.setTextColor(AppTheme.text).setTextSize(14).setTextLineHeight(20)
      .setTitleColor(AppTheme.text).setTitleSize([22, 20, 18, 16, 15, 14])
      .setInlineCodeColor(AppTheme.text).setInlineCodeBackgroundColor(AppTheme.codeInline)
      .setQuoteTextColor(AppTheme.secondary).setQuoteBorderColor(AppTheme.muted).setQuoteBackgroundColor(AppTheme.rail)
      .setHyperlinkTextColor(AppTheme.accent).setHyperlinkUnderlineState(false)
      .setLineColor(AppTheme.border).setCodeBlockTheme(light ? 'light' : 'dark').setCodeBlockIdxState(false)
      .setMermaidTheme(light ? 'light' : 'dark').setLatexMathTextSize(14)
      .setLatexMathTextColor(light ? 0xFF202B3D : 0xFFD8DDE6)
      .setTableTitleTextColor(AppTheme.text).setTableTitleBackgroundColor(AppTheme.rail)
      .setTableBackgroundColor(AppTheme.contentSurface).setTableInterleaveBackgroundColor(AppTheme.contentSurface)
      .setTableOuterBorderColor(AppTheme.border).setTableInnerBorderColor(AppTheme.border);
    this.controller.setTableInterleaveTextColor(AppTheme.text);
    this.controller.setTableNormalTextColor(AppTheme.text);
  }
  private openLink(href: string): void {
    if (!/^https?:\/\//i.test(href)) { return; }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData', uri: href }).catch(() => { this.getUIContext().getPromptAction().showToast({ message: '无法打开此链接' }); });
  }
  private copyText(text: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => { this.getUIContext().getPromptAction().showToast({ message: '已复制' }); }).catch(() => { this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重新选择' }); });
  }
  build() {
    Markdown({ text: mermaidBlocks(displayMarkdown(this.text)), controller: this.controller, plugins: MERMAID_PLUGINS }).width('100%')
  }
}
