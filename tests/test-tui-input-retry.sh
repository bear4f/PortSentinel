#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

default_config >"$CONFIG_FILE"
config_edit test-rule '.rules = [{name:"Snell",protocol:"both",port:"10086",groups:[],sources:{ipv4:[],ipv6:[]},ipv4_default:"drop",ipv6_default:"drop"}]'

retry_output="$(add_rule_source 2>&1 <<'EOF'
wrong
1
7
4

not-an-ip
8.212.49.31
EOF
)"

assert_contains 'invalid rule ID is retried' "$retry_output" '规则 ID 无效，请输入 1-1'
assert_contains 'invalid address family is retried' "$retry_output" '地址族只能选择 4 或 6，请重新输入'
assert_contains 'empty address is retried' "$retry_output" '请输入有效的 IPv4 地址或 CIDR'
assert_contains 'invalid address is retried' "$retry_output" '请输入有效的 IPv4 地址或 CIDR'
assert_contains 'successful retry reports saved source' "$retry_output" '来源已添加'
assert_success 'valid address is stored after retries' jq -e '.rules[0].sources.ipv4 == ["8.212.49.31"]' "$CONFIG_FILE"

list_output="$(list_rules)"
assert_contains 'rule list uses readable heading' "$list_output" '[1] Snell'
assert_contains 'rule list expands protocol' "$list_output" '协议：TCP + UDP'
assert_contains 'rule list explains IPv4 policy' "$list_output" 'IPv4：直接地址 1 个；Group：未绑定；未匹配时拒绝'
assert_contains 'rule list explains IPv6 policy' "$list_output" 'IPv6：直接地址 0 个；Group：未绑定；未匹配时拒绝'

failing_tui_action() { die "模拟操作失败。"; }
guard_output_file="$TEST_ROOT/tui-guard.txt"
run_tui_action failing_tui_action >"$guard_output_file" 2>&1
guard_output="$(<"$guard_output_file")"
assert_contains 'menu action catches fatal function errors' "$guard_output" '操作未完成，已返回当前菜单'

finish_tests
