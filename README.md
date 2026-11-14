# 远码 · 鸿蒙客户端

支持手机与电脑局域网直连，也支持通过自建中继跨网络连接。电脑需要 macOS 或 Windows 11 x64、Node.js 22 或 26，以及已登录的桌面智能体；使用 Codex 时，网关须连接与 Codex 桌面共用的后端。

## 局域网连接

手机和电脑连接同一局域网。

![局域网直连网关架构图](docs/assets/yuanma-lan.svg)

手机通过电脑内网地址直接连接网关，指令与结果双向传输；任务和文件操作仍在电脑上完成。

在电脑终端安装并启动：

```sh
npm install -g @fxz26284407/yuanma-gateway@latest --registry=https://registry.npmmirror.com
yuanma-gateway init
yuanma-gateway pair
```

首次初始化时，中继地址留空。选择手机可达的局域网 IP，再用 App 扫描终端二维码即可连接。`pair` 会自动启动网关。当前 App 最低要求 Gateway **0.1.9**。

安装命令仅本次使用 npmmirror 镜像，不修改全局 npm 配置。镜像同步可能有延迟；找不到所需版本时，可将镜像地址改为 https://registry.npmjs.org。

## 网关升级

已有网关升级：

```sh
npm install -g @fxz26284407/yuanma-gateway@latest --registry=https://registry.npmmirror.com
yuanma-gateway restart
```

App 内“网关搭建说明”也提供安装和升级命令，可逐条复制。

## 跨网络连接：安装和使用中继

电脑和手机不在同一局域网时，可让两端主动连接同一个公网中继。电脑仍需开机、联网，并保持桌面智能体与网关运行；中继只转发两端加密后的业务数据，任务仍在电脑执行。

![公网中继连接架构图](docs/assets/yuanma-relay.svg)

图示为 WSS 公网入口方案：手机与电脑网关主动连接同一入口，Noise 加密贯穿手机与电脑两端，指令与结果双向传输。直接使用公网 WS 端口的方式见下文。

### 1. 安装中继

准备已安装 Docker 的服务器，或安装了 Docker Desktop 的电脑。服务器需要可达的公网入口；本机部署可配合花生壳等支持 WebSocket 的穿透服务。

直接使用 [Docker Hub 镜像](https://hub.docker.com/r/fxz26284407/yuanma-relay)，无需在中继宿主机安装 Node.js、桌面智能体或 npm 网关。固定标签 `2026.11.03` 支持 Linux amd64 / arm64，Docker 自动选择架构。以下命令在中继宿主机的 Bash / sh 终端执行：

```sh
docker pull fxz26284407/yuanma-relay:2026.11.03

docker run -d --name yuanma-relay \
  --restart unless-stopped --init \
  -p 19088:8080 \
  --read-only --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop ALL --security-opt no-new-privileges:true \
  --memory 128m --cpus 0.5 --pids-limit 64 \
  --log-opt max-size=5m --log-opt max-file=3 \
  fxz26284407/yuanma-relay:2026.11.03
```

端口映射为“宿主机 `19088` → 容器 `8080`”。端口冲突时修改左侧端口，并同步修改公网入口的回源配置。无需挂载电脑工作目录、数据库、网关配置或密钥。

检查服务：

```sh
docker ps --filter name=yuanma-relay
docker logs --tail 50 yuanma-relay
curl --max-time 5 -fsS http://127.0.0.1:19088/health
```

健康接口应返回 `{"ok":true}`。查看日志时如尚无连接，日志不会持续输出，这是正常现象。

### 2. 配置公网地址

选择一种入口：

| 方式 | 配置 | 连接地址示例 |
| --- | --- | --- |
| 公网服务器端口直连 | 放行服务器防火墙与云安全组的 TCP `19088` 端口 | `ws://服务器公网IP:19088` |
| 域名与外部反向代理 | 由 Nginx 等反代处理 TLS，启用 WebSocket 升级，回源 `http://中继宿主机:19088` | `wss://relay.example.com` |
| 本机 Docker 与花生壳 | 建立支持 WebSocket 的 HTTPS 映射，回源到中继宿主机 HTTP `19088` 端口 | `wss://花生壳实际域名` |

公网域名推荐使用 `wss://` 与有效证书。中继容器内部只提供 HTTP/WS，不包含 Nginx，也不配置域名证书；TLS 由外层反代或穿透服务处理。非默认公网端口需写入连接地址。

花生壳直接运行在中继宿主机上时，回源主机可填 `127.0.0.1`；运行在另一个容器时，应填该容器可达的宿主机地址，不能将它自己的 `127.0.0.1` 当成中继宿主机。Docker Desktop 环境可按实际网络配置使用 `host.docker.internal`。

使用 HTTPS 公网入口时，先检查：

```sh
curl --max-time 10 -fsS https://relay.example.com/health
```

将域名替换成实际地址，应返回 `{"ok":true}`。HTTP 健康检查通过后，还须确认入口支持 WebSocket 升级；仅返回 HTTP 200 不能证明手机可连接。

### 3. 电脑网关连接中继并配对手机

先按上文安装 npm 网关。首次使用时，在运行桌面智能体的电脑终端执行：

```sh
yuanma-gateway init --relay-url wss://relay.example.com
yuanma-gateway pair --relay-url wss://relay.example.com
```

已有局域网安装的用户直接执行第二条 `pair` 命令即可，不需重新初始化身份。命令会启动或切换原网关、保存中继地址，并生成配对二维码。网关参数使用 `ws://` 或 `wss://`，不要填 `http://` 或 `https://`。

在 App 连接页扫描终端二维码；已配对同一电脑时，使用“扫码更新连接地址”沿用原配对。二维码含短时凭据，不公开分享。手机与电脑必须连接同一套中继。

后续启动、查看状态或重启：

```sh
yuanma-gateway start
yuanma-gateway status
yuanma-gateway restart
```

`start` / `restart` 沿用已保存的连接方式。需要重新生成中继二维码时，仍应显式执行 `pair --relay-url 地址`，因为不带参数的 `pair` 默认选择局域网。

回到局域网直连时，将手机和电脑接入同一局域网，执行以下命令并重新扫码：

```sh
yuanma-gateway pair
```

局域网与中继模式不会自动互相回退。本机中继、Docker Desktop、穿透服务或工作电脑休眠、退出后，连接会中断。

### 4. 中继日常管理与排障

```sh
docker restart yuanma-relay
docker stop yuanma-relay
docker start yuanma-relay
```

| 现象 | 检查项 |
| --- | --- |
| 宿主机 `/health` 不通 | 容器是否运行、宿主机端口是否冲突、端口映射是否正确 |
| 宿主机正常，公网地址不通 | 防火墙、安全组、反代或穿透回源地址与端口 |
| HTTPS 正常，手机仍连不上 | WebSocket 升级、证书、公网端口，以及电脑网关是否在线 |
| 扫码后仍使用旧地址 | 二维码是否过期、是否完成新地址登录并保存 |
| 切换地址后立即断开 | 手机与电脑是否连接同一个中继，网关 `status` 中地址是否正确 |

更多部署与配置细节见 [网关仓库中继部署说明](https://github.com/fxz26284407/yuanma-gateway#中继部署直接拉取-docker-hub-镜像)。

[用户协议](https://fxz26284407.github.io/yuanma-harmony/user-agreement.html) · [Apache-2.0](LICENSE) · [第三方声明](NOTICE) · 作者 [@fxz26284407](https://github.com/fxz26284407)
