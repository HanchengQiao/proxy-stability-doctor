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

state_dir="$tmp_dir/state"

out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent codex compact status)"
assert_contains "suggested_token_limit=<insufficient>" "$out" "empty compact status"

"$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent codex compact observe --result success --tokens 40000 --bytes 160000 --source test >/dev/null
out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent codex compact status)"
assert_contains "suggested_token_limit=36000" "$out" "success-only token suggestion"
assert_contains "suggested_byte_limit=144000" "$out" "success-only byte suggestion"
assert_contains "confidence=low" "$out" "success-only confidence"

"$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent codex compact observe --result failure --tokens 50000 --bytes 200000 --source test >/dev/null
out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent codex compact status)"
assert_contains "suggested_token_limit=40000" "$out" "failure token suggestion"
assert_contains "suggested_byte_limit=160000" "$out" "failure byte suggestion"
assert_contains "confidence=medium" "$out" "single failure confidence"

out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" --agent claude compact status)"
assert_contains "suggested_token_limit=<insufficient>" "$out" "profile-isolated threshold"

scan_state="$tmp_dir/scan-state"
scan_log="$tmp_dir/agent.log"
cat > "$scan_log" <<'LOG'
ts=2026-05-01T00:00:00Z compact failure last_api_response_total_tokens=62500 failing_compaction_request_model_visible_bytes=250000
LOG

out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$scan_state" --agent codex compact scan --log-file "$scan_log")"
assert_contains "compact scan imported observations=1" "$out" "scan import count"
assert_contains "suggested_token_limit=50000" "$out" "scan token suggestion"
assert_contains "suggested_byte_limit=200000" "$out" "scan byte suggestion"

echo "test_compact_threshold ok"
