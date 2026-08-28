#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${PORTSENTINEL_RUN_NETNS:-0}" != 1 ]]; then
    printf 'SKIP: network namespace test requires PORTSENTINEL_RUN_NETNS=1\n'
    exit 0
fi
if [[ "$(uname -s)" != Linux || "${EUID}" -ne 0 ]] || ! command -v ip >/dev/null 2>&1; then
    printf 'SKIP: Linux root with ip-netns is required\n'
    exit 0
fi

namespace="portsentinel-test-$$"
cleanup() { ip netns delete "$namespace" >/dev/null 2>&1 || true; }
trap cleanup EXIT
ip netns add "$namespace"
ip -n "$namespace" link set lo up
ip netns exec "$namespace" iptables -N PORTSENTINEL
ip netns exec "$namespace" iptables -A PORTSENTINEL -p tcp --dport 10773 -s 192.0.2.1 -j ACCEPT
ip netns exec "$namespace" iptables -A PORTSENTINEL -p tcp --dport 10773 -j DROP
ip netns exec "$namespace" iptables -A PORTSENTINEL -j RETURN
ip netns exec "$namespace" iptables -I INPUT 1 -j PORTSENTINEL
ip netns exec "$namespace" ip6tables -N PORTSENTINEL
ip netns exec "$namespace" ip6tables -A PORTSENTINEL -p tcp --dport 10773 -j DROP
ip netns exec "$namespace" ip6tables -A PORTSENTINEL -j RETURN
ip netns exec "$namespace" ip6tables -I INPUT 1 -j PORTSENTINEL
ip netns exec "$namespace" iptables -C INPUT -j PORTSENTINEL
ip netns exec "$namespace" ip6tables -C INPUT -j PORTSENTINEL
printf 'PASS: namespace chains and dual-stack policy loaded\n'
