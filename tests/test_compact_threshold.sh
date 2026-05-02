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

json_state="$tmp_dir/json-scan-state"
json_log="$tmp_dir/json-agent.log"
cat > "$json_log" <<'LOG'
{"event":"context_compaction","result":"failure","last_api_response_total_tokens":62500,"failing_compaction_request_model_visible_bytes":250000}
LOG

out="$("$ROOT_DIR/bin/proxy-doctor" --state-dir "$json_state" --agent codex compact scan --log-file "$json_log")"
assert_contains "compact scan imported observations=1" "$out" "json scan import count"
assert_contains "suggested_token_limit=50000" "$out" "json scan token suggestion"
assert_contains "suggested_byte_limit=200000" "$out" "json scan byte suggestion"

limited_state="$tmp_dir/limited-scan-state"
limited_log="$tmp_dir/limited-agent.log"
cat > "$limited_log" <<'LOG'
ts=2026-05-01T00:00:01Z compact failure last_api_response_total_tokens=61000 failing_compaction_request_model_visible_bytes=244000
ts=2026-05-01T00:00:02Z compact failure last_api_response_total_tokens=62000 failing_compaction_request_model_visible_bytes=248000
ts=2026-05-01T00:00:03Z compact failure last_api_response_total_tokens=63000 failing_compaction_request_model_visible_bytes=252000
LOG

out="$(PD_COMPACT_SCAN_MAX_OBSERVATIONS=2 "$ROOT_DIR/bin/proxy-doctor" --state-dir "$limited_state" --agent codex compact scan --log-file "$limited_log")"
assert_contains "compact scan imported observations=2" "$out" "scan observation cap"
assert_contains "scan_max_observations=2" "$out" "scan cap status"
limited_count="$(wc -l < "$limited_state/compact-observations.log" | tr -d ' ')"
if [ "$limited_count" != "2" ]; then
  echo "scan observation cap wrote unexpected count: $limited_count" >&2
  exit 1
fi

tail_state="$tmp_dir/tail-scan-state"
tail_log="$tmp_dir/tail-agent.log"
{
  echo "old compact failure last_api_response_total_tokens=90000 failing_compaction_request_model_visible_bytes=360000"
  printf 'padding %.0s' {1..300}
  printf '\n'
  echo "recent compact failure last_api_response_total_tokens=42000 failing_compaction_request_model_visible_bytes=168000"
} > "$tail_log"

out="$(PD_COMPACT_SCAN_MAX_BYTES=180 "$ROOT_DIR/bin/proxy-doctor" --state-dir "$tail_state" --agent codex compact scan --log-file "$tail_log")"
assert_contains "compact scan imported observations=1" "$out" "tail-limited scan count"
assert_contains "suggested_token_limit=33600" "$out" "tail-limited token suggestion"
if grep -q "90000" "$tail_state/compact-observations.log"; then
  echo "tail-limited scan imported an old observation outside the byte window" >&2
  exit 1
fi
if compgen -G "$tail_state/compact-scan.*" >/dev/null; then
  echo "tail-limited scan left raw temporary log material in state directory" >&2
  exit 1
fi

echo "test_compact_threshold ok"
