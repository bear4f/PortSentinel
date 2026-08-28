#!/usr/bin/env bash
# shellcheck disable=SC1091 # Runtime-relative test helper.
source "$(dirname "$0")/test-helper.sh"

assert_success 'IPv4 /0' validate_address 0.0.0.0/0 4
assert_success 'IPv4 /32' validate_address 192.0.2.1/32 4
assert_success 'IPv6 /0' validate_address ::/0 6
assert_success 'IPv6 /128' validate_address 2001:db8::1/128 6
assert_failure 'IPv4 prefix overflow' validate_address 192.0.2.0/33 4
assert_failure 'IPv6 prefix overflow' validate_address 2001:db8::/129 6
finish_tests
