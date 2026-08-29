#!/usr/bin/env bash
# 供测试使用的假解析器：从 FAKE_DNS_FILE 中读取 "<域名> <地址> [地址...]"。
# 域名不在文件中时返回非零，模拟解析失败。
set -Eeuo pipefail

domain="$1"
[[ -r "${FAKE_DNS_FILE:-}" ]] || exit 1

line="$(awk -v want="$domain" '$1 == want {$1=""; print; exit}' "$FAKE_DNS_FILE")"
[[ -n "${line// /}" ]] || exit 1

for address in $line; do
    if [[ "$address" == *:* ]]; then printf '6\t%s\n' "$address"; else printf '4\t%s\n' "$address"; fi
done
