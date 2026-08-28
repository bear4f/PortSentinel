#!/usr/bin/env bash
set -Eeuo pipefail

CHAIN=PORTSENTINEL
STAGE_CHAIN=PORTSENTINEL_NEW

die() { printf 'PortSentinel uninstall: %s\n' "$*" >&2; exit 1; }
[[ "${EUID}" -eq 0 ]] || die "run as root"

remove_family() {
    local bin="$1" chain
    command -v "$bin" >/dev/null 2>&1 || return 0
    for chain in "$CHAIN" "$STAGE_CHAIN" PORTSENTINEL_OLD; do
        while "$bin" -w 5 -C INPUT -j "$chain" >/dev/null 2>&1; do "$bin" -w 5 -D INPUT -j "$chain"; done
        if "$bin" -w 5 -nL "$chain" >/dev/null 2>&1; then
            "$bin" -w 5 -F "$chain"
            "$bin" -w 5 -X "$chain"
        fi
    done
}

answer=''
if [[ -t 0 ]]; then
    read -r -p 'Uninstall PortSentinel? Type UNINSTALL: ' answer
else
    answer="${PORTSENTINEL_UNINSTALL_CONFIRM:-}"
fi
[[ "$answer" == UNINSTALL ]] || { printf 'Uninstall cancelled.\n'; exit 0; }

remove_family iptables
remove_family ip6tables
if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now portsentinel.service >/dev/null 2>&1 || true
fi
rm -f -- /etc/systemd/system/portsentinel.service /usr/local/bin/portsentinel
rm -rf -- /usr/local/lib/portsentinel
if command -v systemctl >/dev/null 2>&1; then systemctl daemon-reload || true; fi

keep=yes
if [[ -t 0 ]]; then
    read -r -p 'Keep /etc/portsentinel configuration and backups? [Y/n] ' keep
    keep="${keep:-yes}"
fi
if [[ "$keep" =~ ^[Nn] ]]; then
    rm -rf -- /etc/portsentinel
    printf 'Configuration and backups removed.\n'
else
    printf 'Configuration and backups kept in /etc/portsentinel.\n'
fi
printf 'PortSentinel uninstalled. No unrelated firewall rules were changed.\n'
