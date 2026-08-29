#!/usr/bin/env bash
# 备份轮转不得删除本次事务备份，否则回滚会失去唯一依据。
set -Eeuo pipefail

FAKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-keep.XXXXXX")"
FAKE_TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
trap 'rm -rf -- "$FAKE_ROOT"' EXIT
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$FAKE_TESTS_DIR/fake-firewall-env.sh"
cp "$FAKE_TESTS_DIR/../examples/config.example.json" "$PORTSENTINEL_CONFIG_FILE"
printf 'BACKUP_KEEP=0\n' >"$PORTSENTINEL_CONF_FILE"

portsentinel="$FAKE_TESTS_DIR/../bin/portsentinel"

bash "$portsentinel" apply --non-interactive >/dev/null
[[ "$(find "$PORTSENTINEL_BACKUP_DIR" -name '*.ipv4.rules' | wc -l)" -ge 1 ]]

# 注入 IPv6 切换失败：回滚必须成功，失败文案也必须与实际结果一致。
export FAKE_FAIL_FAMILY=ip6tables FAKE_FAIL_OP=-E
: >"$PORTSENTINEL_LOG_FILE"
output="$(bash "$portsentinel" apply --non-interactive 2>&1 || true)"

grep -q 'operation=rollback result=success' "$PORTSENTINEL_LOG_FILE" || {
  printf 'FAIL: rollback failed because rotation removed the transaction backup\n' >&2
  printf -- '--- log ---\n%s\n' "$(cat "$PORTSENTINEL_LOG_FILE")" >&2
  exit 1
}
[[ "$output" == *'已回滚到备份'* ]]
[[ "$output" != *'自动回滚失败'* ]]

# 回滚失败时不得报告成功。
unset FAKE_FAIL_FAMILY FAKE_FAIL_OP
bash "$portsentinel" apply --non-interactive >/dev/null
export FAKE_FAIL_FAMILY=ip6tables FAKE_FAIL_OP=-E
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_ROOT/bin/iptables-restore"
chmod +x "$FAKE_ROOT/bin/iptables-restore"
: >"$PORTSENTINEL_LOG_FILE"
output="$(bash "$portsentinel" apply --non-interactive 2>&1 || true)"
[[ "$output" == *'自动回滚失败，请手动恢复备份'* ]]
[[ "$output" != *'已回滚到备份'* ]]
grep -q 'operation=rollback result=failure' "$PORTSENTINEL_LOG_FILE"

printf 'PASS: %s\n' "$(basename "$0")"
