#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-dry-run.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/etc"
cp "$(dirname "$0")/../examples/config.example.json" "$root/etc/config.json"
output="$(PORTSENTINEL_CONFIG_DIR="$root/etc" PORTSENTINEL_LOG_FILE="$root/log" bash "$(dirname "$0")/../bin/portsentinel" apply --dry-run)"
[[ "$output" == *'===== IPv4 ====='* ]]
[[ "$output" == *'===== IPv6 ====='* ]]
[[ "$output" == *'-s 192.0.2.10 -j ACCEPT'* ]]
[[ "$output" == *'-s 2001:db8::10 -j ACCEPT'* ]]
[[ "$output" == *'-p tcp --dport 10773 -j DROP'* ]]
printf 'PASS: %s\n' "$(basename "$0")"
