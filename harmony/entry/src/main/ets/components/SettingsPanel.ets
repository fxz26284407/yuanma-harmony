import { SheetHeader } from './SheetHeader';
import { UiState, ProjectItem } from '../model/UiState';
import { AppTheme } from '../theme/AppTheme';
interface SettingsInfoRow {
  icon: Resource;
  title: string;
  value: string;
  action: () => void;
}
@Component
export struct SettingsPanel {
  @ObjectLink client: UiState;
  onNavigate: (page: string) => void = () => {};
  @State private info: string = '';
  @State private projectPath: string = '';
  @State private pathError: string = '';
  @State private savingPath: boolean = false;
  private async savePath(): Promise<void> {
    this.savingPath = true; this.pathError = '';
    try { await this.client.saveProjectCreationPath(this.projectPath); this.info = ''; } catch (error) { this.pathError = (error as Error).message; } finally { this.savingPath = false; }
  }
  @State private infoTitle: string = '';
  @Builder
  private InfoRow($$: SettingsInfoRow) {
    Button() { Row({ space: 12 }) { SymbolGlyph($$.icon).fontSize(20).fontColor([AppTheme.secondary]); Text($$.title).fontSize(14).fontColor(AppTheme.text).layoutWeight(1); if ($$.value) { Text($$.value).fontSize(12).fontColor(AppTheme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '45%' }) } SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppTheme.muted]) }.padding({ left: 16, right: 16 }).height(54).width('100%') }
      .type(ButtonType.Normal).width('100%').height(54).backgroundColor(Color.Transparent).onClick(() => { this.infoTitle = $$.title; $$.action(); })
  }
  @Builder
  private Details() {
    Column({ space: 16 }) {
      SheetHeader({ title: this.infoTitle || '提示', onClose: () => { this.info = ''; } })
      Scroll() {
        if (this.infoTitle === '默认项目创建路径') {
          Column({ space: 12 }) {
            Text('填写 Mac 上的父目录，新项目将创建在此目录下。支持绝对路径和 ~/，按所连接的 Mac 分别保存。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
            TextInput({ text: this.projectPath, placeholder: '~/workspace' }).id('project-creation-path-input').height(48).fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).maxLength(4096).onChange((value: string) => { this.projectPath = value; })
            if (this.pathError) { Text(this.pathError).fontSize(12).fontColor(AppTheme.error).width('100%') }
          }.width('100%')
        } else if (this.infoTitle === this.client.containerName + '访问权限' && this.client.projects.length > 0) {
          Column({ space: 8 }) {
            ForEach(this.client.projects, (project: ProjectItem) => {
              Row({ space: 12 }) {
                Stack() { SymbolGlyph($r('sys.symbol.folder')).fontSize(18).fontColor([AppTheme.secondary]) }.width(32).height(32).backgroundColor(AppTheme.subtle).borderRadius(9)
                Text(project.name || project.id).fontSize(14).fontWeight(FontWeight.Medium).lineHeight(21).fontColor(AppTheme.text).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Text(project.capability === 'control' ? '可执行' : '只读').fontSize(11).fontColor(project.capability === 'control' ? AppTheme.text : AppTheme.secondary).height(26).padding({ left: 10, right: 10 }).backgroundColor(project.capability === 'control' ? AppTheme.chip : AppTheme.subtle).borderRadius(10)
              }.id('settings-project-' + project.id).padding(12).width('100%').constraintSize({ minHeight: 58 }).backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.subtle }).borderRadius(12)
            }, (project: ProjectItem) => JSON.stringify([project.id, project.name, project.capability]))
          }.width('100%')
        } else { Text(this.info).fontSize(14).lineHeight(24).fontColor(AppTheme.text).width('100%').copyOption(CopyOptions.LocalDevice) }
      }.id('settings-info-content').width('100%').constraintSize({ maxHeight: 360 }).align(Alignment.TopStart).scrollBar(BarState.Auto)
      Button(this.infoTitle === '默认项目创建路径' ? '保存路径' : '完成').id('settings-info-close').height(44).width('100%').fontSize(14).fontColor(AppTheme.text).backgroundColor(AppTheme.subtle).borderRadius(14).enabled(!this.savingPath).onClick(() => { if (this.infoTitle === '默认项目创建路径') { this.savePath(); } else { this.info = ''; } })
    }.id('settings-info-sheet').padding({ left: 20, right: 20, top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 6 }) {
          Text('连接').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12, bottom: 6 })
          Column() {
            this.InfoRow({ icon: $r('sys.symbol.link'), title: 'Mac', value: this.client.authenticated ? '已连接' : '未连接', action: () => { this.onNavigate('connect'); } })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            this.InfoRow({ icon: $r('sys.symbol.info_circle'), title: '连接信息', value: '', action: () => { this.info = this.client.fingerprint ? 'Mac 身份指纹\n' + this.client.fingerprint + '\n端到端加密连接，密钥证明后鉴权。' : '连接 Mac 后可查看设备身份。'; } })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            this.InfoRow({ icon: $r('sys.symbol.folder'), title: this.client.containerName + '访问权限', value: this.client.projects.length + ' 个' + this.client.containerName, action: () => { this.info = this.client.projects.length ? this.client.projects.length + ' 个已授权' + this.client.containerName : '暂无授权' + this.client.containerName; } })
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            if (this.client.selectedAgent === 'codex') {
            this.InfoRow({ icon: $r('sys.symbol.folder'), title: '默认项目创建路径', value: this.client.projectCreationPath, action: () => { this.projectPath = this.client.projectCreationPath; this.pathError = ''; this.info = 'path'; } })
            }
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row() { Text('新' + this.client.containerName + '权限').fontSize(14).fontColor(AppTheme.text).layoutWeight(1); Text(this.client.newProjectCapability === 'control' ? '自动可执行' : this.client.newProjectCapability === 'read' ? '自动只读' : '逐项授权').id('new-project-policy').fontSize(12).fontColor(AppTheme.secondary) }.padding({ left: 16, right: 16 }).height(54).width('100%')
            Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 })
            Row({ space: 12 }) { Column({ space: 4 }) { Text('CLI 下一步建议').fontSize(14).fontColor(AppTheme.text); Text('每回合最多额外采样一次，使用 CLI 额度').fontSize(11).fontColor(AppTheme.secondary) }.layoutWeight(1).alignItems(HorizontalAlign.Start); Toggle({ type: ToggleType.Switch, isOn: this.client.nextSuggestionEnabled }).id('suggestions-enabled').onChange((value: boolean) => { this.client.saveSuggestionSetting(value).catch(() => { this.info = '建议设置保存失败'; }); }) }.padding({ left: 16, right: 16 }).height(64).width('100%')
          }.width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(18)
        }.width('100%')
        Column({ space: 6 }) {
          Text('Skills 与插件').fontSize(12).fontColor(AppTheme.secondary).width('100%').padding({ left: 12, bottom: 6 })
          Column() {
            Button() { Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize(20).fontColor([AppTheme.secondary])
              Text(this.client.extensionSyncing ? '正在同步…' : '同步 Skills 与插件').fontSize(14).fontColor(AppTheme.text).layoutWeight(1)
              if (this.client.extensionSyncing) { LoadingProgress().width(18).height(18).color(AppTheme.accent) } else { Text('同步').fontSize(12).fontColor(AppTheme.accent) }
            }.padding({ left: 16, right: 16 }).height(54).width('100%') }.id('sync-extensions').type(ButtonType.Normal).padding(0).height(54).width('100%').backgroundColor(Color.Transparent).enabled(this.client.capabilities.extensions && this.client.authenticated && !this.client.busy && !this.client.extensionSyncing && this.client.projects.length > 0)
              .onClick(() => { this.client.syncExtensions().catch((error: Error) => { this.infoTitle = '同步 Skills 与插件'; this.info = this.client.userFacingError(error) || '连接正在恢复，请恢复连接后重新同步'; }); })
            Text(this.client.extensionSyncStatus || (this.client.authenticated ? (this.client.projects.length > 0 ? '读取当前智能体已启用的扩展，供输入框 @ 使用。Skill 随' + this.client.containerName + '和会话切换。' : '请先在 Mac 授权一个' + this.client.containerName + '，再同步扩展清单。') : '连接 Mac 后可同步当前电脑的扩展清单。')).id('extension-sync-status').fontSize(11).lineHeight(18).fontColor(AppTheme.secondary).width('100%').padding({ left: 16, right: 16, bottom: 12 })
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
          Column() { Hyperlink('https://github.com/fxz26284407/yuanma-gateway#readme', '使用说明 · 网关搭建（GitHub）').id('gateway-guide-settings').color(this.client.appearance === 'light' ? '#287889' : '#86CDDD').height(54).width('100%').padding({ left: 16, right: 16 }).accessibilityText('在系统浏览器打开 GitHub 网关搭建与使用说明'); Divider().color(AppTheme.subtle).margin({ left: 16, right: 16 }); this.InfoRow({ icon: $r('sys.symbol.lock'), title: '设备与隐私', value: '', action: () => { this.info = '设备签名使用 HUKS；配对身份由 Mac 固定公钥验证。草稿仅保存在本机；秘密回答不写入草稿。'; } }); this.InfoRow({ icon: $r('sys.symbol.doc_text'), title: '版本信息', value: '开发构建', action: () => { this.info = '远码 · HarmonyOS 原生客户端'; } }) }.width('100%').backgroundColor(AppTheme.subtle).border({ width: 0.6, color: AppTheme.border }).borderRadius(18)
        }.width('100%')
        Button() { Row({ space: 12 }) { SymbolGlyph($r('sys.symbol.power')).fontSize(20).fontColor([AppTheme.error]); Text('断开连接').fontSize(14).fontColor(AppTheme.error).layoutWeight(1) }.padding(16).width('100%') }.type(ButtonType.Normal).height(54).width('100%').backgroundColor(AppTheme.subtle).borderRadius(18).onClick(() => { this.client.pauseConnection(); this.onNavigate('connect'); })
      }.padding({ top: 20, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
      .bindSheet(this.info.length > 0, this.Details, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: AppTheme.fallbackColor(this.client.reduceTransparency), systemMaterial: AppTheme.material(this.client.reduceTransparency), blurStyle: AppTheme.fallbackBlur(this.client.reduceTransparency), onDisappear: () => { this.info = ''; this.infoTitle = ''; } })
  }
}
