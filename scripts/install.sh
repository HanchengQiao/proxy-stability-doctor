#!/usr/bin/env bash
set -euo pipefail

repo="${PROXY_DOCTOR_REPO:-HanchengQiao/proxy-stability-doctor}"
version="${PROXY_DOCTOR_VERSION:-main}"

if [ -n "${INSTALL_PREFIX:-}" ]; then
  prefix="$INSTALL_PREFIX"
else
  if [ -z "${HOME:-}" ]; then
    echo "ERROR: HOME is unset; set INSTALL_PREFIX=/path/to/prefix" >&2
    exit 1
  fi
  prefix="$HOME/.local"
fi

install_dir="${PROXY_DOCTOR_INSTALL_DIR:-$prefix/share/proxy-stability-doctor}"
bin_dir="${PROXY_DOCTOR_BIN_DIR:-$prefix/bin}"
binary_path="$bin_dir/proxy-doctor"
tmp_dir=""
backup_dir=""
binary_backup=""
placed_install_dir=0
install_done=0

say() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "missing required command: $1"
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

  fail "missing required command: curl or wget"
}

unique_backup_path() {
  base_path="$1"
  candidate="$base_path"
  index=1

  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="${base_path}.${index}"
    index=$((index + 1))
  done

  printf '%s\n' "$candidate"
}

case "$version" in
  v*) ref_path="refs/tags/$version" ;;
  *) ref_path="refs/heads/$version" ;;
esac

archive_url="${PROXY_DOCTOR_ARCHIVE_URL:-https://github.com/${repo}/archive/${ref_path}.tar.gz}"

cleanup() {
  status=$?

  if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi

  if [ "$status" -ne 0 ] && [ "$install_done" -ne 1 ]; then
    if [ "$placed_install_dir" -eq 1 ]; then
      rm -rf "$install_dir" 2>/dev/null || true
    fi

    if [ -n "${backup_dir:-}" ] && [ -e "$backup_dir" ]; then
      if mv "$backup_dir" "$install_dir" 2>/dev/null; then
        warn "restored previous install from $backup_dir"
      else
        warn "could not restore previous install from $backup_dir"
      fi
    fi

    if [ -n "${binary_backup:-}" ] && [ -e "$binary_backup" ]; then
      rm -f "$binary_path" 2>/dev/null || true
      if mv "$binary_backup" "$binary_path" 2>/dev/null; then
        warn "restored previous executable from $binary_backup"
      else
        warn "could not restore previous executable from $binary_backup"
      fi
    fi
  fi

  exit "$status"
}

trap cleanup EXIT INT TERM

need_cmd mktemp
need_cmd rm
need_cmd tar
need_cmd mkdir
need_cmd dirname
need_cmd mv
need_cmd ln
need_cmd chmod
need_cmd date

tmp_dir="$(mktemp -d)"

archive_path="$tmp_dir/source.tar.gz"
source_dir="$tmp_dir/source"

say "Installing proxy-stability-doctor"

mkdir -p "$source_dir"

if [ -n "${PROXY_DOCTOR_SOURCE_DIR:-}" ]; then
  if [ ! -d "$PROXY_DOCTOR_SOURCE_DIR" ]; then
    fail "PROXY_DOCTOR_SOURCE_DIR does not exist: $PROXY_DOCTOR_SOURCE_DIR"
  fi
  say "Using local source: $PROXY_DOCTOR_SOURCE_DIR"
  (
    cd "$PROXY_DOCTOR_SOURCE_DIR"
    tar -cf - .
  ) | (
    cd "$source_dir"
    tar -xf -
  )
else
  say "Downloading $repo@$version"
  fetch_url "$archive_url" "$archive_path"
  tar -xzf "$archive_path" -C "$source_dir" --strip-components=1
fi

if [ ! -f "$source_dir/bin/proxy-doctor" ]; then
  fail "downloaded source is missing bin/proxy-doctor"
fi

if [ ! -f "$source_dir/lib/proxy_doctor/core.sh" ]; then
  fail "downloaded source is missing lib/proxy_doctor/core.sh"
fi

chmod +x "$source_dir/bin/proxy-doctor"

source_version="$("$source_dir/bin/proxy-doctor" version)" || fail "downloaded proxy-doctor failed its version check"
if [ -z "$source_version" ]; then
  fail "downloaded proxy-doctor returned an empty version"
fi

mkdir -p "$(dirname "$install_dir")"
mkdir -p "$bin_dir"

if [ -d "$binary_path" ] && [ ! -L "$binary_path" ]; then
  fail "$binary_path is a directory; set PROXY_DOCTOR_BIN_DIR or remove the directory"
fi

if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
  backup_stamp="$(date +%Y%m%d%H%M%S)"
  backup_dir="$(unique_backup_path "${install_dir}.previous.$backup_stamp")"
  mv "$install_dir" "$backup_dir"
  say "Backed up previous install to $backup_dir"
fi

mv "$source_dir" "$install_dir"
placed_install_dir=1
chmod +x "$install_dir/bin/proxy-doctor"

installed_version="$("$install_dir/bin/proxy-doctor" version)" || fail "installed proxy-doctor failed its version check"
if [ "$installed_version" != "$source_version" ]; then
  fail "installed version mismatch: expected $source_version, got $installed_version"
fi

if [ -e "$binary_path" ] || [ -L "$binary_path" ]; then
  binary_backup="$(unique_backup_path "${binary_path}.previous.$(date +%Y%m%d%H%M%S)")"
  mv "$binary_path" "$binary_backup"
  say "Backed up previous executable to $binary_backup"
fi

ln -s "$install_dir/bin/proxy-doctor" "$binary_path"

install_done=1

say "Installed $binary_path (version $installed_version)"

case ":${PATH:-}:" in
  *":$bin_dir:"*)
    say "Run: proxy-doctor --agent codex doctor --no-probes"
    ;;
  *)
    warn "$bin_dir is not on PATH"
    say "Run now: $binary_path --agent codex doctor --no-probes"
    say "Add to PATH: export PATH=\"$bin_dir:\$PATH\""
    ;;
esac
