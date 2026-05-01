#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "$1" >&2
  exit 1
}

prefix="$tmp_dir/prefix"
home_dir="$tmp_dir/home"
mkdir -p "$home_dir"

HOME="$home_dir" INSTALL_PREFIX="$prefix" PROXY_DOCTOR_SOURCE_DIR="$ROOT_DIR" "$ROOT_DIR/scripts/install.sh" >"$tmp_dir/install.out"

binary="$prefix/bin/proxy-doctor"
install_dir="$prefix/share/proxy-stability-doctor"

[ -x "$binary" ] || fail "installed proxy-doctor is not executable"
[ -d "$install_dir" ] || fail "install directory was not created"

version="$("$binary" version)"
[ "$version" = "0.1.0" ] || fail "unexpected installed version: $version"

grep -q "Installed $binary (version 0.1.0)" "$tmp_dir/install.out" || fail "installer did not print success message"

HOME="$home_dir" INSTALL_PREFIX="$prefix" PROXY_DOCTOR_SOURCE_DIR="$ROOT_DIR" "$ROOT_DIR/scripts/install.sh" >"$tmp_dir/reinstall.out"

"$binary" version >/dev/null
find "$prefix/share" -maxdepth 1 -type d -name 'proxy-stability-doctor.previous.*' | grep -q . || fail "reinstall did not keep a backup"
find "$prefix/bin" -maxdepth 1 -name 'proxy-doctor.previous.*' | grep -q . || fail "reinstall did not keep executable backup"
grep -q "Backed up previous install" "$tmp_dir/reinstall.out" || fail "reinstall did not report backup"
grep -q "Backed up previous executable" "$tmp_dir/reinstall.out" || fail "reinstall did not report executable backup"

echo "test_install_script ok"
