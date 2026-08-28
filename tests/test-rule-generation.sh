#!/usr/bin/env bash
# shellcheck source=test-helper.sh
source "$(dirname "$0")/test-helper.sh"

cat >"$CONFIG_FILE" <<'JSON'
{
  "version":1,
  "groups":{"relay":{"ipv4":["192.0.2.1","192.0.2.1"],"ipv6":["2001:db8::1"]}},
  "rules":[
    {"name":"dual","protocol":"both","port":"10086","groups":["relay"],"sources":{"ipv4":["198.51.100.0/24"],"ipv6":[]},"ipv4_default":"drop","ipv6_default":"drop"},
    {"name":"udp","protocol":"udp","port":"20000:20100","groups":[],"sources":{"ipv4":[],"ipv6":[]},"ipv4_default":"accept","ipv6_default":"accept"}
  ]
}
JSON

# Duplicate input is rejected; normalize it before generation to separately test output de-duplication.
assert_failure 'duplicate group source rejected' validate_config
jq '.groups.relay.ipv4 |= unique' "$CONFIG_FILE" >"$TEST_ROOT/normalized.json"
mv "$TEST_ROOT/normalized.json" "$CONFIG_FILE"
assert_success 'normalized config valid' validate_config
generate_rules
v4="$(printf '%s\n' "${RULES_V4[@]}")"
v6="$(printf '%s\n' "${RULES_V6[@]}")"
assert_contains 'TCP generated' "$v4" '-p tcp --dport 10086'
assert_contains 'UDP generated' "$v4" '-p udp --dport 10086'
assert_contains 'IPv4 group expanded' "$v4" '-s 192.0.2.1 -j ACCEPT'
assert_contains 'IPv4 CIDR expanded' "$v4" '-s 198.51.100.0/24 -j ACCEPT'
assert_contains 'IPv6 group expanded' "$v6" '-s 2001:db8::1 -j ACCEPT'
assert_contains 'range unrestricted return' "$v6" '-p udp --dport 20000:20100 -j RETURN'
finish_tests
