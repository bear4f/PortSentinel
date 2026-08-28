#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-test.XXXXXX")"
cleanup_test() { rm -rf -- "$TEST_ROOT"; }
trap cleanup_test EXIT

export PORTSENTINEL_CONFIG_DIR="$TEST_ROOT/etc"
export PORTSENTINEL_CONFIG_FILE="$TEST_ROOT/etc/config.json"
export PORTSENTINEL_BACKUP_DIR="$TEST_ROOT/etc/backups"
export PORTSENTINEL_LOG_FILE="$TEST_ROOT/portsentinel.log"
export PORTSENTINEL_LOCK_FILE="$TEST_ROOT/portsentinel.lock"
export PORTSENTINEL_LIB_ONLY=1
mkdir -p "$PORTSENTINEL_CONFIG_DIR" "$PORTSENTINEL_BACKUP_DIR"

# shellcheck source=../bin/portsentinel
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/portsentinel"

pass_count=0
assert_success() {
    local description="$1"; shift
    if "$@"; then ((pass_count+=1)); else printf 'FAIL: %s\n' "$description" >&2; exit 1; fi
}

assert_failure() {
    local description="$1"; shift
    if "$@" >/dev/null 2>&1; then printf 'FAIL: %s (unexpected success)\n' "$description" >&2; exit 1; else ((pass_count+=1)); fi
}

assert_contains() {
    local description="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then ((pass_count+=1)); else printf 'FAIL: %s: missing %s\n' "$description" "$needle" >&2; exit 1; fi
}

finish_tests() { printf 'PASS: %s (%d assertions)\n' "$(basename "$0")" "$pass_count"; }
