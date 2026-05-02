#!/usr/bin/env bash

pd_adapter_name() {
  printf 'custom\n'
}

pd_adapter_capabilities() {
  if [ -n "${PD_RESTART_COMMAND:-}" ]; then
    printf 'status,diagnose,restart-command\n'
  else
    printf 'status,diagnose\n'
  fi
}

pd_adapter_summary() {
  if [ -n "${PD_RESTART_COMMAND:-}" ]; then
    pd_say "custom restart command configured"
  else
    pd_say "custom restart command not configured; repair will be diagnostic-only"
  fi
}

pd_adapter_status() {
  failures=0

  if [ -n "${PD_HTTP_PORT:-}" ]; then
    if ! pd_port_probe_tools_available; then
      pd_warn "custom http port health unknown: install lsof or nc for local port checks"
      failures=$((failures + 1))
    elif pd_port_listening "$PD_HTTP_PORT"; then
      pd_say "custom http port healthy: $PD_HTTP_PORT"
    else
      pd_warn "custom http port not listening: $PD_HTTP_PORT"
      failures=$((failures + 1))
    fi
  elif [ -n "${PD_HTTP_PROXY:-}" ]; then
    pd_warn "custom http proxy set but port could not be inferred"
    failures=$((failures + 1))
  fi

  if [ -n "${PD_SOCKS_PORT:-}" ]; then
    if ! pd_port_probe_tools_available; then
      pd_warn "custom socks port health unknown: install lsof or nc for local port checks"
      failures=$((failures + 1))
    elif pd_port_listening "$PD_SOCKS_PORT"; then
      pd_say "custom socks port healthy: $PD_SOCKS_PORT"
    else
      pd_warn "custom socks port not listening: $PD_SOCKS_PORT"
      failures=$((failures + 1))
    fi
  elif [ -n "${PD_SOCKS_PROXY:-}" ]; then
    pd_warn "custom socks proxy set but port could not be inferred"
    failures=$((failures + 1))
  fi

  if [ -z "${PD_HTTP_PORT:-}" ] && [ -z "${PD_SOCKS_PORT:-}" ]; then
    pd_warn "no proxy ports configured"
    failures=$((failures + 1))
  fi

  [ "$failures" -eq 0 ]
}

pd_adapter_preflight() {
  if [ -z "${PD_RESTART_COMMAND:-}" ]; then
    pd_warn "PD_RESTART_COMMAND is unset"
    return 1
  fi
  return 0
}

pd_adapter_restart() {
  pd_adapter_preflight || return 1
  bash -lc "$PD_RESTART_COMMAND"
}
