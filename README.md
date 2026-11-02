# 远码 · 鸿蒙客户端（yuanma-harmony）

远码是独立开发的 HarmonyOS 原生 Codex 移动工作端：连接你的 Mac，继续原会话、查看执行过程与代码差异、处理审批和选项，并在断线后恢复工作。

## 项目系列

[远码 Yuanma · GitHub Project](https://github.com/users/fxz26284407/projects/2)

- [鸿蒙原生客户端](https://github.com/fxz26284407/yuanma-harmony)（本仓库）
- [Mac 网关与公网密文中继](https://github.com/fxz26284407/yuanma-gateway)

## 功能

- 原生玻璃风格菜单和面板，深色、亮色外观及紧凑排版。
- 同步分区、项目和会话；启动后可直接选择最近会话。
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

以上命令在网关仓库执行。手机扫码后按 Mac 上的授权流程连接。中继域名和端口不写死在手机源码中，地址更新可在“设置 → 连接 → Mac”重新扫码；同一 Mac 沿用原设备身份及项目授权。

客户端与 Mac 使用固定公钥 Noise 加密通道及 HUKS 签名登录。中继只转发密文，HTTP/WS 接入仍保留应用层加密和设备权限边界。

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
