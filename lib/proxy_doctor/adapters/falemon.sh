#!/usr/bin/env bash

: "${PD_FALEMON_APP_DIR:=$HOME/Library/Application Support/com.falemon.macos10921}"
: "${PD_FALEMON_HTTP_BIN:=$PD_FALEMON_APP_DIR/falemonhttp}"
: "${PD_FALEMON_LF_BIN:=$PD_FALEMON_APP_DIR/falemonlf}"
: "${PD_FALEMON_REQUIRE_PROCESSES:=1}"
: "${PD_FALEMON_CHECK_HTTP_PROCESS:=1}"
: "${PD_FALEMON_CHECK_LF_PROCESS:=1}"
: "${PD_FALEMON_HTTP_PATTERN:=$PD_FALEMON_HTTP_BIN}"
: "${PD_FALEMON_LF_PATTERN:=$PD_FALEMON_LF_BIN}"

pd_adapter_name() {
  printf 'falemon\n'
}

pd_adapter_capabilities() {
  if [ -n "${PD_RESTART_COMMAND:-}" ]; then
    printf 'status,diagnose,restart-command\n'
  else
    printf 'status,diagnose\n'
  fi
}

pd_adapter_summary() {
  pd_say "falemon app dir=$PD_FALEMON_APP_DIR"
  pd_say "falemon http bin=$PD_FALEMON_HTTP_BIN"
  pd_say "falemon lf bin=$PD_FALEMON_LF_BIN"
  pd_say "falemon process checks require=$PD_FALEMON_REQUIRE_PROCESSES http=$PD_FALEMON_CHECK_HTTP_PROCESS lf=$PD_FALEMON_CHECK_LF_PROCESS"
  if [ -n "${PD_RESTART_COMMAND:-}" ]; then
    pd_say "falemon restart command configured"
  else
    pd_say "falemon restart command not configured; repair will be diagnostic-only"
  fi
}

pd_falemon_process_count() {
  pattern="$1"
  pd_process_ids_for_pattern "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

pd_falemon_process_status() {
  label="$1"
  pattern="$2"
  count="$(pd_falemon_process_count "$pattern")"
  if [ "$count" -gt 0 ]; then
    pd_say "falemon $label process count=$count"
    return 0
  fi

  if [ "${PD_FALEMON_REQUIRE_PROCESSES:-1}" = "1" ]; then
    pd_warn "falemon $label process not found"
    return 1
  fi

  pd_warn "falemon $label process not found; process check is advisory"
  return 0
}

pd_falemon_port_status() {
  label="$1"
  port="$2"
  if ! pd_port_probe_tools_available; then
    pd_warn "falemon $label port health unknown: install lsof or nc for local port checks"
    return 1
  fi
  if pd_port_listening "$port"; then
    pd_say "falemon $label port healthy: $port"
    return 0
  fi
  pd_warn "falemon $label port not listening: $port"
  return 1
}

pd_adapter_status() {
  failures=0
  hard_signals=0

  if [ "${PD_FALEMON_CHECK_HTTP_PROCESS:-1}" = "1" ]; then
    if [ "${PD_FALEMON_REQUIRE_PROCESSES:-1}" = "1" ]; then
      hard_signals=$((hard_signals + 1))
    fi
    pd_falemon_process_status "http" "$PD_FALEMON_HTTP_PATTERN" || failures=$((failures + 1))
  fi

  if [ "${PD_FALEMON_CHECK_LF_PROCESS:-1}" = "1" ]; then
    if [ "${PD_FALEMON_REQUIRE_PROCESSES:-1}" = "1" ]; then
      hard_signals=$((hard_signals + 1))
    fi
    pd_falemon_process_status "lf" "$PD_FALEMON_LF_PATTERN" || failures=$((failures + 1))
  fi

  if [ -n "${PD_HTTP_PORT:-}" ]; then
    hard_signals=$((hard_signals + 1))
    pd_falemon_port_status "http" "$PD_HTTP_PORT" || failures=$((failures + 1))
  fi

  if [ -n "${PD_SOCKS_PORT:-}" ]; then
    hard_signals=$((hard_signals + 1))
    pd_falemon_port_status "socks" "$PD_SOCKS_PORT" || failures=$((failures + 1))
  fi

  if [ -z "${PD_HTTP_PORT:-}" ] && [ -z "${PD_SOCKS_PORT:-}" ]; then
    pd_warn "no falemon proxy ports configured"
  fi

  if [ "$hard_signals" -eq 0 ]; then
    pd_warn "no required falemon health signal configured; enable required process checks or configure proxy ports"
    failures=$((failures + 1))
  fi

  [ "$failures" -eq 0 ]
}

pd_adapter_preflight() {
  if [ -z "${PD_RESTART_COMMAND:-}" ]; then
    pd_warn "PD_RESTART_COMMAND is unset; Falemon repair is diagnostic-only"
    return 1
  fi
  return 0
}

pd_adapter_restart() {
  pd_adapter_preflight || return 1
  bash -lc "$PD_RESTART_COMMAND"
}
