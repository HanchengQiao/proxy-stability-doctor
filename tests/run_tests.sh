#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT_DIR/bin/proxy-doctor"

find "$ROOT_DIR/lib" "$ROOT_DIR/tests" -type f -name '*.sh' -print | while IFS= read -r file; do
  bash -n "$file"
done

if [ -d "$ROOT_DIR/scripts" ]; then
  find "$ROOT_DIR/scripts" -type f -name '*.sh' -print | while IFS= read -r file; do
    bash -n "$file"
  done
fi

if command -v shellcheck >/dev/null 2>&1; then
  if ! shellcheck -x "$ROOT_DIR/bin/proxy-doctor"; then
    echo "shellcheck reported warnings; syntax and behavioral tests will still run" >&2
  fi
fi

"$ROOT_DIR/tests/test_core.sh"
"$ROOT_DIR/tests/test_state_dir.sh"
"$ROOT_DIR/tests/test_agent_profiles.sh"
"$ROOT_DIR/tests/test_compact_threshold.sh"
"$ROOT_DIR/tests/test_falemon_adapter.sh"
"$ROOT_DIR/tests/test_repair_policy.sh"
"$ROOT_DIR/tests/test_cli_symlink.sh"
"$ROOT_DIR/tests/test_install_script.sh"

echo "all tests ok"
