#!/usr/bin/env bash
# 配置里没有受保护端口时，Apply 必须把防火墙收敛到同一状态，
# 而不是留下上一次生效的规则。
set -Eeuo pipefail

FAKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-empty.XXXXXX")"
FAKE_TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
trap 'rm -rf -- "$FAKE_ROOT"' EXIT
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$FAKE_TESTS_DIR/fake-firewall-env.sh"
cp "$FAKE_TESTS_DIR/../examples/config.example.json" "$PORTSENTINEL_CONFIG_FILE"

portsentinel="$FAKE_TESTS_DIR/../bin/portsentinel"
chain_file="$FAKE_FIREWALL_ROOT/iptables/chains/PORTSENTINEL"

bash "$portsentinel" apply --non-interactive >/dev/null
[[ -f "$chain_file" ]]
grep -q 'PORTSENTINEL' "$FAKE_FIREWALL_ROOT/iptables/input"

jq '.rules = []' "$PORTSENTINEL_CONFIG_FILE" >"$FAKE_ROOT/next.json"
mv "$FAKE_ROOT/next.json" "$PORTSENTINEL_CONFIG_FILE"

# Dry Run 只说明会做什么，不动防火墙。
output="$(bash "$portsentinel" apply --dry-run)"
[[ "$output" == *'移除 INPUT jump 与 PORTSENTINEL 私有链'* ]]
[[ -f "$chain_file" ]]

# 交互式下需要确认；回答 n 时防火墙保持不变。
output="$(printf 'n\n' | bash "$portsentinel" apply 2>&1)"
[[ "$output" == *'原先受保护的端口将对所有来源开放'* ]]
[[ "$output" == *'已取消应用，防火墙保持不变'* ]]
[[ -f "$chain_file" ]]

# 确认后（或非交互模式下）私有链和 INPUT jump 都要被移除。
bash "$portsentinel" apply --non-interactive >/dev/null
[[ ! -f "$chain_file" ]]
if grep -q 'PORTSENTINEL' "$FAKE_FIREWALL_ROOT/iptables/input"; then
  printf 'FAIL: INPUT still jumps to PORTSENTINEL after applying an empty ruleset\n' >&2
  exit 1
fi
[[ ! -f "$FAKE_FIREWALL_ROOT/ip6tables/chains/PORTSENTINEL" ]]
grep -q 'operation=apply result=success rules=0' "$PORTSENTINEL_LOG_FILE"

# 收敛后重复执行是幂等的，并且不会再创建备份。
before_count="$(find "$PORTSENTINEL_BACKUP_DIR" -name '*.ipv4.rules' | wc -l)"
output="$(bash "$portsentinel" apply --non-interactive)"
[[ "$output" == *'防火墙里也没有 PortSentinel 规则，无需应用'* ]]
[[ "$(find "$PORTSENTINEL_BACKUP_DIR" -name '*.ipv4.rules' | wc -l)" -eq "$before_count" ]]

printf 'PASS: %s\n' "$(basename "$0")"
