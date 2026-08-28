#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-tui.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/etc"
cp "$(dirname "$0")/../examples/config.example.json" "$root/etc/config.json"

output="$(printf '0\n' | TERM=dumb PORTSENTINEL_CONFIG_DIR="$root/etc" PORTSENTINEL_LOG_FILE="$root/log" PORTSENTINEL_IP=true bash "$(dirname "$0")/../bin/portsentinel")"
[[ "$output" == *'Linux 双栈端口白名单管理工具'* ]]
[[ "$output" == *'[1] 受保护端口'* ]]
[[ "$output" == *'[2] IP Group 管理'* ]]
[[ "$output" == *'[6] 应用配置'* ]]
[[ "$output" == *'[u] 一键更新'* ]]
[[ "$output" == *'[0] 退出'* ]]
printf 'PASS: %s\n' "$(basename "$0")"
