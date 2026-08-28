#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-rollback.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/bin" "$root/etc/backups" "$root/firewall"
for family in iptables ip6tables; do cp "$(dirname "$0")/fake-iptables.sh" "$root/bin/$family"; done
for family in iptables-save ip6tables-save; do cp "$(dirname "$0")/fake-save.sh" "$root/bin/$family"; done
for family in iptables-restore ip6tables-restore; do cp "$(dirname "$0")/fake-restore.sh" "$root/bin/$family"; done
chmod +x "$root/bin/"*
cp "$(dirname "$0")/../examples/config.example.json" "$root/etc/config.json"

export FAKE_FIREWALL_ROOT="$root/firewall"
export FAKE_FAIL_FAMILY=ip6tables
export FAKE_FAIL_OP=-E
export PORTSENTINEL_CONFIG_DIR="$root/etc"
export PORTSENTINEL_BACKUP_DIR="$root/etc/backups"
export PORTSENTINEL_LOG_FILE="$root/log"
export PORTSENTINEL_LOCK_FILE="$root/lock"
export PORTSENTINEL_ALLOW_NON_ROOT=1
export PORTSENTINEL_IPTABLES="$root/bin/iptables"
export PORTSENTINEL_IP6TABLES="$root/bin/ip6tables"
export PORTSENTINEL_IPTABLES_SAVE="$root/bin/iptables-save"
export PORTSENTINEL_IP6TABLES_SAVE="$root/bin/ip6tables-save"
export PORTSENTINEL_IPTABLES_RESTORE="$root/bin/iptables-restore"
export PORTSENTINEL_IP6TABLES_RESTORE="$root/bin/ip6tables-restore"
export PORTSENTINEL_IP=true
export PORTSENTINEL_FLOCK=true

if bash "$(dirname "$0")/../bin/portsentinel" apply --non-interactive >/dev/null 2>&1; then
  printf 'FAIL: injected IPv6 switch failure unexpectedly succeeded\n' >&2
  exit 1
fi
[[ "$(wc -l <"$root/firewall/iptables-restore.calls")" -eq 1 ]]
[[ "$(wc -l <"$root/firewall/ip6tables-restore.calls")" -eq 1 ]]
grep -q 'operation=rollback result=success' "$root/log"
printf 'PASS: %s\n' "$(basename "$0")"
