#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT_DIR/bin/proxy-doctor"

find "$ROOT_DIR/lib" "$ROOT_DIR/tests" -type f -name '*.sh' -print | while IFS= read -r file; do
  bash -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
  if ! shellcheck -x "$ROOT_DIR/bin/proxy-doctor"; then
    echo "shellcheck reported warnings; syntax and behavioral tests will still run" >&2
  fi
fi

"$ROOT_DIR/tests/test_core.sh"
"$ROOT_DIR/tests/test_repair_policy.sh"

echo "all tests ok"
