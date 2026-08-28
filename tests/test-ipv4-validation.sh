#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

assert_success 'IPv4 address' validate_address 192.0.2.1 4
assert_success 'IPv4 zero address' validate_address 0.0.0.0 4
assert_failure 'octet overflow' validate_address 256.1.1.1 4
assert_failure 'short IPv4' validate_address 1.2.3 4
assert_failure 'IPv6 rejected as IPv4' validate_address 2001:db8::1 4
finish_tests
