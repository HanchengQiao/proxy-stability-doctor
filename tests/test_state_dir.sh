#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_contains() {
  needle="$1"
  haystack="$2"
  label="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *)
      echo "assertion failed: $label missing '$needle'" >&2
      echo "$haystack" >&2
      exit 1
      ;;
  esac
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

blocked_xdg="$tmp_dir/blocked-xdg"
blocked_home="$tmp_dir/home"
fallback_tmp="$tmp_dir/fallback"
touch "$blocked_xdg"
mkdir -p "$blocked_home" "$fallback_tmp"
touch "$blocked_home/.local"

out="$(env \
  PD_STATE_DIR= \
  PD_ACTION_LOG= \
  PD_COMPACT_OBSERVATION_LOG= \
  PD_COMPACT_STATE= \
  XDG_STATE_HOME="$blocked_xdg" \
  HOME="$blocked_home" \
  TMPDIR="$fallback_tmp" \
  "$ROOT_DIR/bin/proxy-doctor" --agent generic compact status)"

assert_contains "state_source=temporary_fallback" "$out" "temporary fallback source"
assert_contains "state=$fallback_tmp/proxy-stability-doctor-" "$out" "temporary fallback state"

bad_state="$tmp_dir/not-a-directory"
touch "$bad_state"
if "$ROOT_DIR/bin/proxy-doctor" --state-dir "$bad_state" compact status >/dev/null 2>&1; then
  echo "explicit non-directory state path unexpectedly succeeded" >&2
  exit 1
fi

echo "test_state_dir ok"
