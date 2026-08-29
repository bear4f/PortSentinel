#!/usr/bin/env bash
set -Eeuo pipefail

root="$(mktemp -d "${TMPDIR:-/tmp}/portsentinel-backup.XXXXXX")"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/bin" "$root/etc/backups" "$root/firewall"
for family in iptables ip6tables; do cp "$(dirname "$0")/fake-iptables.sh" "$root/bin/$family"; done
for family in iptables-save ip6tables-save; do cp "$(dirname "$0")/fake-save.sh" "$root/bin/$family"; done
for family in iptables-restore ip6tables-restore; do cp "$(dirname "$0")/fake-restore.sh" "$root/bin/$family"; done
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

portsentinel() { bash "$(dirname "$0")/../bin/portsentinel" "$@"; }

# 应用后面板不再提示“待应用”，直到配置再次发生变化。
portsentinel apply --non-interactive >/dev/null
[[ -f "$root/etc/.applied" ]]
panel="$(printf '0\n' | TERM=dumb portsentinel)"
[[ "$panel" == *'已与防火墙同步'* ]]
sleep 1
touch "$root/etc/config.json"
panel="$(printf '0\n' | TERM=dumb portsentinel)"
[[ "$panel" == *'有改动待应用'* ]]

# 每次恢复前的安全备份也必须可以再次恢复。
portsentinel backup >/dev/null
stamp="$(find "$root/etc/backups" -name '*.ipv4.rules' -printf '%f\n' | sort | head -n 1)"
stamp="${stamp%.ipv4.rules}"
portsentinel restore "$stamp" >/dev/null
safety="$(find "$root/etc/backups" -name '*-pre-restore.ipv4.rules' -printf '%f\n' | sort | head -n 1)"
safety="${safety%.ipv4.rules}"
portsentinel restore "$safety" >/dev/null
grep -q "operation=restore result=success set=${safety}" "$root/log"

# 同一秒内重复创建安全备份不会互相覆盖。
portsentinel restore "$stamp" >/dev/null
portsentinel restore "$stamp" >/dev/null
[[ "$(find "$root/etc/backups" -name '*-pre-restore*.ipv4.rules' | wc -l)" -ge 2 ]]

# 交互式恢复接受序号，并拒绝不存在的备份组。
output="$(printf '1\n' | TERM=dumb portsentinel restore 2>&1)"
[[ "$output" == *'[1] '* ]]
[[ "$output" == *'已恢复 IPv4 和 IPv6 备份组'* ]]
if portsentinel restore 20200101-000000 >/dev/null 2>&1; then
  printf 'FAIL: unknown backup stamp was accepted\n' >&2
  exit 1
fi

# reset 与 restore 之后，"已与防火墙同步" 的标记必须失效。
portsentinel apply --non-interactive >/dev/null
[[ -f "$root/etc/.applied" ]]
portsentinel reset --non-interactive >/dev/null
[[ ! -f "$root/etc/.applied" ]]
status="$(portsentinel status)"
[[ "$status" == *'规则未生效'* ]]
if [[ "$status" == *'已与防火墙同步'* ]]; then
  printf 'FAIL: status still claims the firewall matches the config after reset\n' >&2
  exit 1
fi

portsentinel apply --non-interactive >/dev/null
[[ -f "$root/etc/.applied" ]]
output="$(portsentinel restore "$stamp" 2>&1)"
[[ "$output" == *'与 config.json 可能不一致'* ]]
[[ ! -f "$root/etc/.applied" ]]
panel="$(printf '0\n' | TERM=dumb portsentinel)"
[[ "$panel" == *'有改动待应用'* ]]

printf 'PASS: %s\n' "$(basename "$0")"
