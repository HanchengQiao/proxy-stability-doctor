#!/usr/bin/env bash
set -euo pipefail

repo="${PROXY_DOCTOR_REPO:-HanchengQiao/proxy-stability-doctor}"
version="${PROXY_DOCTOR_VERSION:-main}"
prefix="${INSTALL_PREFIX:-$HOME/.local}"
install_dir="${PROXY_DOCTOR_INSTALL_DIR:-$prefix/share/proxy-stability-doctor}"
bin_dir="$prefix/bin"
binary_path="$bin_dir/proxy-doctor"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

fetch_url() {
  url="$1"
  dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
    return
  fi

  echo "missing required command: curl or wget" >&2
  exit 1
}

case "$version" in
  v*) ref_path="refs/tags/$version" ;;
  *) ref_path="refs/heads/$version" ;;
esac

archive_url="https://github.com/${repo}/archive/${ref_path}.tar.gz"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT INT TERM

need_cmd tar
need_cmd mkdir
need_cmd mv
need_cmd ln

archive_path="$tmp_dir/source.tar.gz"
source_dir="$tmp_dir/source"

echo "Installing proxy-stability-doctor from $repo@$version"
fetch_url "$archive_url" "$archive_path"

mkdir -p "$source_dir"
tar -xzf "$archive_path" -C "$source_dir" --strip-components=1

mkdir -p "$(dirname "$install_dir")"
mkdir -p "$bin_dir"

if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
  backup_dir="${install_dir}.previous.$(date +%Y%m%d%H%M%S)"
  mv "$install_dir" "$backup_dir"
  echo "Backed up previous install to $backup_dir"
fi

mv "$source_dir" "$install_dir"
chmod +x "$install_dir/bin/proxy-doctor"
ln -sfn "$install_dir/bin/proxy-doctor" "$binary_path"

echo "Installed $binary_path"
echo "Run: proxy-doctor version"

