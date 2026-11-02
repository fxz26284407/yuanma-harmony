# 远码 · 鸿蒙客户端（yuanma-harmony）

远码是独立开发的 HarmonyOS 原生 Codex 移动工作端：连接你的 Mac，继续原会话、查看执行过程与代码差异、处理审批和选项，并在断线后恢复工作。

## 项目系列

[远码 Yuanma · GitHub Project](https://github.com/users/fxz26284407/projects/2)

- [鸿蒙原生客户端](https://github.com/fxz26284407/yuanma-harmony)（本仓库）
- [Mac 网关与公网密文中继](https://github.com/fxz26284407/yuanma-gateway)

## 部署架构

![远码部署架构](docs/assets/deployment.svg)

手机和 Mac 主动连接同一个公网 WS 入口；业务内容通过 Noise 在两端加密，中继只负责转发。Codex Desktop 与 Mac 网关连接同一个 app-server，任务、文件操作和审批发生在 Mac。SQLite 消息账本与设备授权也保存在 Mac。

公网服务器只安装 Docker 中继，默认端口映射为 `19088:8080`。有域名时可增加支持 WebSocket Upgrade 的 Nginx；直接使用 `ws://服务器地址:19088` 时省略 Nginx。

[架构图源文件](docs/deployment.archify.json)

## 功能

- 原生玻璃风格菜单和面板，深色、亮色外观及紧凑排版。
- 同步分区、项目和会话；启动后可直接选择最近会话。
- 在手机新建 Mac 项目，设置默认创建路径，并按 Mac 端策略自动取得项目执行权限。
- 消息排队、引导、审批、原生选项、图片、文件差异和执行状态。
- 模型、推理强度、高速模式、会话权限与扩展引用。
- 从 Mac 二维码读取中继地址，保存配对身份，支持换网和重新连接。
- CLI 下一步建议预览；采用后成为可编辑草稿，不自动发送。

## 构建

在 macOS 安装 DevEco Studio，并安装本工程要求的 HarmonyOS SDK 26.0.0、Native SDK/CMake 及 Node.js 22。当前脚本使用 `/Applications/DevEco-Studio.app`；如安装位置不同，调整 `scripts/build-harmony.mjs` 的 IDE 路径。

```sh
nvm use 22
npm ci
cp harmony/build-profile.example.json5 harmony/build-profile.json5
npm run prepare:crypto
```

进入 `harmony/`，使用 DevEco Studio 的同步功能或其 OHPM 工具安装依赖：

```sh
cd harmony
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
cd ..
npm run build:harmony
```

构建脚本会将 LICENSE、NOTICE 和上游许可副本放入 HAP 原始资源中，分发构建产物时仍保留原作者及依赖声明。

示例构建配置不含签名。安装到真机前，在 DevEco Studio 中使用你自己的开发者账号和设备配置调试签名；必要时修改 `harmony/AppScope/app.json5` 中的 bundleName。作者的证书、私钥、设备 profile、密码和签名 HAP 均不在仓库中。

Noise-C 会按固定提交下载到 `.local/noise-c`，由 NAPI 模块链接；保留该源码的上游许可，不修改固定版本。

## 连接你的 Mac

先按 [网关仓库说明](https://github.com/fxz26284407/yuanma-gateway#readme) 启动本地网关和公网中继，再生成二维码：

```sh
npm run pairing:qr -- --relay-url ws://your-relay.example.com
```

这里独立的 `--` 是 npm 的参数分隔符，用于把后面的 `--relay-url` 传给脚本，并非重复。若直接运行脚本，写成 `node scripts/pairing-qr.mjs --relay-url ws://relay.example.com`，不加中间的分隔符。

以上命令在网关仓库执行。手机扫码后按 Mac 上的授权流程连接。中继域名和端口不写死在手机源码中，地址更新可在“设置 → 连接 → Mac”重新扫码；同一 Mac 沿用原设备身份及项目授权。

客户端与 Mac 使用固定公钥 Noise 加密通道及 HUKS 签名登录。中继只转发密文，HTTP/WS 接入仍保留应用层加密和设备权限边界。

## 新建项目、默认路径与自动授权

### 1. 确认 Mac 已开启自动授权

先更新客户端和 [Mac 网关](https://github.com/fxz26284407/yuanma-gateway)，完成配对并连接。在手机“设置 → 连接 → 新项目权限”查看当前策略：显示“自动可执行”才可以从手机新建项目；“自动只读”或“逐项授权”均不支持创建。

策略由 Mac 管理。如果需要开启，在 **网关仓库目录**执行：

```sh
node dist/cli.js devices --state-dir .local/gateway
node dist/cli.js device-project-policy \
  --state-dir .local/gateway \
  --device-id '替换为上一条输出中该手机的 id' \
  --capability control
```

设备 ID 使用已配对手机的 `id`，`--state-dir` 使用正在运行的网关状态目录。策略变更后手机会重新鉴权，必要时点击重新连接已配对的 Mac。更多策略说明见 [网关的新建项目与自动授权说明](https://github.com/fxz26284407/yuanma-gateway#移动端新建项目与自动授权)。

### 2. 设置默认创建路径

打开“设置 → 连接 → 默认项目创建路径”，输入 **Mac 上的父目录**，点击“保存路径”，设置页会立即显示保存后的值。

- 默认值为 `~/workspace`；可填写 `/` 开头的绝对路径或 `~/` 路径，例如 `~/Projects`。
- `~` 指运行网关的 Mac 用户主目录，填写的是 Mac 路径。
- 此设置保存在手机上，按连接的 Mac 分别保存，重启后保留；修改它不移动已有项目。
- 不存在的目录会由网关创建；运行网关的 Mac 用户须有对应目录的写入权限。

### 3. 创建并开始对话

打开侧栏，在“项目”标题右侧点击“新建项目”。确认面板中显示的父目录，输入项目名，再点击“创建并授权”。项目名最长 80 个字符，不能含 `/`、`\`、控制字符，也不能是 `.` 或 `..`。

例如，父目录是 `~/Projects`、项目名为 `my-app`，网关就在 Mac 上创建 `~/Projects/my-app` 并登记 Codex 项目。创建成功后，手机自动取得该项目执行权限并进入新对话，无需再单独批准此项目。

自动授权沿用 Mac 为此设备设置的新项目策略，也适用于网关后续发现的、符合策略范围的其他项目；手动撤掉的项目不会自动加回。项目授权保存在 Mac 网关状态目录，重启网关后保留。项目执行权限与会话审批模式分别管理，新对话仍默认“要求批准”。

若提示先设为“自动可执行”，按第 1 步调整 Mac 策略并重连；目录错误需检查 Mac 路径与写入权限；网关不支持创建时，先更新并重启 Mac 网关。

## 目录

| 目录 | 内容 |
| --- | --- |
| `harmony/entry/src/main/ets/` | ArkUI 界面、会话状态、网络与 HUKS |
| `harmony/entry/src/main/cpp/` | Noise/P-256 NAPI 桥接 |
| `harmony/AppScope/` | 远码名称、图标与应用信息 |
| `interop/` | 固定 Noise-C 的 CMake 构建 |
| `scripts/` | 原生构建及固定依赖准备 |

不提交 `.local/`、设备信息、签名配置、构建产物、真实连接材料或个人文档；不包含项目自有测试用例及临时验收脚本。

## 作者与开源许可

原作者：[@fxz26284407](https://github.com/fxz26284407)。

**创作不易。二次开发或分发时，请保留原作者署名和原项目链接，并按许可证保留 LICENSE 与 NOTICE。** 也欢迎在你的 README、关于页面或分发说明中介绍项目来源。

本项目原创代码采用 [Apache-2.0](LICENSE)。上述署名倡议不增加 Apache-2.0 之外的授权限制。第三方依赖、原生组件和字体的许可见 [NOTICE](NOTICE) 及 `licenses/`，各自声明继续有效。
