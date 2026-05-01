#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
ln -s "$ROOT_DIR/bin/proxy-doctor" "$tmp_dir/bin/proxy-doctor"

version="$("$tmp_dir/bin/proxy-doctor" version)"

if [ "$version" != "0.1.0" ]; then
  echo "unexpected symlinked CLI version: $version" >&2
  exit 1
fi

echo "test_cli_symlink ok"
