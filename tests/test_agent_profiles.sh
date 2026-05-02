#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PD_ROOT_DIR="$ROOT_DIR"
PD_LIB_DIR="$ROOT_DIR/lib/proxy_doctor"

. "$PD_LIB_DIR/core.sh"
. "$PD_LIB_DIR/config.sh"

assert_contains() {
  needle="$1"
  haystack="$2"
  label="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *)
      echo "assertion failed: $label missing '$needle'" >&2
      exit 1
      ;;
  esac
}

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

assert_eq "claude-code" "$(pd_normalize_agent_profile 'Claude Code!')" "agent profile normalization"
assert_eq "generic" "$(pd_normalize_agent_profile '!!!')" "empty agent profile fallback"
assert_eq "codex" "$(pd_normalize_agent_profile 'OpenAI')" "openai alias normalization"
assert_eq "codex" "$(pd_normalize_agent_profile 'codex_cli')" "codex cli alias normalization"
assert_eq "claude-code" "$(pd_normalize_agent_profile 'anthropic')" "anthropic alias normalization"

PD_AGENT_PROFILE=codex
codex_targets="$(pd_probe_targets)"
assert_contains "api.openai.com" "$codex_targets" "codex api target"
assert_contains "chatgpt.com" "$codex_targets" "codex web target"

PD_AGENT_PROFILE=anthropic
claude_targets="$(pd_probe_targets)"
assert_contains "api.anthropic.com" "$claude_targets" "claude api target"
assert_contains "claude.ai" "$claude_targets" "claude web target"

PD_AGENT_PROFILE=generic
generic_targets="$(pd_probe_targets)"
assert_contains "example.com" "$generic_targets" "generic target"

PD_PROBE_TARGETS_FILE="$tmp_dir/probes.txt"
printf '%s\n' 'local test|https://example.invalid/health|204' > "$PD_PROBE_TARGETS_FILE"
assert_eq "local test|https://example.invalid/health|204" "$(pd_probe_targets)" "probe file override"

echo "test_agent_profiles ok"
