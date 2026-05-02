#!/usr/bin/env bash

pd_action_status() {
  [ "$#" -eq 0 ] || pd_die "status does not accept flags yet"

  status_code=0
  pd_say "provider=$(pd_adapter_name) capabilities=$(pd_adapter_capabilities)"
  pd_say "agent_profile=${PD_AGENT_PROFILE:-generic} agent_name=${PD_AGENT_NAME:-${PD_AGENT_PROFILE:-generic}}"
  pd_say "state_dir=$PD_STATE_DIR state_source=${PD_STATE_DIR_SOURCE:-unknown}"
  pd_say "tools curl=$(pd_command_state curl) port_probe_tools=$(pd_port_probe_tool_names)"
  pd_adapter_status || status_code=$?

  if [ -f "$PD_ACTION_LOG" ]; then
    pd_say "recent bounded events:"
    tail -n 5 "$PD_ACTION_LOG" | sed 's/^/  /'
  else
    pd_say "recent bounded events: <none>"
  fi

  return "$status_code"
}
