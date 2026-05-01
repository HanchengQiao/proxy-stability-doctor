#!/usr/bin/env bash

pd_load_config_file() {
  file="${1:-}"
  [ -n "$file" ] || return 0
  [ -f "$file" ] || pd_die "config file not found: $file"
  # shellcheck source=/dev/null
  . "$file"
}

pd_finalize_config() {
  PD_PROVIDER="${PD_PROVIDER:-custom}"
  PD_AGENT_PROFILE="$(pd_normalize_agent_profile "${PD_AGENT_PROFILE:-generic}")"
  PD_AGENT_NAME="${PD_AGENT_NAME:-$PD_AGENT_PROFILE}"
  PD_HTTP_PROXY="${PD_HTTP_PROXY:-${HTTP_PROXY:-${http_proxy:-}}}"
  PD_SOCKS_PROXY="${PD_SOCKS_PROXY:-${ALL_PROXY:-${all_proxy:-}}}"
  PD_NO_PROXY="${PD_NO_PROXY:-${NO_PROXY:-${no_proxy:-localhost,127.0.0.1,::1,.local}}}"

  if [ -z "${PD_HTTP_PORT:-}" ] && [ -n "$PD_HTTP_PROXY" ]; then
    PD_HTTP_PORT="$(pd_url_port "$PD_HTTP_PROXY" 2>/dev/null || true)"
  fi
  if [ -z "${PD_SOCKS_PORT:-}" ] && [ -n "$PD_SOCKS_PROXY" ]; then
    PD_SOCKS_PORT="$(pd_url_port "$PD_SOCKS_PROXY" 2>/dev/null || true)"
  fi

  if [ -z "${PD_STATE_DIR:-}" ]; then
    if [ -n "${XDG_STATE_HOME:-}" ]; then
      PD_STATE_DIR="$XDG_STATE_HOME/proxy-stability-doctor"
    else
      PD_STATE_DIR="$HOME/.local/state/proxy-stability-doctor"
    fi
  fi

  PD_ACTION_LOG="${PD_ACTION_LOG:-$PD_STATE_DIR/actions.log}"
  PD_COMPACT_OBSERVATION_LOG="${PD_COMPACT_OBSERVATION_LOG:-$PD_STATE_DIR/compact-observations.log}"
  PD_COMPACT_STATE="${PD_COMPACT_STATE:-$PD_STATE_DIR/compact-threshold.state}"
  PD_MAX_LOG_BYTES="${PD_MAX_LOG_BYTES:-262144}"
  PD_MAX_LOG_LINE_BYTES="${PD_MAX_LOG_LINE_BYTES:-2000}"
  PD_PROBE_CONNECT_TIMEOUT="${PD_PROBE_CONNECT_TIMEOUT:-5}"
  PD_PROBE_MAX_TIME="${PD_PROBE_MAX_TIME:-15}"
  PD_RESTART_WAIT_SECONDS="${PD_RESTART_WAIT_SECONDS:-25}"
  PD_COMPACT_FAILURE_MARGIN_PERCENT="${PD_COMPACT_FAILURE_MARGIN_PERCENT:-80}"
  PD_COMPACT_SUCCESS_MARGIN_PERCENT="${PD_COMPACT_SUCCESS_MARGIN_PERCENT:-90}"

  export PD_PROVIDER PD_AGENT_PROFILE PD_AGENT_NAME PD_HTTP_PROXY PD_SOCKS_PROXY PD_NO_PROXY
  export PD_HTTP_PORT PD_SOCKS_PORT PD_STATE_DIR PD_ACTION_LOG
  export PD_COMPACT_OBSERVATION_LOG PD_COMPACT_STATE
  export PD_MAX_LOG_BYTES PD_MAX_LOG_LINE_BYTES
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
