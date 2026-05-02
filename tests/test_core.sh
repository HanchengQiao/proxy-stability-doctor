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

pd_is_valid_port 65535 || { echo "valid port was rejected" >&2; exit 1; }
if pd_is_valid_port 0 || pd_is_valid_port 65536 || pd_is_valid_port abc; then
  echo "invalid port was accepted" >&2
  exit 1
fi

pd_status_allowed "403" "200,401,403"
if pd_status_allowed "500" "200,401,403"; then
  echo "status matcher accepted unexpected status" >&2
  exit 1
fi

PD_PROVIDER="Falemon!"
PD_AGENT_PROFILE="OpenAI"
PD_HTTP_PORT=99999
PD_SOCKS_PORT=abc
PD_STATE_DIR="$tmp_dir/config-state"
PD_MAX_LOG_BYTES=bad
unset HTTP_PROXY http_proxy ALL_PROXY all_proxy NO_PROXY no_proxy
pd_finalize_config >/dev/null 2>&1
assert_eq "falemon" "$PD_PROVIDER" "provider normalization"
assert_eq "codex" "$PD_AGENT_PROFILE" "finalized agent normalization"
assert_eq "" "${PD_HTTP_PORT:-}" "invalid http port cleared"
assert_eq "" "${PD_SOCKS_PORT:-}" "invalid socks port cleared"
assert_eq "262144" "$PD_MAX_LOG_BYTES" "invalid positive integer defaulted"

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
