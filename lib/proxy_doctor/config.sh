#!/usr/bin/env bash

pd_load_config_file() {
  file="${1:-}"
  [ -n "$file" ] || return 0
  [ -f "$file" ] || pd_die "config file not found: $file"
  # shellcheck source=/dev/null
  . "$file"
}

pd_state_dir_candidate_usable() {
  pd_state_dir_candidate="${1:-}"
  [ -n "$pd_state_dir_candidate" ] || return 1
  mkdir -p "$pd_state_dir_candidate" 2>/dev/null || return 1
  [ -d "$pd_state_dir_candidate" ] && [ -w "$pd_state_dir_candidate" ]
}

pd_select_default_state_dir() {
  if [ -n "${XDG_STATE_HOME:-}" ]; then
    pd_state_dir_candidate="$XDG_STATE_HOME/proxy-stability-doctor"
    if pd_state_dir_candidate_usable "$pd_state_dir_candidate"; then
      PD_STATE_DIR="$pd_state_dir_candidate"
      PD_STATE_DIR_SOURCE="xdg"
      return 0
    fi
  fi

  if [ -n "${HOME:-}" ]; then
    pd_state_dir_candidate="$HOME/.local/state/proxy-stability-doctor"
    if pd_state_dir_candidate_usable "$pd_state_dir_candidate"; then
      PD_STATE_DIR="$pd_state_dir_candidate"
      PD_STATE_DIR_SOURCE="home"
      return 0
    fi
  fi

  pd_state_dir_tmp_root="${TMPDIR:-/tmp}"
  pd_state_dir_uid="${UID:-}"
  if [ -z "$pd_state_dir_uid" ]; then
    pd_state_dir_uid="$(id -u 2>/dev/null || printf 'user')"
  fi
  pd_state_dir_candidate="$pd_state_dir_tmp_root/proxy-stability-doctor-$pd_state_dir_uid"
  if pd_state_dir_candidate_usable "$pd_state_dir_candidate"; then
    PD_STATE_DIR="$pd_state_dir_candidate"
    PD_STATE_DIR_SOURCE="temporary_fallback"
    return 0
  fi

  pd_die "could not create a writable default state directory; set PD_STATE_DIR"
}

pd_finalize_config() {
  PD_PROVIDER="$(pd_normalize_provider_name "${PD_PROVIDER:-custom}")"
  PD_AGENT_PROFILE="$(pd_normalize_agent_profile "${PD_AGENT_PROFILE:-generic}")"
  PD_AGENT_NAME="${PD_AGENT_NAME:-$PD_AGENT_PROFILE}"
  PD_HTTP_PROXY="${PD_HTTP_PROXY:-${HTTP_PROXY:-${http_proxy:-}}}"
  PD_SOCKS_PROXY="${PD_SOCKS_PROXY:-${ALL_PROXY:-${all_proxy:-}}}"
  PD_NO_PROXY="${PD_NO_PROXY:-${NO_PROXY:-${no_proxy:-localhost,127.0.0.1,::1,.local}}}"

  pd_config_port_or_empty PD_HTTP_PORT
  pd_config_port_or_empty PD_SOCKS_PORT

  if [ -z "${PD_HTTP_PORT:-}" ] && [ -n "$PD_HTTP_PROXY" ]; then
    PD_HTTP_PORT="$(pd_url_port "$PD_HTTP_PROXY" 2>/dev/null || true)"
    pd_config_port_or_empty PD_HTTP_PORT
  fi
  if [ -z "${PD_SOCKS_PORT:-}" ] && [ -n "$PD_SOCKS_PROXY" ]; then
    PD_SOCKS_PORT="$(pd_url_port "$PD_SOCKS_PROXY" 2>/dev/null || true)"
    pd_config_port_or_empty PD_SOCKS_PORT
  fi

  if [ -z "${PD_STATE_DIR:-}" ]; then
    pd_select_default_state_dir
  else
    PD_STATE_DIR_SOURCE="${PD_STATE_DIR_SOURCE:-explicit}"
  fi

  PD_ACTION_LOG="${PD_ACTION_LOG:-$PD_STATE_DIR/actions.log}"
  PD_COMPACT_OBSERVATION_LOG="${PD_COMPACT_OBSERVATION_LOG:-$PD_STATE_DIR/compact-observations.log}"
  PD_COMPACT_STATE="${PD_COMPACT_STATE:-$PD_STATE_DIR/compact-threshold.state}"
  PD_MAX_LOG_BYTES="${PD_MAX_LOG_BYTES:-262144}"
  PD_MAX_LOG_LINE_BYTES="${PD_MAX_LOG_LINE_BYTES:-2000}"
  PD_COMPACT_SCAN_MAX_BYTES="${PD_COMPACT_SCAN_MAX_BYTES:-1048576}"
  PD_COMPACT_SCAN_MAX_OBSERVATIONS="${PD_COMPACT_SCAN_MAX_OBSERVATIONS:-200}"
  PD_PROBE_CONNECT_TIMEOUT="${PD_PROBE_CONNECT_TIMEOUT:-5}"
  PD_PROBE_MAX_TIME="${PD_PROBE_MAX_TIME:-15}"
  PD_RESTART_WAIT_SECONDS="${PD_RESTART_WAIT_SECONDS:-25}"
  PD_COMPACT_FAILURE_MARGIN_PERCENT="${PD_COMPACT_FAILURE_MARGIN_PERCENT:-80}"
  PD_COMPACT_SUCCESS_MARGIN_PERCENT="${PD_COMPACT_SUCCESS_MARGIN_PERCENT:-90}"

  pd_config_positive_int_default PD_MAX_LOG_BYTES 262144
  pd_config_positive_int_default PD_MAX_LOG_LINE_BYTES 2000
  pd_config_positive_int_default PD_COMPACT_SCAN_MAX_BYTES 1048576
  pd_config_positive_int_default PD_COMPACT_SCAN_MAX_OBSERVATIONS 200
  pd_config_positive_int_default PD_PROBE_CONNECT_TIMEOUT 5
  pd_config_positive_int_default PD_PROBE_MAX_TIME 15
  pd_config_positive_int_default PD_RESTART_WAIT_SECONDS 25
  pd_config_positive_int_default PD_COMPACT_FAILURE_MARGIN_PERCENT 80
  pd_config_positive_int_default PD_COMPACT_SUCCESS_MARGIN_PERCENT 90

  export PD_PROVIDER PD_AGENT_PROFILE PD_AGENT_NAME PD_HTTP_PROXY PD_SOCKS_PROXY PD_NO_PROXY
  export PD_HTTP_PORT PD_SOCKS_PORT PD_STATE_DIR PD_STATE_DIR_SOURCE PD_ACTION_LOG
  export PD_COMPACT_OBSERVATION_LOG PD_COMPACT_STATE
  export PD_MAX_LOG_BYTES PD_MAX_LOG_LINE_BYTES PD_COMPACT_SCAN_MAX_BYTES PD_COMPACT_SCAN_MAX_OBSERVATIONS
  export PD_PROBE_CONNECT_TIMEOUT PD_PROBE_MAX_TIME PD_RESTART_WAIT_SECONDS
  export PD_COMPACT_FAILURE_MARGIN_PERCENT PD_COMPACT_SUCCESS_MARGIN_PERCENT
}

pd_load_adapter() {
  if [ -n "${PD_ADAPTER_PATH:-}" ]; then
    adapter_path="$PD_ADAPTER_PATH"
  else
    adapter_path="$PD_LIB_DIR/adapters/${PD_PROVIDER}.sh"
  fi

  [ -f "$adapter_path" ] || pd_die "adapter not found: $adapter_path"
  # shellcheck source=/dev/null
  . "$adapter_path"

  for required in pd_adapter_name pd_adapter_capabilities pd_adapter_status pd_adapter_preflight pd_adapter_restart; do
    pd_adapter_function_exists "$required" || pd_die "adapter missing required function: $required"
  done
}
