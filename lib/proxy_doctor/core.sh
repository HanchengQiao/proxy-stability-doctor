#!/usr/bin/env bash

pd_now() {
  date '+%Y-%m-%d %H:%M:%S'
}

pd_say() {
  printf '[%s] %s\n' "$(pd_now)" "$*"
}

pd_warn() {
  printf '[%s] WARN: %s\n' "$(pd_now)" "$*" >&2
}

pd_die() {
  printf '[%s] ERROR: %s\n' "$(pd_now)" "$*" >&2
  exit 1
}

pd_is_positive_int() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

pd_redact_url() {
  value="${1:-}"
  case "$value" in
    *://*@*) printf '%s\n' "$value" | sed -E 's#(://)[^/@]+@#\1***@#' ;;
    '') printf '<unset>\n' ;;
    *) printf '%s\n' "$value" ;;
  esac
}

pd_url_port() {
  value="${1:-}"
  [ -n "$value" ] || return 1
  port="$(printf '%s\n' "$value" | sed -nE 's#^[A-Za-z][A-Za-z0-9+.-]*://([^/@]+@)?\[[^]]+\]:([0-9]+)(/.*)?$#\2#p' | sed -n '1p')"
  if [ -z "$port" ]; then
    port="$(printf '%s\n' "$value" | sed -nE 's#^[A-Za-z][A-Za-z0-9+.-]*://([^/@]+@)?[^/:]+:([0-9]+)(/.*)?$#\2#p' | sed -n '1p')"
  fi
  [ -n "$port" ] || return 1
  printf '%s\n' "$port"
}

pd_ensure_state_dir() {
  mkdir -p "$PD_STATE_DIR"
}

pd_trim_file() {
  file="$1"
  max_bytes="$2"
  [ -f "$file" ] || return 0
  size="$(wc -c < "$file" | tr -d ' ')"
  [ "$size" -le "$max_bytes" ] && return 0
  tmp_file="${file}.tmp.$$"
  tail -c "$max_bytes" "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

pd_append_event() {
  pd_ensure_state_dir
  event="${1:-event}"
  detail="${2:-}"
  max_line="${PD_MAX_LOG_LINE_BYTES:-2000}"
  max_file="${PD_MAX_LOG_BYTES:-262144}"
  line="$(printf 'ts=%s event=%s detail=%s' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$event" "$detail")"
  line="$(printf '%s' "$line" | tr '\n' ' ' | cut -c 1-"$max_line")"
  printf '%s\n' "$line" >> "$PD_ACTION_LOG"
  pd_trim_file "$PD_ACTION_LOG" "$max_file"
}

pd_lock_acquire() {
  pd_ensure_state_dir
  PD_LOCK_DIR="${PD_STATE_DIR}/repair.lock"
  if mkdir "$PD_LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" > "${PD_LOCK_DIR}/pid"
    return 0
  fi

  old_pid=""
  [ -f "${PD_LOCK_DIR}/pid" ] && old_pid="$(sed -n '1p' "${PD_LOCK_DIR}/pid" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    pd_warn "another repair appears to be running with pid $old_pid"
    return 1
  fi

  rm -f "${PD_LOCK_DIR}/pid" 2>/dev/null || true
  rmdir "$PD_LOCK_DIR" 2>/dev/null || true
  mkdir "$PD_LOCK_DIR" || return 1
  printf '%s\n' "$$" > "${PD_LOCK_DIR}/pid"
}

pd_lock_release() {
  [ -n "${PD_LOCK_DIR:-}" ] || return 0
  rm -f "${PD_LOCK_DIR}/pid" 2>/dev/null || true
  rmdir "$PD_LOCK_DIR" 2>/dev/null || true
}

pd_port_listening() {
  port="${1:-}"
  pd_is_positive_int "$port" || return 1
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  fi
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1 && return 0
  fi
  return 1
}

pd_process_ids_for_pattern() {
  pattern="${1:-}"
  [ -n "$pattern" ] || return 1
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$pattern" 2>/dev/null && return 0
  fi
  ps -axo pid=,command= | awk -v pattern="$pattern" '$0 ~ pattern {print $1}'
}

pd_status_allowed() {
  status="${1:-}"
  allowed="${2:-}"
  [ -n "$status" ] || return 1
  old_ifs="$IFS"
  IFS=','
  set -- $allowed
  IFS="$old_ifs"
  for candidate in "$@"; do
    candidate="$(printf '%s' "$candidate" | tr -d ' ')"
    [ "$status" = "$candidate" ] && return 0
  done
  return 1
}

pd_http_probe() {
  proxy="${1:-}"
  url="${2:-}"
  [ -n "$proxy" ] || return 2
  [ -n "$url" ] || return 2
  curl -o /dev/null -sS -w '%{http_code} %{time_total} %{remote_ip}' \
    --connect-timeout "${PD_PROBE_CONNECT_TIMEOUT:-5}" \
    --max-time "${PD_PROBE_MAX_TIME:-15}" \
    --proxy "$proxy" \
    "$url"
}

pd_probe_targets() {
  if [ -n "${PD_PROBE_TARGETS_FILE:-}" ] && [ -f "$PD_PROBE_TARGETS_FILE" ]; then
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$PD_PROBE_TARGETS_FILE"
    return 0
  fi

  printf '%s\n' \
    'api.openai.com models|https://api.openai.com/v1/models|200,401,403' \
    'chatgpt.com|https://chatgpt.com/|200,301,302,307,308,403'
}

pd_run_all_probes() {
  if [ "${PD_SKIP_NETWORK_PROBES:-0}" = "1" ]; then
    pd_say "network probes skipped by PD_SKIP_NETWORK_PROBES=1"
    return 0
  fi

  if [ -z "${PD_HTTP_PROXY:-}" ]; then
    pd_warn "PD_HTTP_PROXY is unset; network probes cannot run"
    return 1
  fi

  failures=0
  while IFS='|' read -r label url allowed; do
    [ -n "${url:-}" ] || continue
    result="$(pd_http_probe "$PD_HTTP_PROXY" "$url" 2>/dev/null || true)"
    status="$(printf '%s' "$result" | awk '{print $1}')"
    duration="$(printf '%s' "$result" | awk '{print $2}')"
    remote_ip="$(printf '%s' "$result" | awk '{print $3}')"
    if pd_status_allowed "$status" "$allowed"; then
      pd_say "probe ok label='$label' status=$status time=${duration:-na} remote=${remote_ip:-na}"
      pd_append_event "probe_ok" "label='$label' status=$status"
    else
      pd_warn "probe failed label='$label' status=${status:-none} allowed=$allowed"
      pd_append_event "probe_failed" "label='$label' status=${status:-none} allowed=$allowed"
      failures=$((failures + 1))
    fi
  done <<EOF
$(pd_probe_targets)
EOF

  [ "$failures" -eq 0 ]
}

pd_adapter_function_exists() {
  command -v "$1" >/dev/null 2>&1
}

