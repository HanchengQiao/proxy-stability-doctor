#!/usr/bin/env bash

pd_repair_health_check() {
  pd_adapter_status >/dev/null 2>&1 || return 1
  pd_run_all_probes >/dev/null 2>&1 || return 1
}

pd_wait_for_repair_health() {
  deadline=$(( $(date +%s) + PD_RESTART_WAIT_SECONDS ))
  while [ "$(date +%s)" -le "$deadline" ]; do
    if pd_repair_health_check; then
      return 0
    fi
    sleep 1
  done
  return 1
}

pd_action_repair() {
  allow_restart=0
  apply=0
  force=0
  skip_network_probes=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --allow-restart)
        allow_restart=1
        shift
        ;;
      --apply)
        apply=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      --no-probes)
        skip_network_probes=1
        PD_SKIP_NETWORK_PROBES=1
        export PD_SKIP_NETWORK_PROBES
        shift
        ;;
      --dry-run)
        apply=0
        shift
        ;;
      *)
        pd_die "unknown repair flag: $1"
        ;;
    esac
  done

  pd_lock_acquire || pd_die "could not acquire repair lock"
  trap pd_lock_release EXIT INT TERM

  pd_append_event "repair_start" "provider=$PD_PROVIDER allow_restart=$allow_restart apply=$apply force=$force skip_network_probes=$skip_network_probes"

  if [ "$force" -eq 0 ] && pd_repair_health_check; then
    pd_say "current health is good; repair skipped"
    pd_append_event "repair_skipped_healthy" "provider=$PD_PROVIDER"
    return 0
  fi

  if [ "$allow_restart" -ne 1 ] || [ "$apply" -ne 1 ]; then
    pd_say "repair dry-run: diagnostics completed, restart not applied"
    pd_say "pass --allow-restart --apply to permit adapter restart after preflight"
    pd_adapter_status || true
    pd_append_event "repair_dry_run" "provider=$PD_PROVIDER"
    return 0
  fi

  if ! pd_adapter_preflight; then
    pd_warn "adapter has no safe restart path or preflight failed; diagnostic fallback only"
    pd_adapter_status || true
    pd_append_event "repair_fallback_diagnostic" "provider=$PD_PROVIDER"
    return 0
  fi

  pd_say "adapter preflight passed; running restart"
  pd_adapter_restart
  pd_append_event "restart_invoked" "provider=$PD_PROVIDER"

  if pd_wait_for_repair_health; then
    pd_say "repair verified: service healthy after restart"
    pd_append_event "repair_verified" "provider=$PD_PROVIDER"
    return 0
  fi

  pd_warn "restart was invoked but health verification did not pass"
  pd_append_event "repair_verify_failed" "provider=$PD_PROVIDER"
  return 1
}
