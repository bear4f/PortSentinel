#!/usr/bin/env bash
# shellcheck source=test-helper.sh
source "$(dirname "$0")/test-helper.sh"

assert_success 'compressed IPv6' validate_address 2001:db8::1 6
assert_success 'loopback IPv6' validate_address ::1 6
assert_failure 'invalid hex' validate_address 2001:db8::gg 6
assert_failure 'double compression' validate_address 2001::db8::1 6
assert_failure 'IPv4 rejected as IPv6' validate_address 192.0.2.1 6
finish_tests
