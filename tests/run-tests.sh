#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
find "$repo" -type f \( -name '*.sh' -o -path "$repo/bin/portsentinel" \) -print0 | while IFS= read -r -d '' file; do bash -n "$file"; done

tests=(
  test-ipv4-validation.sh
  test-ipv6-validation.sh
  test-cidr-validation.sh
  test-port-validation.sh
  test-config.sh
  test-rule-generation.sh
  test-ipv6-empty-whitelist.sh
  test-ssh-protection.sh
  test-dry-run.sh
  test-apply-idempotent.sh
  test-rollback.sh
  test-netns.sh
)
for test_file in "${tests[@]}"; do bash "$repo/tests/$test_file"; done
printf 'All PortSentinel tests passed.\n'
