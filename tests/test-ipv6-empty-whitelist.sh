#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

cat >"$CONFIG_FILE" <<'JSON'
{"version":1,"groups":{},"rules":[{"name":"no-v6-bypass","protocol":"tcp","port":"10773","groups":[],"sources":{"ipv4":["23.27.240.187"],"ipv6":[]},"ipv4_default":"drop","ipv6_default":"drop"}]}
JSON
assert_success 'security regression config valid' validate_config
generate_rules
v6="$(printf '%s\n' "${RULES_V6[@]}")"
assert_contains 'empty IPv6 whitelist still drops' "$v6" '-p tcp --dport 10773 -j DROP'
finish_tests
