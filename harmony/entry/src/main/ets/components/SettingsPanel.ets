import { SheetHeader } from './SheetHeader';
import { UiState, ProjectItem } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
@Component
export struct SettingsPanel {
  @ObjectLink client: UiState;
  onNavigate: (page: string) => void = () => {};
  @State private info: string = '';
  @State private infoTitle: string = '';
  @Builder
  private InfoRow(icon: Resource, title: string, value: string, action: () => void) {
    Button() { Row({ space: 12 }) { SymbolGlyph(icon).fontSize(20).fontColor([AppTheme.secondary]); Text(title).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if (value) { Text(value).fontSize(12).fontColor(AppTheme.secondary) } SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppTheme.muted]) }.padding({ left: 16, right: 16 }).height(54).width('100%') }
      .type(ButtonType.Normal).width('100%').height(54).backgroundColor(Color.Transparent).onClick(() => { this.infoTitle = title; action(); })
  }
  @Builder
  private Details() {
    Column({ space: 16 }) {
      SheetHeader({ title: this.infoTitle || '提示', onClose: () => { this.info = ''; } })
      Scroll() {
        if (this.infoTitle === '项目访问权限' && this.client.projects.length > 0) {
          Column({ space: 8 }) {
            ForEach(this.client.projects, (project: ProjectItem) => {
              Row({ space: 12 }) {
                Stack() { SymbolGlyph($r('sys.symbol.folder')).fontSize(18).fontColor([AppTheme.secondary]) }.width(32).height(32).backgroundColor(AppTheme.subtle).borderRadius(9)
                Text(project.name || project.id).fontSize(14).fontWeight(FontWeight.Medium).lineHeight(21).fontColor(AppTheme.text).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Text(project.capability === 'control' ? '可执行' : '只读').fontSize(11).fontColor(project.capability === 'control' ? AppTheme.text : AppTheme.secondary).height(26).padding({ left: 10, right: 10 }).backgroundColor(project.capability === 'control' ? AppTheme.chip : AppTheme.subtle).borderRadius(10)
              }.id('settings-project-' + project.id).padding(12).width('100%').constraintSize({ minHeight: 58 }).backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.subtle }).borderRadius(12)
            }, (project: ProjectItem) => project.id)
          }.width('100%')
        } else { Text(this.info).fontSize(14).lineHeight(24).fontColor(AppTheme.text).width('100%').copyOption(CopyOptions.LocalDevice) }
      }.id('settings-info-content').width('100%').constraintSize({ maxHeight: 360 }).align(Alignment.TopStart).scrollBar(BarState.Auto)
      Button('完成').id('settings-info-close').height(44).width('100%').fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).borderRadius(14).onClick(() => { this.info = ''; })
    }.id('settings-info-sheet').padding({ left: 20, right: 20, top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 6 }) {
          Text('连接').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12, bottom: 6 })
          Column() {
            this.InfoRow($r('sys.symbol.link'), 'Mac', this.client.authenticated ? '已连接' : '未连接', () => { this.onNavigate('connect'); })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            this.InfoRow($r('sys.symbol.info_circle'), '连接信息', '', () => { this.info = this.client.fingerprint ? 'Mac 身份指纹\n' + this.client.fingerprint + '\n端到端加密连接，密钥证明后鉴权。' : '连接 Mac 后可查看设备身份。'; })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            this.InfoRow($r('sys.symbol.folder'), '项目访问权限', this.client.projects.length + ' 个项目', () => { this.info = this.client.projects.length ? this.client.projects.length + ' 个已授权项目' : '暂无授权项目'; })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row() { Text('新项目权限').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Text(this.client.newProjectCapability === 'control' ? '自动可执行' : this.client.newProjectCapability === 'read' ? '自动只读' : '逐项授权').id('new-project-policy').fontSize(12).fontColor(AppTheme.secondary) }.padding({ left: 16, right: 16 }).height(54).width('100%')
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row({ space: 12 }) { Column({ space: 4 }) { Text('CLI 下一步建议').fontSize(14).fontColor(AppTheme.text); Text('每回合最多额外采样一次，使用 CLI 额度').fontSize(11).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start); Toggle({ type: ToggleType.Switch, isOn: this.client.nextSuggestionEnabled }).id('suggestions-enabled').onChange((value: boolean) => { this.client.saveSuggestionSetting(value).catch(() => { this.info = '建议设置保存失败'; }); }) }.padding({ left: 16, right: 16 }).height(64).width('100%')
          }.width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(18)
        }.width('100%')
        Column({ space: 6 }) {
          Text('显示').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12, bottom: 6 })
          Column() {
            Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.moon')).fontSize(20).fontColor([AppTheme.secondary]); Text('外观').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Row({ space: 4 }) {
              Button('深色').id('appearance-dark').height(44).width(64).fontSize(13).fontColor(this.client.appearance === 'dark' ? AppTheme.accent : AppTheme.secondary).backgroundColor(this.client.appearance === 'dark' ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.client.saveDisplaySettings(this.client.reduceTransparency, this.client.reduceMotion, 'dark').catch(() => { this.info = '外观保存失败'; }); })
              Button('亮色').id('appearance-light').height(44).width(64).fontSize(13).fontColor(this.client.appearance === 'light' ? AppTheme.accent : AppTheme.secondary).backgroundColor(this.client.appearance === 'light' ? AppTheme.selected : Color.Transparent).borderRadius(12).onClick(() => { this.client.saveDisplaySettings(this.client.reduceTransparency, this.client.reduceMotion, 'light').catch(() => { this.info = '外观保存失败'; }); })
            } }.padding({ left: 16, right: 16 }).height(54).width('100%')
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row() { Text('材质').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Text(this.client.reduceTransparency ? '减少透明度' : AppTheme.supportsImmersive() ? '原生沉浸光感' : '系统磨砂').id('material-support').fontSize(12).fontColor(AppTheme.secondary) }.padding({ left: 16, right: 16 }).height(54).width('100%')
            Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize(20).fontColor([AppTheme.secondary]); Text('减少透明度').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.client.reduceTransparency }).onChange((value: boolean) => { this.client.saveDisplaySettings(value, this.client.reduceMotion).catch(() => { this.info = '显示设置保存失败'; }); }) }.padding({ left: 16, right: 16 }).height(54).width('100%')
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.hourglass')).fontSize(20).fontColor([AppTheme.secondary]); Text('减少动态效果').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.client.reduceMotion }).onChange((value: boolean) => { this.client.saveDisplaySettings(this.client.reduceTransparency, value).catch(() => { this.info = '显示设置保存失败'; }); }) }.padding({ left: 16, right: 16 }).height(54).width('100%')
          }.width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(18)
        }.width('100%')
        Column({ space: 6 }) {
          Text('关于').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12, bottom: 6 })
          Column() { this.InfoRow($r('sys.symbol.lock'), '设备与隐私', '', () => { this.info = '设备签名使用 HUKS；配对身份由 Mac 固定公钥验证。草稿仅保存在本机；秘密回答不写入草稿。'; }); this.InfoRow($r('sys.symbol.doc_text'), '版本信息', '开发构建', () => { this.info = '远码 · HarmonyOS 原生客户端'; }) }.width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(18)
        }.width('100%')
        Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.power')).fontSize(20).fontColor([AppTheme.error]); Text('断开连接').fontSize(14).fontColor(AppTheme.error).layoutWeight(1) }.padding(16).width('100%') }.type(ButtonType.Normal).height(54).width('100%').backgroundColor(AppTheme.subtle).borderRadius(18).onClick(() => { this.client.pauseConnection(); this.onNavigate('connect'); })
      }.padding({ top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
      .bindSheet(this.info.length > 0, this.Details, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: AppTheme.fallbackColor(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), blurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onDisappear: () => { this.info = ''; this.infoTitle = ''; } })
  }
}
