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

pd_normalize_agent_profile() {
  pd_agent_profile_normalized="$(printf '%s\n' "${1:-generic}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g;s/^-+//;s/-+$//')"
  if [ -n "$pd_agent_profile_normalized" ]; then
    printf '%s\n' "$pd_agent_profile_normalized"
  else
    printf 'generic\n'
  fi
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

pd_sanitize_compact_field() {
  printf '%s' "${1:-}" | tr '\n\t ' '___' | sed -E 's/[^A-Za-z0-9_.:@%+=,-]/_/g' | cut -c 1-160
}

pd_kv_value() {
  pd_kv_line="${1:-}"
  pd_kv_key="${2:-}"
  printf '%s\n' "$pd_kv_line" | tr ' ' '\n' | sed -n "s/^${pd_kv_key}=//p" | sed -n '1p'
}

pd_percent_of() {
  pd_percent_value="${1:-}"
  pd_percent="${2:-}"
  pd_is_positive_int "$pd_percent_value" || return 1
  pd_is_positive_int "$pd_percent" || return 1
  printf '%s\n' $((pd_percent_value * pd_percent / 100))
}

pd_compact_write_state() {
  pd_ensure_state_dir
  pd_compact_tmp="${PD_COMPACT_STATE}.tmp.$$"
  {
    printf 'updated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'agent_profile=%s\n' "${PD_AGENT_PROFILE:-generic}"
    printf 'observations=%s\n' "${pd_compact_observations:-0}"
    printf 'success_count=%s\n' "${pd_compact_success_count:-0}"
    printf 'failure_count=%s\n' "${pd_compact_failure_count:-0}"
    printf 'success_max_tokens=%s\n' "${pd_compact_success_max_tokens:-}"
    printf 'failure_min_tokens=%s\n' "${pd_compact_failure_min_tokens:-}"
    printf 'success_max_bytes=%s\n' "${pd_compact_success_max_bytes:-}"
    printf 'failure_min_bytes=%s\n' "${pd_compact_failure_min_bytes:-}"
    printf 'suggested_token_limit=%s\n' "${pd_compact_suggested_tokens:-}"
    printf 'suggested_byte_limit=%s\n' "${pd_compact_suggested_bytes:-}"
    printf 'confidence=%s\n' "${pd_compact_confidence:-insufficient}"
    printf 'basis=%s\n' "${pd_compact_basis:-no_observations}"
  } > "$pd_compact_tmp"
  mv "$pd_compact_tmp" "$PD_COMPACT_STATE"
}

pd_compact_recalculate() {
  pd_compact_observations=0
  pd_compact_success_count=0
  pd_compact_failure_count=0
  pd_compact_success_max_tokens=""
  pd_compact_failure_min_tokens=""
  pd_compact_success_max_bytes=""
  pd_compact_failure_min_bytes=""
  pd_compact_suggested_tokens=""
  pd_compact_suggested_bytes=""
  pd_compact_confidence="insufficient"
  pd_compact_basis="no_observations"

  if [ ! -f "${PD_COMPACT_OBSERVATION_LOG:-}" ]; then
    pd_compact_write_state
    return 0
  fi

  while IFS= read -r pd_compact_line; do
    pd_compact_profile="$(pd_kv_value "$pd_compact_line" agent_profile)"
    if [ -n "$pd_compact_profile" ] && [ "$pd_compact_profile" != "${PD_AGENT_PROFILE:-generic}" ]; then
      continue
    fi

    pd_compact_result="$(pd_kv_value "$pd_compact_line" result)"
    pd_compact_tokens="$(pd_kv_value "$pd_compact_line" tokens)"
    pd_compact_bytes="$(pd_kv_value "$pd_compact_line" bytes)"

    case "$pd_compact_result" in
      success|failure) ;;
      *) continue ;;
    esac

    if ! pd_is_positive_int "$pd_compact_tokens" && ! pd_is_positive_int "$pd_compact_bytes"; then
      continue
    fi

    pd_compact_observations=$((pd_compact_observations + 1))

    if [ "$pd_compact_result" = "success" ]; then
      pd_compact_success_count=$((pd_compact_success_count + 1))
      if pd_is_positive_int "$pd_compact_tokens"; then
        if [ -z "$pd_compact_success_max_tokens" ] || [ "$pd_compact_tokens" -gt "$pd_compact_success_max_tokens" ]; then
          pd_compact_success_max_tokens="$pd_compact_tokens"
        fi
      fi
      if pd_is_positive_int "$pd_compact_bytes"; then
        if [ -z "$pd_compact_success_max_bytes" ] || [ "$pd_compact_bytes" -gt "$pd_compact_success_max_bytes" ]; then
          pd_compact_success_max_bytes="$pd_compact_bytes"
        fi
      fi
    else
      pd_compact_failure_count=$((pd_compact_failure_count + 1))
      if pd_is_positive_int "$pd_compact_tokens"; then
        if [ -z "$pd_compact_failure_min_tokens" ] || [ "$pd_compact_tokens" -lt "$pd_compact_failure_min_tokens" ]; then
          pd_compact_failure_min_tokens="$pd_compact_tokens"
        fi
      fi
      if pd_is_positive_int "$pd_compact_bytes"; then
        if [ -z "$pd_compact_failure_min_bytes" ] || [ "$pd_compact_bytes" -lt "$pd_compact_failure_min_bytes" ]; then
          pd_compact_failure_min_bytes="$pd_compact_bytes"
        fi
      fi
    fi
  done < "$PD_COMPACT_OBSERVATION_LOG"

  if pd_is_positive_int "$pd_compact_failure_min_tokens"; then
    pd_compact_suggested_tokens="$(pd_percent_of "$pd_compact_failure_min_tokens" "${PD_COMPACT_FAILURE_MARGIN_PERCENT:-80}")"
    pd_compact_basis="below_observed_failure"
  elif pd_is_positive_int "$pd_compact_success_max_tokens"; then
    pd_compact_suggested_tokens="$(pd_percent_of "$pd_compact_success_max_tokens" "${PD_COMPACT_SUCCESS_MARGIN_PERCENT:-90}")"
    pd_compact_basis="below_observed_success"
  fi

  if pd_is_positive_int "$pd_compact_failure_min_bytes"; then
    pd_compact_suggested_bytes="$(pd_percent_of "$pd_compact_failure_min_bytes" "${PD_COMPACT_FAILURE_MARGIN_PERCENT:-80}")"
    [ "$pd_compact_basis" = "no_observations" ] && pd_compact_basis="below_observed_failure"
  elif pd_is_positive_int "$pd_compact_success_max_bytes"; then
    pd_compact_suggested_bytes="$(pd_percent_of "$pd_compact_success_max_bytes" "${PD_COMPACT_SUCCESS_MARGIN_PERCENT:-90}")"
    [ "$pd_compact_basis" = "no_observations" ] && pd_compact_basis="below_observed_success"
  fi

  if [ "$pd_compact_failure_count" -ge 2 ]; then
    pd_compact_confidence="high"
  elif [ "$pd_compact_failure_count" -eq 1 ]; then
    pd_compact_confidence="medium"
  elif [ "$pd_compact_success_count" -gt 0 ]; then
    pd_compact_confidence="low"
  fi

  pd_compact_write_state
}

pd_compact_observe() {
  pd_compact_result="${1:-}"
  pd_compact_tokens="${2:-}"
  pd_compact_bytes="${3:-}"
  pd_compact_source="$(pd_sanitize_compact_field "${4:-manual}")"
  pd_compact_reason="$(pd_sanitize_compact_field "${5:-observed}")"

  case "$pd_compact_result" in
    success|failure) ;;
    *) pd_die "compact result must be success or failure" ;;
  esac

  if ! pd_is_positive_int "$pd_compact_tokens" && ! pd_is_positive_int "$pd_compact_bytes"; then
    pd_die "compact observation needs --tokens or --bytes"
  fi

  pd_ensure_state_dir
  pd_compact_line="$(printf 'ts=%s agent_profile=%s result=%s tokens=%s bytes=%s source=%s reason=%s' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "${PD_AGENT_PROFILE:-generic}" \
    "$pd_compact_result" \
    "$pd_compact_tokens" \
    "$pd_compact_bytes" \
    "$pd_compact_source" \
    "$pd_compact_reason")"
  printf '%s\n' "$pd_compact_line" >> "$PD_COMPACT_OBSERVATION_LOG"
  pd_trim_file "$PD_COMPACT_OBSERVATION_LOG" "${PD_MAX_LOG_BYTES:-262144}"
  pd_compact_recalculate
}

pd_compact_result_from_line() {
  pd_compact_line="${1:-}"
  pd_compact_result="$(printf '%s\n' "$pd_compact_line" | sed -nE 's/.*(^|[[:space:]])result=(success|failure)([[:space:]]|$).*/\2/p' | sed -n '1p')"
  if [ -n "$pd_compact_result" ]; then
    printf '%s\n' "$pd_compact_result"
    return 0
  fi
  if printf '%s\n' "$pd_compact_line" | grep -Eiq 'fail|error|timeout|disconnect|too large|exceed'; then
    printf 'failure\n'
    return 0
  fi
  if printf '%s\n' "$pd_compact_line" | grep -Eiq 'success|succeeded|complete|completed|ok'; then
    printf 'success\n'
    return 0
  fi
  return 1
}

pd_compact_scan_log() {
  pd_compact_file="${1:-}"
  [ -f "$pd_compact_file" ] || pd_die "compact log file not found: $pd_compact_file"
  pd_compact_count=0
  pd_compact_source="scan:$(basename "$pd_compact_file")"

  while IFS= read -r pd_compact_line; do
    printf '%s\n' "$pd_compact_line" | grep -Eiq 'compact|compaction|context' || continue
    pd_compact_result="$(pd_compact_result_from_line "$pd_compact_line" || true)"
    [ -n "$pd_compact_result" ] || continue
    pd_compact_tokens="$(printf '%s\n' "$pd_compact_line" | sed -nE 's/.*(last_api_response_total_tokens|compact_tokens|total_tokens|tokens)=([0-9]+).*/\2/p' | sed -n '1p')"
    pd_compact_bytes="$(printf '%s\n' "$pd_compact_line" | sed -nE 's/.*(failing_compaction_request_model_visible_bytes|compact_bytes|model_visible_bytes|visible_bytes)=([0-9]+).*/\2/p' | sed -n '1p')"
    if ! pd_is_positive_int "$pd_compact_tokens" && ! pd_is_positive_int "$pd_compact_bytes"; then
      continue
    fi
    pd_compact_observe "$pd_compact_result" "$pd_compact_tokens" "$pd_compact_bytes" "$pd_compact_source" "scanned_log"
    pd_compact_count=$((pd_compact_count + 1))
  done < "$pd_compact_file"

  printf '%s\n' "$pd_compact_count"
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

  case "$(pd_normalize_agent_profile "${PD_AGENT_PROFILE:-generic}")" in
    codex|openai)
      printf '%s\n' \
        'openai models|https://api.openai.com/v1/models|200,401,403' \
        'chatgpt home|https://chatgpt.com/|200,301,302,307,308,403'
      ;;
    claude|claude-code|claudecode|anthropic)
      printf '%s\n' \
        'anthropic messages|https://api.anthropic.com/v1/messages|200,401,403,404,405' \
        'claude home|https://claude.ai/|200,301,302,307,308,403'
      ;;
    custom|generic|*)
      printf '%s\n' \
        'example.com|https://example.com/|200'
      ;;
  esac
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
