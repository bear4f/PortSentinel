#!/usr/bin/env bash
# 为使用模拟防火墙后端的测试准备一份隔离环境。
# 用法：source tests/fake-firewall-env.sh  （需先设置 FAKE_ROOT 与 FAKE_TESTS_DIR）
set -Eeuo pipefail

mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/etc/backups" "$FAKE_ROOT/firewall"
for fake_family in iptables ip6tables; do cp "$FAKE_TESTS_DIR/fake-iptables.sh" "$FAKE_ROOT/bin/$fake_family"; done
for fake_family in iptables-save ip6tables-save; do cp "$FAKE_TESTS_DIR/fake-save.sh" "$FAKE_ROOT/bin/$fake_family"; done
for fake_family in iptables-restore ip6tables-restore; do cp "$FAKE_TESTS_DIR/fake-restore.sh" "$FAKE_ROOT/bin/$fake_family"; done
chmod +x "$FAKE_ROOT/bin/"*

export FAKE_FIREWALL_ROOT="$FAKE_ROOT/firewall"
export PORTSENTINEL_CONFIG_DIR="$FAKE_ROOT/etc"
export PORTSENTINEL_CONFIG_FILE="$FAKE_ROOT/etc/config.json"
export PORTSENTINEL_BACKUP_DIR="$FAKE_ROOT/etc/backups"
export PORTSENTINEL_CONF_FILE="$FAKE_ROOT/etc/portsentinel.conf"
export PORTSENTINEL_APPLIED_MARKER="$FAKE_ROOT/etc/.applied"
export PORTSENTINEL_LOG_FILE="$FAKE_ROOT/log"
export PORTSENTINEL_LOCK_FILE="$FAKE_ROOT/lock"
export PORTSENTINEL_ALLOW_NON_ROOT=1
export PORTSENTINEL_IPTABLES="$FAKE_ROOT/bin/iptables"
export PORTSENTINEL_IP6TABLES="$FAKE_ROOT/bin/ip6tables"
export PORTSENTINEL_IPTABLES_SAVE="$FAKE_ROOT/bin/iptables-save"
export PORTSENTINEL_IP6TABLES_SAVE="$FAKE_ROOT/bin/ip6tables-save"
export PORTSENTINEL_IPTABLES_RESTORE="$FAKE_ROOT/bin/iptables-restore"
export PORTSENTINEL_IP6TABLES_RESTORE="$FAKE_ROOT/bin/ip6tables-restore"
export PORTSENTINEL_IP=true
export PORTSENTINEL_FLOCK=true
export TERM=dumb
