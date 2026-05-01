#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PD_ROOT_DIR="$ROOT_DIR"
PD_LIB_DIR="$ROOT_DIR/lib/proxy_doctor"

. "$PD_LIB_DIR/core.sh"
. "$PD_LIB_DIR/config.sh"

assert_eq() {
  expected="$1"
  actual="$2"
  label="$3"
  if [ "$expected" != "$actual" ]; then
    echo "assertion failed: $label expected='$expected' actual='$actual'" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_eq "7890" "$(pd_url_port 'http://127.0.0.1:7890')" "http port parse"
assert_eq "7891" "$(pd_url_port 'socks5h://user:pass@[::1]:7891')" "ipv6 socks port parse"

pd_status_allowed "403" "200,401,403"
if pd_status_allowed "500" "200,401,403"; then
  echo "status matcher accepted unexpected status" >&2
  exit 1
fi

PD_STATE_DIR="$tmp_dir/state"
PD_ACTION_LOG="$PD_STATE_DIR/actions.log"
PD_MAX_LOG_BYTES=120
PD_MAX_LOG_LINE_BYTES=40
for n in 1 2 3 4 5 6 7 8 9 10; do
  pd_append_event "event$n" "abcdefghijklmnopqrstuvwxyz0123456789"
done
size="$(wc -c < "$PD_ACTION_LOG" | tr -d ' ')"
if [ "$size" -gt 120 ]; then
  echo "compact log was not trimmed: $size" >&2
  exit 1
fi

pd_lock_acquire
pd_lock_release

echo "test_core ok"

