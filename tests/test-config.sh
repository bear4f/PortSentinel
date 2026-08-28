#!/usr/bin/env bash
# shellcheck source=test-helper.sh
source "$(dirname "$0")/test-helper.sh"

cp "$(dirname "$0")/../examples/config.example.json" "$CONFIG_FILE"
assert_success 'valid example config' validate_config

jq '.rules[0].sources.ipv4=["999.1.1.1"]' "$CONFIG_FILE" >"$TEST_ROOT/bad-ip.json"
assert_failure 'invalid address config' validate_config "$TEST_ROOT/bad-ip.json"

jq '.rules += [.rules[0]]' "$CONFIG_FILE" >"$TEST_ROOT/duplicate.json"
assert_failure 'duplicate rule and port' validate_config "$TEST_ROOT/duplicate.json"

jq '.rules += [{name:"overlap",protocol:"both",port:"10770:10780",groups:[],sources:{ipv4:[],ipv6:[]},ipv4_default:"drop",ipv6_default:"drop"}]' "$CONFIG_FILE" >"$TEST_ROOT/overlap.json"
assert_failure 'overlapping protocol range' validate_config "$TEST_ROOT/overlap.json"

jq '.rules[0].groups=["missing"]' "$CONFIG_FILE" >"$TEST_ROOT/missing-group.json"
assert_failure 'missing group reference' validate_config "$TEST_ROOT/missing-group.json"
finish_tests
