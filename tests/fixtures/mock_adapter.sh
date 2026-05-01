#!/usr/bin/env bash

pd_adapter_name() {
  printf 'mock\n'
}

pd_adapter_capabilities() {
  printf 'status,diagnose,restart-command\n'
}

pd_adapter_status() {
  if [ -f "$PD_STATE_DIR/mock_healthy" ]; then
    pd_say "mock adapter healthy"
    return 0
  fi
  pd_warn "mock adapter unhealthy"
  return 1
}

pd_adapter_preflight() {
  return 0
}

pd_adapter_restart() {
  mkdir -p "$PD_STATE_DIR"
  : > "$PD_STATE_DIR/mock_restarted"
  : > "$PD_STATE_DIR/mock_healthy"
  pd_say "mock restart completed"
}

