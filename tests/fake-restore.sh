#!/usr/bin/env bash
set -Eeuo pipefail
cat >/dev/null
if [[ -n "${FAKE_FIREWALL_ROOT:-}" ]]; then
  printf 'restore\n' >>"${FAKE_FIREWALL_ROOT}/$(basename "$0").calls"
fi
[[ "${FAKE_RESTORE_FAIL:-0}" != 1 ]]
