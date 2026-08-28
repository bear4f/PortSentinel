#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Sourced functions consume these shared globals.
source "$(dirname "$0")/test-helper.sh"

cat >"$CONFIG_FILE" <<'JSON'
{"version":1,"groups":{},"rules":[{"name":"ssh","protocol":"tcp","port":"22816","groups":[],"sources":{"ipv4":["198.51.100.10"],"ipv6":[]},"ipv4_default":"drop","ipv6_default":"drop"}]}
JSON
SSH_CONNECTION='59.51.104.35 50123 192.0.2.20 22816'
NON_INTERACTIVE=1
assert_failure 'unsafe non-interactive SSH apply is rejected' ssh_lockout_check
PRESERVE_CURRENT_SSH=1
assert_success 'explicit current SSH preservation accepted' ssh_lockout_check
generate_rules
v4="$(printf '%s\n' "${RULES_V4[@]}")"
assert_contains 'ephemeral SSH source precedes drop' "$v4" '-p tcp --dport 22816 -s 59.51.104.35 -j ACCEPT'

# 交互式面板给出编号选项：默认取消，强制应用还需要二次确认。
PRESERVE_CURRENT_SSH=0; PRESERVE_SSH_SOURCE=''; PRESERVE_SSH_FAMILY=0; PRESERVE_SSH_PORT=0
NON_INTERACTIVE=0
lockout_log="$TEST_ROOT/lockout.txt"

cancel_status=0
ssh_lockout_check >"$lockout_log" 2>&1 <<'INPUT' || cancel_status=$?
2
INPUT
assert_contains 'lockout prompt offers a numbered choice' "$(<"$lockout_log")" '[1] 临时放行当前 SSH 来源（推荐，不写入配置文件）'
assert_success 'cancelling the lockout prompt stops the apply' test "$cancel_status" -ne 0
assert_success 'cancelling leaves no ephemeral SSH allowance' test -z "$PRESERVE_SSH_SOURCE"

force_status=0
ssh_lockout_check >"$lockout_log" 2>&1 <<'INPUT' || force_status=$?
3
n
INPUT
assert_success 'declining the second confirmation stops the apply' test "$force_status" -ne 0

force_status=0
ssh_lockout_check >"$lockout_log" 2>&1 <<'INPUT' || force_status=$?
3
y
INPUT
assert_success 'confirming twice allows the forced apply' test "$force_status" -eq 0
assert_contains 'forced apply warns about out-of-band access' "$(<"$lockout_log")" '请准备好带外访问方式'
assert_success 'forced apply adds no ephemeral SSH allowance' test -z "$PRESERVE_SSH_SOURCE"

ssh_lockout_check >"$lockout_log" 2>&1 <<'INPUT'
1
INPUT
assert_contains 'choosing preserve keeps config untouched' "$(<"$lockout_log")" 'config.json 不会改变'
assert_success 'preserve records the current SSH source' test "$PRESERVE_SSH_SOURCE" = 59.51.104.35

PRESERVE_SSH_SOURCE=''; PRESERVE_SSH_FAMILY=0; PRESERVE_SSH_PORT=0
NON_INTERACTIVE=1
unset SSH_CONNECTION
SSH_CLIENT='59.51.104.35 50123 22816'
assert_failure 'SSH_CLIENT three-field form is parsed and rejected safely' ssh_lockout_check
finish_tests
