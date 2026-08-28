#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

default_config >"$CONFIG_FILE"

direct_output="$(add_rule 2>&1 <<'EOF'
snell
0
10086
9
3
9
1

not-an-ip
8.212.49.31, 2001:db8::8, 192.0.2.0/24
EOF
)"

assert_contains 'invalid port stays in current step' "$direct_output" '端口无效，请重新输入'
assert_contains 'invalid protocol stays in current step' "$direct_output" '协议选项无效，请重新选择'
assert_contains 'invalid source choice stays in current step' "$direct_output" '白名单来源选项无效，请重新选择'
assert_contains 'empty direct source stays in current step' "$direct_output" 'IP/CIDR 不能为空，请重新输入'
assert_contains 'invalid direct source stays in current step' "$direct_output" 'IP/CIDR 无效：not-an-ip'
assert_contains 'direct source detects address families' "$direct_output" '已识别 IPv4 2 个、IPv6 1 个来源'
assert_success 'direct source rule has expected protocol and port' jq -e '.rules[0].protocol == "both" and .rules[0].port == "10086"' "$CONFIG_FILE"
assert_success 'direct source stores IPv4 values' jq -e '.rules[0].sources.ipv4 == ["192.0.2.0/24", "8.212.49.31"]' "$CONFIG_FILE"
assert_success 'direct source stores IPv6 values' jq -e '.rules[0].sources.ipv6 == ["2001:db8::8"]' "$CONFIG_FILE"
assert_success 'direct source does not create a group reference' jq -e '.rules[0].groups == []' "$CONFIG_FILE"
assert_success 'direct source blocks non-whitelisted dual-stack traffic' jq -e '.rules[0].ipv4_default == "drop" and .rules[0].ipv6_default == "drop"' "$CONFIG_FILE"

config_edit test-group '.groups.office = {ipv4:["198.51.100.10"],ipv6:["2001:db8::10"]}'
group_output="$(add_rule 2>&1 <<'EOF'
web
443
1
2
missing
office
EOF
)"

assert_contains 'group source lists available groups' "$group_output" 'office'
assert_contains 'missing group stays in current step' "$group_output" '找不到 IP Group：missing'
assert_success 'group source stores group binding' jq -e '.rules[1].groups == ["office"]' "$CONFIG_FILE"
assert_success 'group source leaves direct sources empty' jq -e '.rules[1].sources.ipv4 == [] and .rules[1].sources.ipv6 == []' "$CONFIG_FILE"
assert_success 'group source blocks non-whitelisted dual-stack traffic' jq -e '.rules[1].ipv4_default == "drop" and .rules[1].ipv6_default == "drop"' "$CONFIG_FILE"

finish_tests
