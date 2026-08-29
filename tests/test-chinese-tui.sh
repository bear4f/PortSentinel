#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-tui.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/etc"
cp "$(dirname "$0")/../examples/config.example.json" "$root/etc/config.json"

run_tui() {
    TERM=dumb PORTSENTINEL_CONFIG_DIR="$root/etc" PORTSENTINEL_LOG_FILE="$root/log" \
      PORTSENTINEL_IP=true bash "$(dirname "$0")/../bin/portsentinel"
}

output="$(printf '0\n' | run_tui)"
[[ "$output" == *'Linux 双栈端口白名单管理工具'* ]]
[[ "$output" == *'v1.4.0'* ]]
[[ "$output" == *'运行状态'* ]]
[[ "$output" == *'常用操作'* ]]
[[ "$output" == *'策略管理'* ]]
[[ "$output" == *'系统维护'* ]]
[[ "$output" == *'[1] 添加端口保护'* ]]
[[ "$output" == *'[2] 应用配置'* ]]
[[ "$output" == *'[3] 受保护端口'* ]]
[[ "$output" == *'[4] IP Group'* ]]
[[ "$output" == *'[6] 备份与恢复'* ]]
[[ "$output" == *'[u] 一键更新'* ]]
[[ "$output" == *'[h] 帮助'* ]]
[[ "$output" == *'[0] 退出'* ]]
[[ "$output" == *'请选择操作 ›'* ]]

# 每个菜单项只占一行：标题与说明并排显示。
[[ "$(printf '%s\n' "$output" | grep -c '^  \[[0-9]\] ')" -eq 8 ]]
[[ "$output" == *'[1] 添加端口保护      设置协议与端口，绑定白名单'* ]]

# 面板反映真实链状态，并提示配置是否已经写入防火墙。
[[ "$output" == *'规则未生效'* ]]
[[ "$output" == *'有改动待应用'* ]]
: >"$root/etc/.applied"
output="$(printf '0\n' | run_tui)"
[[ "$output" == *'已与防火墙同步'* ]]

# 无效选项和空行都不会退出面板。
output="$(printf '\nx\n0\n' | run_tui 2>&1)"
[[ "$output" == *'无效选项，请重新选择'* ]]

# 子菜单可以进入并返回主菜单。
output="$(printf '3\n0\n0\n' | run_tui 2>&1)"
[[ "$output" == *'受保护端口'* ]]
[[ "$output" == *'[7] 绑定 IP Group'* ]]
output="$(printf '4\n0\n0\n' | run_tui 2>&1)"
[[ "$output" == *'[3] 添加来源'* ]]
output="$(printf '6\n0\n0\n' | run_tui 2>&1)"
[[ "$output" == *'[3] 恢复备份'* ]]
output="$(printf 'h\n\n0\n' | run_tui 2>&1)"
[[ "$output" == *'使用提示'* ]]
[[ "$output" == *'用法：portsentinel [命令]'* ]]

printf 'PASS: %s\n' "$(basename "$0")"
