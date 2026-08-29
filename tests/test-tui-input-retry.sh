#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

default_config >"$CONFIG_FILE"
config_edit test-rule '.rules = [{name:"Snell",protocol:"both",port:"10086",groups:[],sources:{ipv4:[],ipv6:[]},ipv4_default:"drop",ipv6_default:"drop"}]'

retry_output="$(add_rule_source 2>&1 <<'INPUT'
wrong
1
9
1

not-an-ip
8.212.49.31, 2001:db8::5
INPUT
)"

assert_contains 'invalid rule ID is retried' "$retry_output" '规则 ID 无效，请输入 1-1'
assert_contains 'source kind picker offers both direct input and groups' "$retry_output" '[2] 绑定已有 IP Group'
assert_contains 'invalid source kind is retried' "$retry_output" '无效选项，请重新选择'
assert_contains 'rule picker lists rules' "$retry_output" '[1] Snell  ·  TCP+UDP/10086'
assert_contains 'empty address is retried' "$retry_output" 'IP/CIDR 或域名不能为空，请重新输入'
assert_contains 'invalid address is retried' "$retry_output" 'IP/CIDR 或域名无效：not-an-ip'
assert_contains 'address families are detected' "$retry_output" '已识别 IPv4 1 个、IPv6 1 个、域名 0 个来源'
assert_contains 'successful retry reports saved source' "$retry_output" '来源已添加'
assert_success 'valid addresses are stored after retries' jq -e '.rules[0].sources.ipv4 == ["8.212.49.31"] and .rules[0].sources.ipv6 == ["2001:db8::5"]' "$CONFIG_FILE"

remove_output="$(remove_rule_source 2>&1 <<'INPUT'
1
1
2001:db8::5
INPUT
)"
assert_contains 'removal shows the current sources' "$remove_output" '  IPv4：8.212.49.31'
assert_contains 'removal lists bound groups too' "$remove_output" '  IP Group：未绑定'
assert_success 'removed source is dropped' jq -e '.rules[0].sources.ipv6 == []' "$CONFIG_FILE"

list_output="$(list_rules)"
assert_contains 'rule list uses readable heading' "$list_output" '[1] Snell'
assert_contains 'rule list expands protocol' "$list_output" '协议：TCP + UDP'
assert_contains 'rule list explains IPv4 policy' "$list_output" 'IPv4：直接地址 1 个；Group：未绑定；未匹配时拒绝'
assert_contains 'rule list explains IPv6 policy' "$list_output" 'IPv6：直接地址 0 个；Group：未绑定；未匹配时拒绝'

# q 可以在任何输入步骤放弃当前操作，菜单会给出明确提示而不是错误。
cancel_file="$TEST_ROOT/cancel.txt"
run_tui_action add_rule_source >"$cancel_file" 2>&1 <<'INPUT'
1
q
INPUT
assert_contains 'q cancels the current action' "$(<"$cancel_file")" '已放弃当前操作，返回菜单'
assert_success 'cancelling changes nothing' jq -e '.rules[0].sources.ipv4 == ["8.212.49.31"]' "$CONFIG_FILE"

# 同一个入口里也可以绑定 / 解绑 IP Group，不必再去单独的菜单项。
config_edit test-group '.groups.office = {ipv4:["198.51.100.10"],ipv6:[],domains:[]}'
group_output="$(add_rule_source 2>&1 <<'INPUT'
1
2
missing
office
INPUT
)"
assert_contains 'unknown group stays in the current step' "$group_output" '找不到 IP Group：missing'
assert_contains 'binding a group is reported' "$group_output" '已绑定 IP Group：office'
assert_success 'group binding is stored on the rule' jq -e '.rules[0].groups == ["office"]' "$CONFIG_FILE"

unbind_output="$(remove_rule_source 2>&1 <<'INPUT'
1
2
nope
office
INPUT
)"
assert_contains 'unbinding rejects groups the rule does not use' "$unbind_output" '该规则未绑定：nope'
assert_success 'group is detached from the rule' jq -e '.rules[0].groups == []' "$CONFIG_FILE"

failing_tui_action() { die "模拟操作失败。"; }
guard_output_file="$TEST_ROOT/tui-guard.txt"
run_tui_action failing_tui_action >"$guard_output_file" 2>&1
guard_output="$(<"$guard_output_file")"
assert_contains 'menu action catches fatal function errors' "$guard_output" '操作未完成，已返回当前菜单'

# 编辑规则时协议与默认策略改为编号选择。
edit_output="$(edit_rule 2>&1 <<'INPUT'
1
3
9
1
INPUT
)"
assert_contains 'invalid field choice stays in current step' "$edit_output" '无效选项，请重新选择'
assert_success 'protocol is updated through the picker' jq -e '.rules[0].protocol == "tcp"' "$CONFIG_FILE"

delete_output="$(delete_rule 2>&1 <<'INPUT'
1
n
INPUT
)"
assert_contains 'delete asks for a plain confirmation' "$delete_output" '已取消删除'
assert_success 'declined delete keeps the rule' jq -e '.rules | length == 1' "$CONFIG_FILE"

delete_output="$(delete_rule 2>&1 <<'INPUT'
1
y
INPUT
)"
assert_contains 'confirmed delete reports the rule name' "$delete_output" '已删除规则：Snell'
assert_success 'confirmed delete removes the rule' jq -e '.rules | length == 0' "$CONFIG_FILE"

finish_tests
