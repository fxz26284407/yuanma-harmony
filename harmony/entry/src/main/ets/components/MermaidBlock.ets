import { buildMermaidHtml } from '@luvi/lv-markdown-in/src/main/ets/enhance/utils/MermaidHtmlBuilder';
import { webview } from '@kit.ArkWeb';
import { fileIo as fs } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppTheme } from '../theme/AppTheme';

function compatibleFlowchart(source: string): string {
  if (!/^\s*(?:flowchart|graph)\b/.test(source)) { return source; }
  return source.split('\n').map((line: string): string => {
    if (line.trimStart().startsWith('%%')) { return line; }
    return line.replace(/"(?:[^"\\]|\\.)*"|\b([A-Za-z_][\w-]*)\[([^\[\]\r\n]*)\](?!\])/g,
      (node: string, id: string = '', label: string = ''): string => {
        // Quoted labels and cylinder/parallelogram shapes already have their own syntax.
        if (!id || /^["`(/\\]/.test(label.trimStart()) || !/[()]|\\n/.test(label)) { return node; }
        return id + '["' + label.replace(/"/g, '#quot;').replace(/\\n/g, '<br/>') + '"]';
      });
  }).join('\n');
}

function scriptString(value: string): string { return JSON.stringify(value).replace(/</g, '\\u003c'); }

@Component
export struct MermaidBlock {
  @Prop @Watch('reload') encodedSource: string = '';
  @StorageLink('appAppearance') @Watch('reload') private appearance: string = 'dark';
  @State private code: boolean = false;
  @State private fullscreen: boolean = false;
  @State private src: string = '';
  @State private failed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private fullController: webview.WebviewController = new webview.WebviewController();
  private version: number = 0;
  private path: string = '';
  private source(): string { try { return decodeURIComponent(this.encodedSource); } catch (_) { return this.encodedSource; } }
  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { this.version++; this.removeFile(); }
  private removeFile(): void { if (this.path) { try { fs.unlinkSync(this.path); } catch (_) {} this.path = ''; } }
  private async reload(): Promise<void> {
    const version: number = ++this.version; const source: string = this.source();
    this.failed = false;
    try {
      const context = this.getUIContext().getHostContext()!;
      const light: boolean = this.appearance === 'light';
      // Reuse the pinned dependency's Mermaid engine and bundled offline runtime.
      let html = await buildMermaidHtml(context, source, light ? 'default' : 'dark', 'strict', light ? 'light' : 'dark');
      html = html.replace(JSON.stringify(source), scriptString(source));
      const compatible: string = compatibleFlowchart(source);
      if (compatible !== source) {
        // Parse the original first; only retry legacy unquoted labels when it is invalid.
        const render: string = 'mermaid.render("lv_mermaid_diagram", diagram)';
        if (!html.includes(render)) { throw new Error('Unsupported Mermaid HTML builder'); }
        html = html.replace(render, 'mermaid.parse(diagram).then(function() { return diagram; }, function() { return ' +
          scriptString(compatible) + '; }).then(function(text) { return mermaid.render("lv_mermaid_diagram", text); })');
      }
      if (version !== this.version) { return; }
      this.src = ''; this.removeFile();
      this.path = context.cacheDir + '/yuanma-mermaid-' + Date.now() + '-' + Math.random().toString(36).slice(2) + '.html';
      const file = fs.openSync(this.path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try { fs.writeSync(file.fd, html); } finally { fs.closeSync(file); }
      this.src = 'file://' + this.path;
    } catch (_) { if (version === this.version) { this.failed = true; } }
  }
  private copy(): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.source()))
      .then(() => { this.getUIContext().getPromptAction().showToast({ message: '代码已复制' }); })
      .catch(() => { this.getUIContext().getPromptAction().showToast({ message: '复制失败，请长按选择源码' }); });
  }
  @Builder
  private diagram(controller: webview.WebviewController) {
    if (this.failed) { Text('图表加载失败，请查看源码').fontColor(AppTheme.secondary).padding(12) }
    else if (this.src) {
      Web({ src: this.src, controller: controller }).javaScriptAccess(true).fileAccess(true).blockNetwork(true)
        .domStorageAccess(false).width('100%').height('100%')
    } else { LoadingProgress().width(32).height(32).color(AppTheme.accent) }
  }
  @Builder
  private fullView() {
    Column() {
      Row() {
        Text('Mermaid').fontSize(16).fontColor(AppTheme.text).layoutWeight(1)
        Button('关闭').id('mermaid-close').height(44).backgroundColor(Color.Transparent).fontColor(AppTheme.text).onClick(() => { this.fullscreen = false; })
      }.height(52).flexShrink(0).width('100%').padding({ left: 16, right: 8 })
      Stack() {
        if (this.code) {
          Scroll() { Text(this.source()).fontSize(13).fontFamily('monospace').fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice).width('100%').padding(12) }.width('100%').height('100%')
        } else { this.diagram(this.fullController) }
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(AppTheme.background)
  }
  build() {
    Column() {
      Row({ space: 4 }) {
        if (this.code) {
          Button() { SymbolGlyph($r('sys.symbol.eye')).fontSize(18).fontColor([AppTheme.text]) }
            .id('mermaid-preview').width(44).height(44).backgroundColor(Color.Transparent)
            .accessibilityText('显示图表').onClick(() => { this.code = false; })
        }
        Button('mermaid').id('mermaid-source').height(44).fontSize(13).fontColor(AppTheme.secondary)
          .backgroundColor(Color.Transparent).accessibilityText('查看 Mermaid 源码').onClick(() => { this.code = true; })
        Blank()
        Button() { Image(this.appearance === 'light' ? $rawfile('imgs/plus_square_on_square_fill_b.png') : $rawfile('imgs/plus_square_on_square_fill_w.png')).width(18).height(18) }
          .width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('复制 Mermaid 源码').onClick(() => { this.copy(); })
        Button() { SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right')).fontSize(18).fontColor([AppTheme.text]) }
          .id('mermaid-expand').width(44).height(44).backgroundColor(Color.Transparent).accessibilityText(this.code ? '展开源码' : '展开图表')
          .onClick(() => { this.fullscreen = true; })
      }.width('100%').padding({ left: 8, right: 4 }).backgroundColor(AppTheme.codeSurface)
      Stack() {
        if (this.code) {
          Scroll() { Text(this.source()).fontSize(13).fontFamily('monospace').fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice).width('100%').padding(12) }
            .width('100%').height('100%').align(Alignment.TopStart)
        } else { this.diagram(this.controller) }
      }.width('100%').height(300)
    }.width('100%').backgroundColor(AppTheme.contentSurface).borderRadius(12).clip(true)
      .bindContentCover(this.fullscreen, this.fullView)
  }
}
