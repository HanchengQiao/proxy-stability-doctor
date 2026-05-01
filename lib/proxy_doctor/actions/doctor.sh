#!/usr/bin/env bash

pd_action_doctor() {
  run_probes=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-probes)
        run_probes=0
        shift
        ;;
      *)
        pd_die "unknown doctor flag: $1"
        ;;
    esac
  done

  pd_append_event "doctor_start" "provider=$PD_PROVIDER agent_profile=${PD_AGENT_PROFILE:-generic}"
  pd_say "proxy stability doctor"
  pd_say "provider=$(pd_adapter_name) capabilities=$(pd_adapter_capabilities)"
  pd_say "agent_profile=${PD_AGENT_PROFILE:-generic} agent_name=${PD_AGENT_NAME:-${PD_AGENT_PROFILE:-generic}}"
  pd_say "state_dir=$PD_STATE_DIR state_source=${PD_STATE_DIR_SOURCE:-unknown}"
  pd_say "http_proxy=$(pd_redact_url "$PD_HTTP_PROXY") http_port=${PD_HTTP_PORT:-<unset>}"
  pd_say "socks_proxy=$(pd_redact_url "$PD_SOCKS_PROXY") socks_port=${PD_SOCKS_PORT:-<unset>}"
  pd_say "no_proxy=$PD_NO_PROXY"

  pd_print_launchctl_proxy_env

  if [ -n "${PD_HTTP_PORT:-}" ]; then
    if pd_port_listening "$PD_HTTP_PORT"; then
      pd_say "http port listening: $PD_HTTP_PORT"
    else
      pd_warn "http port not listening: $PD_HTTP_PORT"
    fi
  fi

  if [ -n "${PD_SOCKS_PORT:-}" ]; then
    if pd_port_listening "$PD_SOCKS_PORT"; then
      pd_say "socks port listening: $PD_SOCKS_PORT"
    else
      pd_warn "socks port not listening: $PD_SOCKS_PORT"
    fi
  fi

  if pd_adapter_function_exists pd_adapter_summary; then
    pd_adapter_summary
  fi

  status_ok=0
  pd_adapter_status || status_ok=$?

  probe_ok=0
  if [ "$run_probes" -eq 1 ]; then
    pd_run_all_probes || probe_ok=$?
  fi

  if [ "$status_ok" -eq 0 ] && [ "$probe_ok" -eq 0 ]; then
    pd_append_event "doctor_ok" "provider=$PD_PROVIDER agent_profile=${PD_AGENT_PROFILE:-generic}"
    return 0
  fi

  pd_append_event "doctor_failed" "provider=$PD_PROVIDER agent_profile=${PD_AGENT_PROFILE:-generic} status=$status_ok probes=$probe_ok"
  return 1
}
