#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Sourced functions consume these shared globals.
source "$(dirname "$0")/test-helper.sh"

cat >"$CONFIG_FILE" <<'JSON'
{"version":1,"groups":{},"rules":[{"name":"ssh","protocol":"tcp","port":"22816","groups":[],"sources":{"ipv4":["198.51.100.10"],"ipv6":[]},"ipv4_default":"drop","ipv6_default":"drop"}]}
JSON
SSH_CONNECTION='59.51.104.35 50123 192.0.2.20 22816'
NON_INTERACTIVE=1
assert_failure 'unsafe non-interactive SSH apply is rejected' ssh_lockout_check
PRESERVE_CURRENT_SSH=1
assert_success 'explicit current SSH preservation accepted' ssh_lockout_check
generate_rules
v4="$(printf '%s\n' "${RULES_V4[@]}")"
assert_contains 'ephemeral SSH source precedes drop' "$v4" '-p tcp --dport 22816 -s 59.51.104.35 -j ACCEPT'

PRESERVE_CURRENT_SSH=0; PRESERVE_SSH_SOURCE=''; PRESERVE_SSH_FAMILY=0; PRESERVE_SSH_PORT=0
unset SSH_CONNECTION
SSH_CLIENT='59.51.104.35 50123 22816'
assert_failure 'SSH_CLIENT three-field form is parsed and rejected safely' ssh_lockout_check
finish_tests
