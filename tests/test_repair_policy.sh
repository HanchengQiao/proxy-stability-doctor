#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

state_dir="$tmp_dir/state"
adapter="$ROOT_DIR/tests/fixtures/mock_adapter.sh"

PD_ADAPTER_PATH="$adapter" \
"$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" repair --no-probes > "$tmp_dir/dry-run.log"

if [ -f "$state_dir/mock_restarted" ]; then
  echo "dry-run repair unexpectedly restarted" >&2
  exit 1
fi

PD_ADAPTER_PATH="$adapter" \
"$ROOT_DIR/bin/proxy-doctor" --state-dir "$state_dir" repair --no-probes --allow-restart --apply > "$tmp_dir/apply.log"

if [ ! -f "$state_dir/mock_restarted" ]; then
  echo "apply repair did not invoke adapter restart" >&2
  exit 1
fi

if [ ! -f "$state_dir/mock_healthy" ]; then
  echo "apply repair did not reach healthy marker" >&2
  exit 1
fi

echo "test_repair_policy ok"
