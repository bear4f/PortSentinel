#!/usr/bin/env bash
set -Eeuo pipefail

family="$(basename "$0")"
state="${FAKE_FIREWALL_ROOT:?}/${family}"
mkdir -p "$state/chains"
touch "$state/input"

[[ "${1:-}" == --version ]] && { printf '%s v1.8.9 (nf_tables)\n' "$family"; exit 0; }
if [[ "${1:-}" == -w ]]; then shift 2; fi

op="${1:-}"; shift || true
if [[ "${FAKE_FAIL_FAMILY:-}" == "$family" && "${FAKE_FAIL_OP:-}" == "$op" ]]; then
  exit 42
fi
# 让调用方在这一步收到 SIGINT，用于验证事务操作的信号回滚。
if [[ "${FAKE_SIGNAL_FAMILY:-}" == "$family" && "${FAKE_SIGNAL_OP:-}" == "$op" ]]; then
  kill -"${FAKE_SIGNAL_NAME:-INT}" "$PPID" 2>/dev/null || true
fi
case "$op" in
  -nL)
    [[ -f "$state/chains/${1}" ]]
    ;;
  -L)
    chain="$1"; shift
    if [[ "$chain" == INPUT ]]; then
      printf 'Chain INPUT (policy ACCEPT)\nnum  target prot opt source destination\n'
      number=1
      while IFS= read -r target; do [[ -n "$target" ]] && printf '%d %s all -- 0.0.0.0/0 0.0.0.0/0\n' "$number" "$target"; ((number+=1)); done <"$state/input"
    else
      [[ -f "$state/chains/$chain" ]] || exit 1
      cat "$state/chains/$chain"
    fi
    ;;
  -N) [[ ! -e "$state/chains/${1}" ]] || exit 1; : >"$state/chains/${1}" ;;
  -A) chain="$1"; shift; printf '%s\n' "$*" >>"$state/chains/$chain" ;;
  -C) [[ "$1" == INPUT && "$2" == -j ]]; grep -Fxq "$3" "$state/input" ;;
  -I) [[ "$1" == INPUT ]]; target="${4}"; { printf '%s\n' "$target"; cat "$state/input"; } >"$state/input.tmp"; mv "$state/input.tmp" "$state/input" ;;
  -R)
    [[ "$1" == INPUT ]]; line="$2"; target="$4"
    awk -v line="$line" -v target="$target" 'NR==line {$0=target} {print}' "$state/input" >"$state/input.tmp"; mv "$state/input.tmp" "$state/input"
    ;;
  -D)
    [[ "$1" == INPUT && "$2" == -j ]]; target="$3"
    awk -v target="$target" 'BEGIN{done=0} !done && $0==target {done=1; next} {print}' "$state/input" >"$state/input.tmp"; mv "$state/input.tmp" "$state/input"
    ;;
  -F) : >"$state/chains/${1}" ;;
  -X) rm -f -- "$state/chains/${1}" ;;
  -E)
    old="$1"; new="$2"; mv "$state/chains/$old" "$state/chains/$new"
    awk -v old="$old" -v new="$new" '$0==old {$0=new} {print}' "$state/input" >"$state/input.tmp"; mv "$state/input.tmp" "$state/input"
    ;;
  *) printf 'unsupported fake firewall command: %s %s\n' "$op" "$*" >&2; exit 2 ;;
esac
