#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../lib/proxy_doctor/core.sh
. "$ROOT_DIR/lib/proxy_doctor/core.sh"
# shellcheck source=../lib/proxy_doctor/adapters/falemon.sh
. "$ROOT_DIR/lib/proxy_doctor/adapters/falemon.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

PD_FALEMON_CHECK_HTTP_PROCESS=0
PD_FALEMON_CHECK_LF_PROCESS=0
PD_FALEMON_REQUIRE_PROCESSES=0
PD_HTTP_PORT=""
PD_SOCKS_PORT=""

if pd_adapter_status >"$tmp_dir/status.out" 2>"$tmp_dir/status.err"; then
  echo "expected falemon status to fail when no required health signals are configured" >&2
  exit 1
fi

if ! grep -q "no required falemon health signal configured" "$tmp_dir/status.err"; then
  echo "expected missing health signal warning" >&2
  exit 1
fi

echo "test_falemon_adapter ok"
