#!/usr/bin/env bash

pd_platform_is_darwin() {
  [ "$(uname -s 2>/dev/null || true)" = "Darwin" ]
}

pd_launchctl_env_value() {
  key="${1:-}"
  [ -n "$key" ] || return 1
  pd_platform_is_darwin || return 1
  command -v launchctl >/dev/null 2>&1 || return 1
  launchctl getenv "$key" 2>/dev/null || true
}

pd_print_launchctl_proxy_env() {
  pd_platform_is_darwin || return 0
  for key in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
    value="$(pd_launchctl_env_value "$key")"
    if [ -n "$value" ]; then
      pd_say "launchctl $key=$(pd_redact_url "$value")"
    else
      pd_say "launchctl $key=<unset>"
    fi
  done
}

