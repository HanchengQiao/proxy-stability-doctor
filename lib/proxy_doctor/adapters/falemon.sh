#!/usr/bin/env bash

: "${PD_FALEMON_APP_DIR:=$HOME/Library/Application Support/com.falemon.macos10921}"
: "${PD_FALEMON_HTTP_BIN:=$PD_FALEMON_APP_DIR/falemonhttp}"
: "${PD_FALEMON_LF_BIN:=$PD_FALEMON_APP_DIR/falemonlf}"

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

pd_adapter_status() {
  failures=0
  http_pattern="$PD_FALEMON_HTTP_BIN"
  lf_pattern="$PD_FALEMON_LF_BIN"

  http_count="$(pd_falemon_process_count "$http_pattern")"
  lf_count="$(pd_falemon_process_count "$lf_pattern")"

  if [ "$http_count" -gt 0 ]; then
    pd_say "falemon http process count=$http_count"
  else
    pd_warn "falemon http process not found"
    failures=$((failures + 1))
  fi

  if [ "$lf_count" -gt 0 ]; then
    pd_say "falemon lf process count=$lf_count"
  else
    pd_warn "falemon lf process not found"
    failures=$((failures + 1))
  fi

  if [ -n "${PD_HTTP_PORT:-}" ]; then
    if pd_port_listening "$PD_HTTP_PORT"; then
      pd_say "falemon http port healthy: $PD_HTTP_PORT"
    else
      pd_warn "falemon http port not listening: $PD_HTTP_PORT"
      failures=$((failures + 1))
    fi
  fi

  if [ -n "${PD_SOCKS_PORT:-}" ]; then
    if pd_port_listening "$PD_SOCKS_PORT"; then
      pd_say "falemon socks port healthy: $PD_SOCKS_PORT"
    else
      pd_warn "falemon socks port not listening: $PD_SOCKS_PORT"
      failures=$((failures + 1))
    fi
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

