import { pasteboard } from '@kit.BasicServicesKit';
import { AppTheme } from '../theme/AppTheme';
import { GATEWAY_UPDATE_COMMAND, MIN_GATEWAY_VERSION } from '../model/GatewayCompatibility';

@Component
export struct GatewayGuide {
  private copy(command: string): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, command))
      .then(() => { this.getUIContext().getPromptAction().showToast({ message: '命令已复制' }); })
      .catch(() => { this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' }); });
  }
  @Builder
  private Command(title: string, command: string, hint: string) {
    Column({ space: 10 }) {
      Row() {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).layoutWeight(1)
        Button('复制命令').height(44).fontSize(12).fontColor(AppTheme.accent).backgroundColor(Color.Transparent).accessibilityText('复制' + title + '命令').onClick(() => { this.copy(command); })
      }.width('100%')
      Text(command).fontFamily('monospace').fontSize(13).lineHeight(22).fontColor(AppTheme.text).copyOption(CopyOptions.LocalDevice).width('100%').padding(12).backgroundColor(AppTheme.codeSurface).borderRadius(12)
      Text(hint).fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
    }.padding(16).width('100%').backgroundColor(AppTheme.subtle).borderRadius(16)
  }
  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('在 Mac 终端依次执行').fontSize(20).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%')
        Text('需要 macOS、Node.js 22，以及已登录的桌面智能体。手机与 Mac 连接同一局域网；最低网关版本 ' + MIN_GATEWAY_VERSION + '。').fontSize(13).lineHeight(22).fontColor(AppTheme.secondary).width('100%')
        this.Command('1. 安装网关', GATEWAY_UPDATE_COMMAND, '已有网关也可执行这条命令升级。使用当前 Mac 用户安装和运行，不使用 sudo。')
        this.Command('2. 首次初始化', 'yuanma-gateway init', '按终端提示选择项目和连接方式。中继地址留空即可使用局域网；多个网卡时选择手机可访问的 IP。已有配置会保留。')
        this.Command('3. 显示配对码', 'yuanma-gateway pair', '会自动启动网关。用本 App 的“扫码连接 Mac”扫描终端二维码，再按终端提示完成配对。')
        Text('Codex 需先准备与桌面共用的 app-server 入口，默认路径为 ~/.local/share/yuanma/shared/app-server.sock；初始化提示入口不存在时，确认桌面服务已启动，并用 --codex-socket 指定实际共享 socket 路径。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        Text('跨网络使用时，需要自行部署可访问的 Relay，并在初始化时填写实际 wss:// 中继地址。').fontSize(12).lineHeight(20).fontColor(AppTheme.secondary).width('100%')
        this.Command('更新后重启', 'yuanma-gateway restart', '已有安装升级后执行。需要重新生成连接二维码时，再执行 yuanma-gateway pair。')
      }.padding({ top: 12, bottom: 24 }).width('100%').alignItems(HorizontalAlign.Start)
    }.id('gateway-guide-content').width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Auto)
  }
}
