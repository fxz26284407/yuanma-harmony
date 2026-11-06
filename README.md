# 远码 · 鸿蒙客户端

手机和 Mac 连接同一局域网。Mac 需要 Node.js 22，以及已登录、与 Codex 桌面共用的 Codex 后端。

在 Mac 终端安装并启动：

```sh
npm install -g @fxz26284407/yuanma-gateway@latest --registry=https://registry.npmmirror.com
yuanma-gateway init
yuanma-gateway pair
```

首次初始化时，中继地址留空。选择手机可达的局域网 IP，再用 App 扫描终端二维码即可连接。`pair` 会自动启动网关。当前 App 最低要求 Gateway **0.1.7**。

安装命令仅本次使用 npmmirror 镜像，不修改全局 npm 配置。镜像同步可能有延迟；找不到所需版本时，可将镜像地址改为 https://registry.npmjs.org。

已有网关升级：

```sh
npm install -g @fxz26284407/yuanma-gateway@latest --registry=https://registry.npmmirror.com
yuanma-gateway restart
```

App 内“网关搭建说明”也提供安装和升级命令，可逐条复制。

[用户协议](https://fxz26284407.github.io/yuanma-harmony/user-agreement.html) · [Apache-2.0](LICENSE) · [第三方声明](NOTICE) · 作者 [@fxz26284407](https://github.com/fxz26284407)
