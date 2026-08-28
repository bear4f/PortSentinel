# PortSentinel

PortSentinel 是一个面向 Linux 服务器的交互式双栈端口白名单管理工具。它通过标准的 `iptables` 和 `ip6tables` 规则限制指定的本机 TCP/UDP 端口：只有明确加入规则或 IP Group 的 IPv4、IPv6 地址及 CIDR 网络可以访问，其他来源将被丢弃。

PortSentinel 只负责常规防火墙访问控制。它不会隐藏流量、提供匿名能力、绕过网络审查、识别应用层协议，也不会修改 NAT、`FORWARD`、`OUTPUT`、`PREROUTING` 或 `POSTROUTING`。

> PortSentinel restricts access to selected network ports using normal Linux firewall rules. It does not hide traffic from network operators and does not provide anonymity.

## 一键安装

支持 Debian 12/13、Ubuntu 22.04/24.04，兼容 amd64 和 arm64：

```bash
curl -fsSL https://raw.githubusercontent.com/bear4f/PortSentinel/main/install.sh | sudo bash
```

安装程序只会安装程序文件、依赖和 systemd 服务，**不会立即添加 DROP 规则或修改现有防火墙策略**。安装完成后运行：

```bash
sudo portsentinel
```

建议先检查安装脚本再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/bear4f/PortSentinel/main/install.sh -o install-portsentinel.sh
less install-portsentinel.sh
sudo bash install-portsentinel.sh
```

## 主要功能

- 同时生成并应用 IPv4 和 IPv6 策略，防止 IPv6 绕过。
- 支持 `1-65535` 的单端口和端口范围。
- 支持 TCP、UDP 和 TCP+UDP。
- 使用 Python `ipaddress` 严格验证 IPv4、IPv6 和 CIDR。
- 支持可被多个端口复用的 IP Group。
- 仅管理独立的 `PORTSENTINEL` 链，不清空系统防火墙。
- 使用临时链安全切换策略，失败时执行双栈成对回滚。
- 根据 `SSH_CONNECTION`、`SSH_CLIENT` 和 `ss -lntp` 防止 SSH 锁死。
- 支持幂等 Apply、`flock` 并发锁、`iptables -w 5`、Dry Run 和 systemd 持久化。
- 提供 TUI 更新按键和 `portsentinel update` 一键更新命令。
- 兼容 xtables 和 nftables 后端的标准 `iptables` 命令接口。

## 快速开始

```bash
# 打开交互式管理菜单
sudo portsentinel

# 只预览 IPv4/IPv6 规则，不修改防火墙
sudo portsentinel apply --dry-run

# 应用配置
sudo portsentinel apply

# 查看状态
sudo portsentinel status
```

交互式菜单支持：

- 添加、编辑和删除受保护端口。
- 添加 IPv4、IPv6 地址和 CIDR。
- 创建、重命名、删除和复用 IP Group。
- 查看展开后的有效规则和流量计数。
- 创建或恢复双栈防火墙备份。
- 重置 PortSentinel 私有规则。
- 一键更新 PortSentinel。

### 添加端口保护

选择主菜单中的 `[3] 添加端口保护` 后，依次输入规则名称、端口和协议，再选择白名单来源。可以直接填写一个或多个具体 IP/CIDR，也可以绑定已经创建的 IP Group：

```text
> 请输入规则名称：snell
> 请输入端口或范围（例如 10773 或 20000:20100）：10086
> 请选择协议：[1] TCP [2] UDP [3] TCP + UDP
> 3
> 请选择白名单来源：
> [1] 直接输入 IP/CIDR
> [2] 绑定 IP Group
> [3] 暂不添加来源（阻止所有访问）
> 1
> 请输入允许访问的 IP/CIDR（多个用逗号分隔，可混合 IPv4 和 IPv6）：8.212.49.31
> [信息] 已识别 IPv4 1 个、IPv6 0 个来源。
> [信息] 规则已保存。请返回主菜单选择 [6] 应用配置。
```

如果多个端口共用同一批地址，请先在 `[2] IP Group 管理` 中创建 Group，然后在来源类型中选择 `[2] 绑定 IP Group`。无论使用直接 IP 还是 Group，未列入白名单的 IPv4/IPv6 来源默认都会被拒绝。保存规则后还需要选择 `[6] 应用配置` 才会写入防火墙。

交互式面板会在当前步骤校验规则 ID、地址族、IP 和 CIDR。输入为空或格式错误时会提示重新输入，不会退出 PortSentinel；其他菜单操作发生错误时也只会返回当前菜单。

## 系统兼容性与依赖

重点支持：

- Debian 12 / 13
- Ubuntu 22.04 / 24.04
- amd64 / arm64

依赖包括 Bash、`iptables`、`ip6tables`、`ip`、`ss`、`flock`、`jq` 和 Python 3。安装程序会通过 `apt` 安装缺少的软件包，不会强制切换到 `iptables-legacy`。

## 安装内容

安装后会创建：

- `/usr/local/bin/portsentinel`
- `/usr/local/lib/portsentinel/uninstall.sh`
- `/etc/portsentinel/config.json`
- `/etc/portsentinel/portsentinel.conf`
- `/etc/portsentinel/backups/`
- `/etc/systemd/system/portsentinel.service`
- `/var/log/portsentinel.log`（首次记录日志时创建）

使用本地仓库安装：

```bash
sudo PORTSENTINEL_SOURCE_DIR="$PWD" bash install.sh
```

## 配置模型

示例配置位于 [`examples/config.example.json`](examples/config.example.json)。每条规则包含：

- 唯一的规则名称。
- `tcp`、`udp` 或 `both` 协议。
- 单端口（如 `10773`）或范围（如 `20000:20100`）。
- 可复用的 IP Group。
- IPv4 和 IPv6 自定义来源。
- IPv4 和 IPv6 各自独立的默认策略。

支持的地址格式：

```text
IPv4:      192.0.2.10
IPv4 CIDR: 198.51.100.0/24
IPv6:      2001:db8::10
IPv6 CIDR: 2001:db8:1234::/48
```

IPv4 支持 `/0` 到 `/32`，IPv6 支持 `/0` 到 `/128`。IPv4 地址只会进入 `iptables`，IPv6 地址只会进入 `ip6tables`。无效地址、重复名称、缺失 Group、重复来源、无效端口以及协议和端口范围重叠都会在接触防火墙前被拒绝。

一个 IP Group 可以同时保存 IPv4 和 IPv6 来源，并绑定到任意数量的受保护端口。修改 Group 后，所有引用该 Group 的端口会在下次 Apply 时自动继承新地址。

### IPv6 空白名单保护

每个受保护端口都有明确的 `ipv6_default`，交互式创建规则时默认使用 `drop`。因此，即使 TCP/10773 只有 IPv4 白名单而没有 IPv6 来源，仍会生成：

```text
ip6tables ... -A PORTSENTINEL_NEW -p tcp --dport 10773 -j DROP
```

这样可以避免端口在 IPv4 已受保护时仍通过 IPv6 暴露。只有用户主动选择“保持不限制”时，才会为该端口生成明确的 `RETURN`。

## 防火墙架构

PortSentinel 在 IPv4 和 IPv6 的 filter 表中分别维护一个 `PORTSENTINEL` 链，并在各自的 `INPUT` 链中保留一个 jump：

```text
iptables:  INPUT -> PORTSENTINEL
ip6tables: INPUT -> PORTSENTINEL
```

白名单来源使用 `ACCEPT`，受保护端口的其他来源使用 `DROP`，私有链最后使用 `RETURN`，让未被 PortSentinel 管理的端口继续执行服务器原有防火墙规则。

PortSentinel 不会对内置链执行无目标的 `iptables -F`、`iptables -X`、`ip6tables -F` 或 `ip6tables -X`。Docker、Fail2ban、UFW、SSH 和用户自定义规则会被保留。第一版只管理进入本机服务的 `INPUT` 流量。

## 双栈事务 Apply 与回滚

`portsentinel apply` 会在 `/run/portsentinel.lock` 锁内完成：

1. 验证完整 JSON 结构、地址、端口、Group 引用和范围重叠。
2. 生成完整的 IPv4 和 IPv6 候选策略。
3. 在修改任何一侧前检查所需后端。
4. 使用同一个 UTC 时间戳保存 IPv4/IPv6 成对备份。
5. 分别构建完整的 `PORTSENTINEL_NEW` 临时链。
6. 将 `INPUT` jump 切换到新链，删除不再引用的旧私有链。
7. 把临时链重命名为正式的 `PORTSENTINEL`。
8. 任意一侧失败或进程收到 `INT`/`TERM` 时，用 `iptables-restore` 和 `ip6tables-restore` 同时恢复两套备份。

候选链在被引用前已经完整构建，因此重复执行 Apply 不会产生重复 jump 或重复规则。完整防火墙 restore 只用于失败回滚或用户主动恢复备份，正常 Apply 不会重建系统其他规则。

如果系统完全禁用了 IPv6，PortSentinel 仍会保存并验证 IPv6 策略，同时明确显示 `IPv6: Disabled by system`。如果系统已启用 IPv6 但后端缺失或执行失败，预检查或 rollback 会阻止双栈策略处于半应用状态。

## SSH 防锁死

交互式 Apply 前，PortSentinel 会从 `SSH_CONNECTION` 或 `SSH_CLIENT` 获取当前客户端地址和服务器实际端口，并在可用时通过 `ss -lntp` 检查监听状态，不会假定 SSH 使用 22 端口。

如果新规则覆盖当前 SSH 端口，但白名单不包含当前来源，程序会显示严重警告并默认取消。继续执行需要输入完整字符串：

```text
APPLY ANYWAY
```

也可以输入 `PRESERVE CURRENT SSH`，或运行：

```bash
sudo portsentinel apply --preserve-current-ssh
```

这会把当前 SSH 来源临时加入本次生成的候选规则，但不会修改 `config.json`，所以下一次 Apply 前仍应把管理地址正式加入白名单。修改任何远程服务器防火墙前，建议保留独立的救援控制台。

## Dry Run 与规则检查

```bash
sudo portsentinel apply --dry-run
sudo portsentinel effective
sudo portsentinel list
sudo portsentinel group list
```

Dry Run 会验证配置并分别打印 `===== IPv4 =====` 和 `===== IPv6 =====` 候选命令，不需要 root 权限，也不会修改防火墙。`effective` 会展开 Group；以 root 运行且规则已激活时，还会显示 packet/byte 计数。

## 备份与恢复

每次真实 Apply 都会创建一组成对备份：

```text
/etc/portsentinel/backups/20260829-003000.ipv4.rules
/etc/portsentinel/backups/20260829-003000.ipv6.rules
```

默认保留最近 20 组：

```bash
sudo portsentinel backup
sudo portsentinel restore 20260829-003000
```

Restore 前还会创建一组安全备份。如果 IPv4 或 IPv6 恢复失败，程序会尝试重新恢复该安全备份。

## 开机自动恢复

`portsentinel.service` 是一个 `Type=oneshot` 服务，在本地文件系统就绪后、`network-pre.target` 之前运行：

```text
/usr/local/bin/portsentinel apply --non-interactive
```

它不依赖 `iptables-persistent`，也不会等待 `network-online.target`。配置不存在或没有受保护端口时会安全退出；错误可以通过以下命令查看：

```bash
sudo systemctl status portsentinel
sudo journalctl -u portsentinel
```

## 一键更新

在交互式菜单中选择 `[u] 一键更新`，或者运行：

```bash
sudo portsentinel update
```

更新功能会通过 HTTPS 下载最新安装程序，先检查 Bash 语法和 PortSentinel 标记，再运行更新模式。它只替换程序和 service 文件，保留配置与备份，重新加载 systemd 元数据，但不会自动重新 Apply 或重启当前防火墙策略。

也可以直接重新执行一键安装命令完成更新：

```bash
curl -fsSL https://raw.githubusercontent.com/bear4f/PortSentinel/main/install.sh | sudo bash -s -- --update
```

## Reset 与卸载

Reset 只删除 `INPUT -> PORTSENTINEL` jump 和 PortSentinel 私有链，保留程序、配置和备份：

```bash
sudo portsentinel reset
```

卸载会要求二次确认，停止并禁用 service，删除 PortSentinel 私有规则和程序文件，然后询问是否保留 `/etc/portsentinel`。默认保留配置和备份：

```bash
sudo portsentinel uninstall
```

Reset 和卸载都不会清空完整的系统内置链。

## CLI 命令

```text
portsentinel
portsentinel status
portsentinel list
portsentinel rule list
portsentinel group list
portsentinel effective
portsentinel apply [--dry-run] [--non-interactive] [--preserve-current-ssh]
portsentinel backup
portsentinel restore [TIMESTAMP]
portsentinel reset [--non-interactive]
portsentinel update
portsentinel uninstall
portsentinel version
```

## 测试

默认测试使用临时配置、Dry Run 和模拟防火墙后端，不会修改宿主机 `INPUT`：

```bash
bash tests/run-tests.sh
```

CI 会执行 Bash 语法检查、ShellCheck、严格地址/端口/配置测试、Group 展开、TCP/UDP/TCP+UDP 生成、重复规则防护、IPv6 空白名单回归测试、幂等 Apply 和双栈 rollback 测试。

在 Linux root 环境中可以显式运行真实 network namespace 测试：

```bash
sudo PORTSENTINEL_RUN_NETNS=1 bash tests/test-netns.sh
```

## 安全模型与限制

PortSentinel 是本机 `INPUT` 访问控制工具，不是完整的系统防火墙管理器。位于 PortSentinel jump 前方的其他 ACCEPT 规则、其他组件后续添加的规则，或不经过本机 `INPUT` 的流量都可能改变最终结果。部署后请检查：

```bash
sudo iptables -S INPUT
sudo ip6tables -S INPUT
```

配置目录由 root 所有，目录权限为 `0700`，JSON 和备份权限为 `0600`。所有地址和端口在作为命令参数前都会经过严格验证，日志只保存操作结果，不记录密码、私钥、Token 或其他凭证。

## License

MIT
