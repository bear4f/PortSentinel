#!/usr/bin/env bash
# shellcheck source=test-helper.sh
source "$(dirname "$0")/test-helper.sh"

assert_success 'lowest port' validate_port 1
assert_success 'highest port' validate_port 65535
assert_success 'port range' validate_port 20000:20100
assert_failure 'zero port' validate_port 0
assert_failure 'overflow port' validate_port 65536
assert_failure 'descending range' validate_port 20100:20000
assert_failure 'hyphen range' validate_port 100-200
finish_tests
