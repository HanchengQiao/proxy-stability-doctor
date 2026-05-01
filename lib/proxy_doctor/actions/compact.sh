#!/usr/bin/env bash

pd_compact_usage() {
  cat <<'USAGE'
Usage:
  proxy-doctor compact status
  proxy-doctor compact suggest
  proxy-doctor compact observe --result success|failure [--tokens N] [--bytes N] [--source TEXT] [--reason TEXT]
  proxy-doctor compact scan --log-file FILE
USAGE
}

pd_compact_state_value() {
  pd_compact_key="${1:-}"
  [ -f "$PD_COMPACT_STATE" ] || return 1
  sed -n "s/^${pd_compact_key}=//p" "$PD_COMPACT_STATE" | sed -n '1p'
}

pd_action_compact_status() {
  [ "$#" -eq 0 ] || pd_die "compact status does not accept flags"
  pd_compact_recalculate

  pd_compact_tokens="$(pd_compact_state_value suggested_token_limit || true)"
  pd_compact_bytes="$(pd_compact_state_value suggested_byte_limit || true)"
  pd_compact_confidence="$(pd_compact_state_value confidence || true)"
  pd_compact_basis="$(pd_compact_state_value basis || true)"
  pd_compact_observations="$(pd_compact_state_value observations || true)"
  pd_compact_success_count="$(pd_compact_state_value success_count || true)"
  pd_compact_failure_count="$(pd_compact_state_value failure_count || true)"

  pd_say "compact detector agent_profile=${PD_AGENT_PROFILE:-generic} agent_name=${PD_AGENT_NAME:-${PD_AGENT_PROFILE:-generic}}"
  pd_say "observations=${pd_compact_observations:-0} success=${pd_compact_success_count:-0} failure=${pd_compact_failure_count:-0}"
  pd_say "suggested_token_limit=${pd_compact_tokens:-<insufficient>} suggested_byte_limit=${pd_compact_bytes:-<insufficient>}"
  pd_say "confidence=${pd_compact_confidence:-insufficient} basis=${pd_compact_basis:-no_observations}"
  pd_say "state_dir=$PD_STATE_DIR state_source=${PD_STATE_DIR_SOURCE:-unknown}"
  pd_say "scan_max_bytes=${PD_COMPACT_SCAN_MAX_BYTES:-1048576} scan_max_observations=${PD_COMPACT_SCAN_MAX_OBSERVATIONS:-200}"
  pd_say "state=$PD_COMPACT_STATE"
}

pd_action_compact_observe() {
  pd_compact_result=""
  pd_compact_tokens=""
  pd_compact_bytes=""
  pd_compact_source="manual"
  pd_compact_reason="observed"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --result)
        [ "$#" -ge 2 ] || pd_die "missing value for --result"
        pd_compact_result="$2"
        shift 2
        ;;
      --tokens)
        [ "$#" -ge 2 ] || pd_die "missing value for --tokens"
        pd_compact_tokens="$2"
        shift 2
        ;;
      --bytes)
        [ "$#" -ge 2 ] || pd_die "missing value for --bytes"
        pd_compact_bytes="$2"
        shift 2
        ;;
      --source)
        [ "$#" -ge 2 ] || pd_die "missing value for --source"
        pd_compact_source="$2"
        shift 2
        ;;
      --reason)
        [ "$#" -ge 2 ] || pd_die "missing value for --reason"
        pd_compact_reason="$2"
        shift 2
        ;;
      -h|--help)
        pd_compact_usage
        return 0
        ;;
      *)
        pd_die "unknown compact observe flag: $1"
        ;;
    esac
  done

  [ -n "$pd_compact_result" ] || pd_die "compact observe requires --result success|failure"
  pd_compact_observe "$pd_compact_result" "$pd_compact_tokens" "$pd_compact_bytes" "$pd_compact_source" "$pd_compact_reason"
  pd_say "compact observation recorded"
  pd_action_compact_status
}

pd_action_compact_scan() {
  pd_compact_file=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --log-file)
        [ "$#" -ge 2 ] || pd_die "missing value for --log-file"
        pd_compact_file="$2"
        shift 2
        ;;
      -h|--help)
        pd_compact_usage
        return 0
        ;;
      *)
        pd_die "unknown compact scan flag: $1"
        ;;
    esac
  done

  [ -n "$pd_compact_file" ] || pd_die "compact scan requires --log-file FILE"
  pd_compact_imported="$(pd_compact_scan_log "$pd_compact_file")"
  pd_say "compact scan imported observations=$pd_compact_imported max_observations=${PD_COMPACT_SCAN_MAX_OBSERVATIONS:-200}"
  pd_action_compact_status
}

pd_action_compact() {
  subcommand="${1:-status}"
  [ "$#" -eq 0 ] || shift

  case "$subcommand" in
    status|suggest)
      pd_action_compact_status "$@"
      ;;
    observe)
      pd_action_compact_observe "$@"
      ;;
    scan)
      pd_action_compact_scan "$@"
      ;;
    -h|--help)
      pd_compact_usage
      ;;
    *)
      pd_compact_usage >&2
      pd_die "unknown compact subcommand: $subcommand"
      ;;
  esac
}
