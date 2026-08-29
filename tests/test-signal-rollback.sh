#!/usr/bin/env bash
# 面板里的操作跑在 ( ) 子 shell 中，而 bash 会重置子 shell 的 trap。
# 本测试确保 Apply 途中收到 SIGINT 时事务仍然会回滚。
set -Eeuo pipefail

FAKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-signal.XXXXXX")"
FAKE_TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
trap 'rm -rf -- "$FAKE_ROOT"' EXIT
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$FAKE_TESTS_DIR/fake-firewall-env.sh"
cp "$FAKE_TESTS_DIR/../examples/config.example.json" "$PORTSENTINEL_CONFIG_FILE"

portsentinel="$FAKE_TESTS_DIR/../bin/portsentinel"

# 先应用一次，让防火墙里存在可回滚的既有状态。
bash "$portsentinel" apply --non-interactive >/dev/null
before="$(cat "$FAKE_FIREWALL_ROOT/iptables/chains/PORTSENTINEL")"

# 第二次应用时，在 IPv6 改名这一步向 PortSentinel 发送信号。
# 修复前：面板路径下 SIGINT 会被吞掉（Apply 照常完成），SIGTERM 则直接杀死
# 子 shell 且不回滚，留下 IPv4 已切换、IPv6 未切换的半应用状态。
export FAKE_SIGNAL_FAMILY=ip6tables FAKE_SIGNAL_OP=-E

for signal_name in INT TERM; do
  export FAKE_SIGNAL_NAME="$signal_name"
  : >"$PORTSENTINEL_LOG_FILE"

  # 走面板路径：菜单 [2] 应用配置 由 run_tui_action 在子 shell 中执行。
  printf '2\n\n0\n' | bash "$portsentinel" >/dev/null 2>&1 || true

  grep -q 'operation=rollback result=success' "$PORTSENTINEL_LOG_FILE" || {
    printf 'FAIL: SIG%s during a panel apply did not trigger a rollback\n' "$signal_name" >&2
    printf -- '--- log ---\n%s\n' "$(cat "$PORTSENTINEL_LOG_FILE")" >&2
    exit 1
  }
  grep -q 'operation=apply result=success' "$PORTSENTINEL_LOG_FILE" && {
    printf 'FAIL: SIG%s during a panel apply was swallowed\n' "$signal_name" >&2
    exit 1
  }
  [[ "$(cat "$FAKE_FIREWALL_ROOT/iptables/chains/PORTSENTINEL")" == "$before" ]]
done
[[ "$(wc -l <"$FAKE_FIREWALL_ROOT/iptables-restore.calls")" -ge 2 ]]
[[ "$(wc -l <"$FAKE_FIREWALL_ROOT/ip6tables-restore.calls")" -ge 2 ]]

# 命令行路径同样要回滚。
export FAKE_SIGNAL_NAME=INT
: >"$PORTSENTINEL_LOG_FILE"
bash "$portsentinel" apply --non-interactive >/dev/null 2>&1 || true
grep -q 'operation=rollback result=success' "$PORTSENTINEL_LOG_FILE"

printf 'PASS: %s\n' "$(basename "$0")"
