#!/usr/bin/env bash

pd_action_status() {
  [ "$#" -eq 0 ] || pd_die "status does not accept flags yet"

  status_code=0
  pd_say "provider=$(pd_adapter_name) capabilities=$(pd_adapter_capabilities)"
  pd_adapter_status || status_code=$?

  if [ -f "$PD_ACTION_LOG" ]; then
    pd_say "recent compact events:"
    tail -n 5 "$PD_ACTION_LOG" | sed 's/^/  /'
  else
    pd_say "recent compact events: <none>"
  fi

  return "$status_code"
}
