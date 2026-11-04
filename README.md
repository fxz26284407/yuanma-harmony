# 远码 · 鸿蒙客户端（yuanma-harmony）

远码是独立开发的 HarmonyOS 原生 Codex 局域网移动工作端：在同一局域网内连接你的 Mac，继续原会话、查看执行过程与代码差异、处理审批和选项，并在断线后恢复工作。

## 项目系列

[远码 Yuanma · GitHub Project](https://github.com/users/fxz26284407/projects/2)

- [鸿蒙原生客户端](https://github.com/fxz26284407/yuanma-harmony)（本仓库）
- [Mac 网关与局域网密文中继](https://github.com/fxz26284407/yuanma-gateway)

## 部署架构

![远码部署架构](docs/assets/deployment.svg)

手机、Mac 和用户自行部署的中继处于同一局域网，两端连接同一个内网 WS 地址，例如 `ws://192.168.1.10:19088`。业务内容通过 Noise 在手机与 Mac 之间加密，中继只负责转发。Codex Desktop 与 Mac 网关连接同一个 app-server，任务、文件操作和审批发生在 Mac。SQLite 消息账本与设备授权也保存在 Mac。

中继运行在 Mac Docker 或同一局域网主机，宿主机内网端口 `19088` 映射到容器 `8080`。无需公网域名或内网穿透；仅允许可信内网设备访问，不配置路由器公网端口转发。离开该局域网后，此部署方式无法连接 Mac。

局域网限定的是手机与 Mac 的连接范围；Mac 上的 Codex、DeepSeek 及模型服务仍按各自配置联网，构建依赖也需从相应软件源获取，不表示全部功能可离线使用。

[架构图源文件](docs/deployment.archify.json)

## 功能

- 原生玻璃风格菜单和面板，深色、亮色外观及紧凑排版。
- 同步分区、项目和会话；启动后可直接选择最近会话。
- 在手机新建 Mac 项目，设置默认创建路径，并按 Mac 端策略自动取得项目执行权限。
- 消息排队、引导、审批、原生选项、图片、文档上传、文件差异和执行状态。
- 模型、推理强度、高速模式、会话权限与扩展引用。
- 从 Mac 二维码读取中继地址，保存配对身份，支持内网地址更新和重新连接。
- Codex / DeepSeek 通用下一步建议，各用自己的模型和额度；采用后成为可编辑草稿，不自动发送。
- 文件图标入口支持文档单个 50 MiB、每条消息附件合计 100 MiB、最多 4 个；图片合计仍为 8 MiB。
- 输入 `@` 搜索技能与插件，支持“请用@技能”直接触发，不再提供独立 `@` 按钮。

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

## 连接你的 Mac：npm 安装并扫码

已安装远码 App 的用户只需在 Mac 安装网关，无需克隆网关源码或安装 DevEco Studio；上面的构建步骤仅供客户端开发者使用。

### 1. 准备 Mac 与局域网中继

需要 macOS、Node.js 22，以及已登录并与 Codex 桌面共用的 app-server（当前适配版本为 0.166.0）。默认共享入口为 `~/.local/share/yuanma/shared/app-server.sock`；该入口必须指向桌面实际使用的同用户私有 socket。安装 npm 包不会自动创建共享后端。

当前 npm 版本仍需要 Relay；“不填 Relay 地址即可直接连接 Mac”的功能尚未发布。可使用局域网内已有中继，或在装有 Docker 的 Mac / 内网主机启动：

```sh
docker run -d --name yuanma-relay \
  --restart unless-stopped \
  -p 192.168.1.10:19088:8080 \
  fxz26284407/yuanma-relay:2026.11.03
```

将 `192.168.1.10` 替换为中继宿主机实际的局域网 IP；已有中继时不要重复启动。手机、Mac 和中继须处于互通内网，防火墙允许该内网端口，不使用访客隔离网络，也不配置公网端口转发。

### 2. 安装网关

在 Mac 终端执行（使用 nvm 管理 Node.js 时）：

```sh
nvm install 22
nvm use 22
npm install -g @fxz26284407/yuanma-gateway@0.1.0 --registry=https://registry.npmjs.org
yuanma-gateway --version
```

已有 Node.js 22 时可直接安装 npm 包。不要使用 `sudo` 启动网关；应与 Codex 桌面使用同一 Mac 用户。SQLite 原生依赖缺少预编译包时，需要 Xcode Command Line Tools。

### 3. 初始化并生成二维码

```sh
yuanma-gateway init --relay-url ws://192.168.1.10:19088
yuanma-gateway pair
```

初始化时按提示选择项目并确认密钥保存与项目访问策略。若共享 socket 不在默认位置，在 `init` 命令后增加 `--codex-socket /实际路径/app-server.sock`。当前版本配对后所有发现的项目和工作区默认可执行，初始项目列表不是权限白名单；会话执行审批独立管理。

`pair` 会确保网关已启动并在终端显示短时有效二维码。命令可在任意目录执行，无需进入网关源码目录。二维码包含配对凭据，请勿公开分享。

已有源码安装和配对数据的用户，先登记原配置与状态目录，再执行 `pair`，避免创建另一套身份：

```sh
yuanma-gateway init --config /原配置绝对路径/config.json --state-dir /原状态目录绝对路径
yuanma-gateway pair
```

### 4. 手机扫码连接

打开远码 App 的连接页面，扫描终端二维码；已配对用户选择“扫码更新连接地址”。同一 Mac 沿用原设备身份及项目授权，成功登录后保存连接地址。

手机不能使用 `127.0.0.1` 或 `localhost` 代表 Mac。IP 变化后重新生成二维码：

```sh
yuanma-gateway pair --relay-url ws://192.168.1.20:19088
```

将示例地址换成实际中继地址。客户端与 Mac 继续使用固定公钥 Noise 加密通道及设备鉴权，中继只转发密文。

### 日常使用与升级

```sh
yuanma-gateway status
yuanma-gateway start
yuanma-gateway stop
```

升级后重启网关：

```sh
npm install -g @fxz26284407/yuanma-gateway@latest --registry=https://registry.npmjs.org
yuanma-gateway restart
```

配置、密钥、配对和消息账本保存在 npm 安装目录之外，升级时保留。不要删除原状态目录、重新生成身份或卸载手机 App 来完成升级。

## 新建项目、默认路径与自动授权

### 1. 完成网关安装与配对

按上文通过 npm 安装网关并扫码连接。当前 npm 网关的项目策略为：所有发现的项目和工作区默认可执行，新项目自动取得执行权限。项目执行权限与会话审批分别管理，新对话仍默认“要求批准”。

可在 Mac 任意目录查看已配对设备：

```sh
yuanma-gateway devices
```

### 2. 设置默认创建路径

打开“设置 → 连接 → 默认项目创建路径”，输入 **Mac 上的父目录**，点击“保存路径”，设置页会立即显示保存后的值。

- 默认值为 `~/workspace`；可填写 `/` 开头的绝对路径或 `~/` 路径，例如 `~/Projects`。
- `~` 指运行网关的 Mac 用户主目录，填写的是 Mac 路径。
- 此设置保存在手机上，按连接的 Mac 分别保存，重启后保留；修改它不移动已有项目。
- 不存在的目录会由网关创建；运行网关的 Mac 用户须有对应目录的写入权限。

### 3. 创建并开始对话

打开侧栏，在“项目”标题右侧点击“新建项目”。确认面板中显示的父目录，输入项目名，再点击“创建并授权”。项目名最长 80 个字符，不能含 `/`、`\`、控制字符，也不能是 `.` 或 `..`。

例如，父目录是 `~/Projects`、项目名为 `my-app`，网关就在 Mac 上创建 `~/Projects/my-app` 并登记 Codex 项目。创建成功后，手机自动取得该项目执行权限并进入新对话，无需再单独批准此项目。

当前 npm 网关会为发现的项目和工作区提供默认执行权限。项目授权保存在 Mac 网关状态目录，重启网关后保留。项目执行权限与会话审批模式分别管理，新对话仍默认“要求批准”。

若仍提示需要开启“自动可执行”，请核对实际连接的网关版本并按上文升级、重启和重连；目录错误需检查 Mac 路径与写入权限；网关不支持创建时，先更新并重启 Mac 网关。

## 项目菜单与桌面同步

侧栏长按项目可选择“重新命名”或“分区”，分区列表支持“不分区”。只读或未授权项目不能修改。侧栏顶部使用透明背景的远码 Logo。

手机新增项目、改名或调整分区后，手机立即更新，侧栏会显示桌面同步状态。当前版本请按以下顺序同步桌面：**完全退出桌面应用 → 稍等并刷新手机侧栏，确认显示“已同步” → 重新打开桌面应用**。仅关闭桌面窗口不算退出。同步需按上文通过 npm 更新并重启 Mac 网关，待同步变更在网关重启后保留。

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
