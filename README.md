# 远码 · 鸿蒙客户端

手机和 Mac 连接同一局域网。Mac 需要 Node.js 22，以及已登录、与 Codex 桌面共用的 Codex 后端。

在 Mac 终端安装并启动：

```sh
npm install -g @fxz26284407/yuanma-gateway@0.1.2 --registry=https://registry.npmjs.org
yuanma-gateway init
yuanma-gateway pair
```

首次初始化时，中继地址留空。选择手机可达的局域网 IP，再用 App 扫描终端二维码即可连接。

[用户协议](https://fxz26284407.github.io/yuanma-harmony/user-agreement.html) · [Apache-2.0](LICENSE) · [第三方声明](NOTICE) · 作者 [@fxz26284407](https://github.com/fxz26284407)
