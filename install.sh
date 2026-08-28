#!/usr/bin/env bash
# PortSentinel installer
set -Eeuo pipefail
umask 077

readonly REPOSITORY="bear4f/PortSentinel"
readonly REF="${PORTSENTINEL_REF:-main}"
readonly RAW_BASE="https://raw.githubusercontent.com/${REPOSITORY}/${REF}"
UPDATE_MODE=0
[[ "${1:-}" == --update ]] && UPDATE_MODE=1

info() { printf '[PortSentinel] %s\n' "$*"; }
die() { printf '[PortSentinel] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "Run this installer as root."

packages=()
command -v curl >/dev/null 2>&1 || packages+=(curl)
command -v iptables >/dev/null 2>&1 || packages+=(iptables)
command -v ip6tables >/dev/null 2>&1 || packages+=(iptables)
command -v ip >/dev/null 2>&1 || packages+=(iproute2)
command -v ss >/dev/null 2>&1 || packages+=(iproute2)
command -v flock >/dev/null 2>&1 || packages+=(util-linux)
command -v jq >/dev/null 2>&1 || packages+=(jq)
command -v python3 >/dev/null 2>&1 || packages+=(python3)

if (( ${#packages[@]} )); then
    command -v apt-get >/dev/null 2>&1 || die "Missing dependencies: ${packages[*]}. Automatic installation supports Debian/Ubuntu apt."
    info "Installing required packages: ${packages[*]}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "${packages[@]}"
fi

stage="$(mktemp -d /tmp/portsentinel-install.XXXXXX)"
cleanup() { rm -rf -- "$stage"; }
trap cleanup EXIT

fetch() {
    local relative="$1" destination="$2"
    if [[ -n "${PORTSENTINEL_SOURCE_DIR:-}" && -f "${PORTSENTINEL_SOURCE_DIR}/${relative}" ]]; then
        cp "${PORTSENTINEL_SOURCE_DIR}/${relative}" "$destination"
    else
        curl -fsSL --proto '=https' --tlsv1.2 "${RAW_BASE}/${relative}" -o "$destination"
    fi
}

fetch bin/portsentinel "$stage/portsentinel"
fetch systemd/portsentinel.service "$stage/portsentinel.service"
fetch uninstall.sh "$stage/uninstall.sh"
bash -n "$stage/portsentinel"
bash -n "$stage/uninstall.sh"
grep -q '^Description=PortSentinel' "$stage/portsentinel.service" || die "Invalid systemd service file."
grep -q 'readonly VERSION=' "$stage/portsentinel" || die "Invalid PortSentinel executable."

install -d -m 700 /etc/portsentinel /etc/portsentinel/backups
chown root:root /etc/portsentinel /etc/portsentinel/backups
chmod 700 /etc/portsentinel /etc/portsentinel/backups
if [[ ! -f /etc/portsentinel/config.json ]]; then
    printf '%s\n' '{"version":1,"groups":{},"rules":[]}' >"$stage/config.json"
    install -o root -g root -m 600 "$stage/config.json" /etc/portsentinel/config.json
fi
if [[ ! -f /etc/portsentinel/portsentinel.conf ]]; then
    printf '%s\n' 'BACKUP_KEEP=20' >"$stage/portsentinel.conf"
    install -o root -g root -m 600 "$stage/portsentinel.conf" /etc/portsentinel/portsentinel.conf
fi

install -d -o root -g root -m 755 /usr/local/lib/portsentinel
install -o root -g root -m 755 "$stage/portsentinel" /usr/local/bin/portsentinel
install -o root -g root -m 755 "$stage/uninstall.sh" /usr/local/lib/portsentinel/uninstall.sh
install -o root -g root -m 644 "$stage/portsentinel.service" /etc/systemd/system/portsentinel.service

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable portsentinel.service >/dev/null
fi

if (( UPDATE_MODE )); then
    info "Update complete: $(/usr/local/bin/portsentinel version)"
else
    info "Installation complete. No firewall rules were changed."
    info "Run 'sudo portsentinel' to create a policy, review the dry run, and apply it."
fi
