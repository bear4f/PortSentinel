#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-apply.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/bin" "$root/etc/backups" "$root/firewall"
cp "$(dirname "$0")/fake-iptables.sh" "$root/bin/iptables"
cp "$(dirname "$0")/fake-iptables.sh" "$root/bin/ip6tables"
cp "$(dirname "$0")/fake-save.sh" "$root/bin/iptables-save"
cp "$(dirname "$0")/fake-save.sh" "$root/bin/ip6tables-save"
cp "$(dirname "$0")/fake-restore.sh" "$root/bin/iptables-restore"
cp "$(dirname "$0")/fake-restore.sh" "$root/bin/ip6tables-restore"
chmod +x "$root/bin/"*
cp "$(dirname "$0")/../examples/config.example.json" "$root/etc/config.json"

export FAKE_FIREWALL_ROOT="$root/firewall"
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

bash "$(dirname "$0")/../bin/portsentinel" apply --non-interactive
first="$(find "$root/firewall" -type f -print -exec shasum {} \; | sort)"
bash "$(dirname "$0")/../bin/portsentinel" apply --non-interactive
second="$(find "$root/firewall" -type f -print -exec shasum {} \; | sort)"
[[ "$first" == "$second" ]]
[[ "$(grep -c '^PORTSENTINEL$' "$root/firewall/iptables/input")" -eq 1 ]]
[[ "$(grep -c '^PORTSENTINEL$' "$root/firewall/ip6tables/input")" -eq 1 ]]
printf 'PASS: %s\n' "$(basename "$0")"
