#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

default_config >"$CONFIG_FILE"
config_edit test-group '.groups.office = {ipv4:["8.212.49.31"],ipv6:[]}'

batch_output="$(add_group_address 2>&1 <<'EOF'
missing
office

not-an-ip
8.212.49.31, 192.0.2.0/24, 2001:db8::10, 2001:db8:1::/64
EOF
)"

assert_contains 'missing group is retried' "$batch_output" '找不到 IP Group：missing'
assert_contains 'empty batch is retried' "$batch_output" 'IP/CIDR 不能为空，请重新输入'
assert_contains 'invalid batch is retried' "$batch_output" 'IP/CIDR 无效：not-an-ip'
assert_contains 'mixed families are detected' "$batch_output" '已识别 IPv4 2 个、IPv6 2 个来源'
assert_contains 'batch update reports success' "$batch_output" '已批量更新 IP Group：office'
assert_success 'IPv4 group addresses are merged and deduplicated' jq -e '.groups.office.ipv4 == ["192.0.2.0/24", "8.212.49.31"]' "$CONFIG_FILE"
assert_success 'IPv6 group addresses are stored' jq -e '.groups.office.ipv6 == ["2001:db8:1::/64", "2001:db8::10"]' "$CONFIG_FILE"

group_list="$(list_groups)"
assert_contains 'group list shows IPv4 count' "$group_list" 'IPv4（2）'
assert_contains 'group list shows IPv6 count' "$group_list" 'IPv6（2）'

finish_tests
