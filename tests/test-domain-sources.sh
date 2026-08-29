#!/usr/bin/env bash
# 域名来源：保存域名本身，每次应用前重新解析；解析失败时沿用上次结果。
set -Eeuo pipefail

FAKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-domain.XXXXXX")"
FAKE_TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
trap 'rm -rf -- "$FAKE_ROOT"' EXIT
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$FAKE_TESTS_DIR/fake-firewall-env.sh"
export PORTSENTINEL_RESOLVER="$FAKE_TESTS_DIR/fake-resolver.sh"
export FAKE_DNS_FILE="$FAKE_ROOT/dns"
portsentinel="$FAKE_TESTS_DIR/../bin/portsentinel"

printf 'relay.example.com 203.0.113.10 2001:db8::10\n' >"$FAKE_DNS_FILE"
cat >"$PORTSENTINEL_CONFIG_FILE" <<'JSON'
{"version":1,
 "groups":{"relay":{"ipv4":["198.51.100.1"],"ipv6":[],"domains":["relay.example.com"]}},
 "rules":[{"name":"xray","protocol":"tcp","port":"443","groups":["relay"],
           "sources":{"ipv4":[],"ipv6":[],"domains":[]},
           "ipv4_default":"drop","ipv6_default":"drop"}]}
JSON

# 解析结果进入白名单，IPv4 与 IPv6 各自归位。
output="$(bash "$portsentinel" apply --dry-run)"
[[ "$output" == *'-s 203.0.113.10 -j ACCEPT'* ]]
[[ "$output" == *'-s 2001:db8::10 -j ACCEPT'* ]]
[[ "$output" == *'-s 198.51.100.1 -j ACCEPT'* ]]

# 域名指向新地址后，重新应用即可跟随，无需改配置。
printf 'relay.example.com 203.0.113.99\n' >"$FAKE_DNS_FILE"
output="$(bash "$portsentinel" apply --dry-run)"
[[ "$output" == *'-s 203.0.113.99 -j ACCEPT'* ]]
[[ "$output" != *'-s 203.0.113.10 -j ACCEPT'* ]]
[[ "$output" != *'2001:db8::10'* ]]

# 解析失败时沿用上次结果，不会把白名单缩空。
: >"$FAKE_DNS_FILE"
output="$(bash "$portsentinel" apply --dry-run 2>&1)"
[[ "$output" == *'本次沿用上次解析结果'* ]]
[[ "$output" == *'-s 203.0.113.99 -j ACCEPT'* ]]

# 从未解析成功过的域名会明确告警，且不会静默进入白名单。
jq '.groups.relay.domains += ["never.example.com"]' "$PORTSENTINEL_CONFIG_FILE" >"$FAKE_ROOT/next.json"
mv "$FAKE_ROOT/next.json" "$PORTSENTINEL_CONFIG_FILE"
output="$(bash "$portsentinel" apply --dry-run 2>&1)"
[[ "$output" == *'解析失败且没有历史记录：never.example.com'* ]]
[[ "$output" == *'部分域名无法解析'* ]]

# 非交互应用在这种情况下继续收敛，交互式则需要确认。
printf 'relay.example.com 203.0.113.99\nnever.example.com 203.0.113.77\n' >"$FAKE_DNS_FILE"
bash "$portsentinel" apply --non-interactive >/dev/null
grep -q '203.0.113.77' "$FAKE_FIREWALL_ROOT/iptables/chains/PORTSENTINEL"
[[ "$(jq -r '.domains["relay.example.com"].ipv4[0]' "$FAKE_ROOT/etc/resolved.json")" == 203.0.113.99 ]]

# resolve 命令单独刷新并展示结果。
printf 'relay.example.com 203.0.113.55\nnever.example.com 203.0.113.77\n' >"$FAKE_DNS_FILE"
output="$(bash "$portsentinel" resolve)"
[[ "$output" == *'relay.example.com'* ]]
[[ "$output" == *'203.0.113.55'* ]]

# 配置中不再引用的域名会从缓存中清理。
jq '.groups.relay.domains = ["relay.example.com"]' "$PORTSENTINEL_CONFIG_FILE" >"$FAKE_ROOT/next.json"
mv "$FAKE_ROOT/next.json" "$PORTSENTINEL_CONFIG_FILE"
bash "$portsentinel" resolve >/dev/null
[[ "$(jq -r '.domains | keys | join(",")' "$FAKE_ROOT/etc/resolved.json")" == 'relay.example.com' ]]

# 缓存不可写时（例如非 root 执行 --dry-run），本次解析结果仍然生效，
# 并且给出的是写入失败的提示，而不是误报解析失败。
output="$(PORTSENTINEL_RESOLVED_FILE=/proc/nowhere/resolved.json bash "$portsentinel" apply --dry-run 2>&1)"
[[ "$output" == *'无法写入解析缓存'* ]]
[[ "$output" == *'-s 203.0.113.55 -j ACCEPT'* ]]
[[ "$output" != *'解析失败'* ]]

# 域名同样参与 SSH 防锁死判断。
printf 'relay.example.com 203.0.113.55\n' >"$FAKE_DNS_FILE"
cat >"$PORTSENTINEL_CONFIG_FILE" <<'JSON'
{"version":1,"groups":{},
 "rules":[{"name":"ssh","protocol":"tcp","port":"22816","groups":[],
           "sources":{"ipv4":[],"ipv6":[],"domains":["relay.example.com"]},
           "ipv4_default":"drop","ipv6_default":"drop"}]}
JSON
SSH_CONNECTION='203.0.113.55 50123 192.0.2.20 22816' bash "$portsentinel" apply --non-interactive >/dev/null
if SSH_CONNECTION='203.0.113.56 50123 192.0.2.20 22816' bash "$portsentinel" apply --non-interactive >/dev/null 2>&1; then
  printf 'FAIL: a source outside the resolved domain was not caught by the SSH check\n' >&2
  exit 1
fi

# 语法非法的域名在校验阶段就被拒绝。
jq '.rules[0].sources.domains = ["not a domain"]' "$PORTSENTINEL_CONFIG_FILE" >"$FAKE_ROOT/next.json"
mv "$FAKE_ROOT/next.json" "$PORTSENTINEL_CONFIG_FILE"
if bash "$portsentinel" apply --dry-run >/dev/null 2>&1; then
  printf 'FAIL: invalid domain syntax was accepted\n' >&2
  exit 1
fi

# 交互式输入：域名当场解析并回显，解析不了的当场拒绝。
cat >"$PORTSENTINEL_CONFIG_FILE" <<'JSON'
{"version":1,"groups":{"Us":{"ipv4":[],"ipv6":[],"domains":[]}},"rules":[]}
JSON
printf 'prowee.example.com 203.0.113.21\npalmspring.example.com 203.0.113.22 2001:db8::22\n' >"$FAKE_DNS_FILE"

interactive_output="$(PORTSENTINEL_LIB_ONLY=1 bash -c 'source "$1"; add_group_address' _ "$portsentinel" 2>&1 <<'INPUT'
Us
nx.example.com
prowee.example.com, palmspring.example.com, 198.51.100.9
INPUT
)"
[[ "$interactive_output" == *'域名解析失败：nx.example.com'* ]]
[[ "$interactive_output" == *'prowee.example.com → IPv4 203.0.113.21'* ]]
[[ "$interactive_output" == *'palmspring.example.com → IPv4 203.0.113.22 IPv6 2001:db8::22'* ]]
[[ "$interactive_output" == *'已识别 IPv4 1 个、IPv6 0 个、域名 2 个来源'* ]]
[[ "$(jq -r '.groups.Us.domains | join(",")' "$PORTSENTINEL_CONFIG_FILE")" == 'palmspring.example.com,prowee.example.com' ]]
[[ "$(jq -r '.groups.Us.ipv4 | join(",")' "$PORTSENTINEL_CONFIG_FILE")" == '198.51.100.9' ]]

# 列表里能看到域名和它当前解析到的地址。
bash "$portsentinel" resolve >/dev/null
list_output="$(bash "$portsentinel" group list)"
[[ "$list_output" == *'域名 prowee.example.com → 203.0.113.21'* ]]

# 删除来源同样接受域名。
PORTSENTINEL_LIB_ONLY=1 bash -c 'source "$1"; remove_group_address' _ "$portsentinel" >/dev/null 2>&1 <<'INPUT'
Us
prowee.example.com
INPUT
[[ "$(jq -r '.groups.Us.domains | join(",")' "$PORTSENTINEL_CONFIG_FILE")" == 'palmspring.example.com' ]]

printf 'PASS: %s\n' "$(basename "$0")"
