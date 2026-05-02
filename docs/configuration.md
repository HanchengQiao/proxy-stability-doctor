# Configuration

Proxy Stability Doctor reads configuration from environment variables and, optionally, a shell-style file passed with `--config FILE`.

```bash
proxy-doctor --config .env doctor
```

Configuration files are trusted local input. Do not use untrusted files, because shell syntax is sourced by the CLI.

## Core Variables

| Variable | Default | Description |
| --- | --- | --- |
| `PD_PROVIDER` | `custom` | Adapter name from `lib/proxy_doctor/adapters/`. |
| `PD_ADAPTER_PATH` | unset | Absolute or relative path to an external adapter file. Takes precedence over `PD_PROVIDER`. |
| `PD_AGENT_PROFILE` | `generic` | Agent workflow profile used for built-in probes and learned compact thresholds. Built-ins include `generic`, `codex`, `claude-code`, and `custom`; common aliases are normalized. |
| `PD_AGENT_NAME` | `PD_AGENT_PROFILE` | Optional display name for local reporting. |
| `PD_HTTP_PROXY` | `HTTP_PROXY` or `http_proxy` | HTTP proxy URL such as `http://127.0.0.1:7890`. |
| `PD_SOCKS_PROXY` | `ALL_PROXY` or `all_proxy` | SOCKS proxy URL such as `socks5h://127.0.0.1:7891`. |
| `PD_HTTP_PORT` | parsed from `PD_HTTP_PROXY` | Explicit local HTTP port. |
| `PD_SOCKS_PORT` | parsed from `PD_SOCKS_PROXY` | Explicit local SOCKS port. |
| `PD_STATE_DIR` | first writable state path | State, event log, learned compact state, and lock directory. |
| `PD_ACTION_LOG` | `$PD_STATE_DIR/actions.log` | Bounded action event log path. |
| `PD_COMPACT_OBSERVATION_LOG` | `$PD_STATE_DIR/compact-observations.log` | Bounded compact observation log path. |
| `PD_COMPACT_STATE` | `$PD_STATE_DIR/compact-threshold.state` | Current learned compact-threshold suggestion state. |
| `PD_MAX_LOG_BYTES` | `262144` | Maximum retained bytes for bounded logs. |
| `PD_MAX_LOG_LINE_BYTES` | `2000` | Maximum bytes retained per event or observation line. |
| `PD_COMPACT_SCAN_MAX_BYTES` | `1048576` | Maximum bytes read from the tail of a local log during `compact scan`. |
| `PD_COMPACT_SCAN_MAX_OBSERVATIONS` | `200` | Maximum compact observations imported in one `compact scan` run. |
| `PD_PROBE_CONNECT_TIMEOUT` | `5` | Curl connect timeout for outbound probe requests. |
| `PD_PROBE_MAX_TIME` | `15` | Curl total timeout for outbound probe requests. |
| `PD_PROBE_TARGETS_FILE` | unset | Custom probe target file. |
| `PD_SKIP_NETWORK_PROBES` | unset | Set to `1` to skip outbound network probes. |
| `PD_RESTART_COMMAND` | unset | Trusted local shell command used by adapters that support command-based restart. |
| `PD_RESTART_WAIT_SECONDS` | `25` | Maximum wait time for post-restart health verification. |
| `PD_COMPACT_FAILURE_MARGIN_PERCENT` | `80` | Suggested compact limit as a percentage below the lowest observed failure. |
| `PD_COMPACT_SUCCESS_MARGIN_PERCENT` | `90` | Low-confidence suggested compact limit as a percentage below the highest observed success when no failures exist yet. |

## Runtime Tool Availability

Proxy Stability Doctor stays usable when optional system tools are missing, but it reports the limitation explicitly:

- `curl` is required for outbound probes. If it is missing, probe commands fail with a clear tool warning. Use `doctor --no-probes` or `repair --no-probes` for local-only diagnostics.
- `lsof` or `nc` is required for local port checks. If both are missing, port health is reported as unknown and adapters can fail or warn depending on the configured health signals.
- `pgrep` is preferred for process discovery; `ps` is used as a fallback when available.

## State Directory Selection

If `PD_STATE_DIR` is set explicitly, Proxy Stability Doctor treats it as a strict user choice and fails when the path cannot be created or written.

If `PD_STATE_DIR` is not set, the CLI selects the first writable path from:

1. `$XDG_STATE_HOME/proxy-stability-doctor`
2. `$HOME/.local/state/proxy-stability-doctor`
3. `$TMPDIR/proxy-stability-doctor-$UID`

The temporary fallback keeps diagnostics usable in restricted environments, but persistent installs should set a stable `PD_STATE_DIR`.

## Proxy URL Examples

```bash
PD_HTTP_PROXY=http://127.0.0.1:7890
PD_SOCKS_PROXY=socks5h://127.0.0.1:7891
```

Proxy credentials are redacted in CLI output:

```bash
PD_HTTP_PROXY=http://user:password@127.0.0.1:7890
```

prints as:

```text
http://***@127.0.0.1:7890
```

## Agent Profiles

`PD_AGENT_PROFILE` chooses built-in outbound probes and keeps learned compact thresholds isolated by agent workflow.

```bash
proxy-doctor --config .env --agent codex doctor
proxy-doctor --config .env --agent claude-code doctor
```

Built-in profiles:

- `generic`: probes `https://example.com/`.
- `codex`: probes OpenAI API and ChatGPT reachability. Aliases include `openai`, `chatgpt`, `codex-cli`, and `openai-codex`.
- `claude-code`: probes Anthropic API and Claude reachability. Aliases include `claude`, `claudecode`, and `anthropic`.
- `custom`: uses the generic fallback unless `PD_PROBE_TARGETS_FILE` is set.

Use `PD_PROBE_TARGETS_FILE` when a team needs a different or private target set.

## Probe Targets

Probe files use one target per line:

```text
label|url|allowed_status_codes
```

Example:

```text
api.openai.com models|https://api.openai.com/v1/models|200,401,403
chatgpt.com home|https://chatgpt.com/|200,301,302,307,308,403
anthropic messages|https://api.anthropic.com/v1/messages|200,401,403,404,405
claude home|https://claude.ai/|200,301,302,307,308,403
example.com|https://example.com/|200
```

Status codes such as `401` and `403` can be acceptable for authenticated endpoints when the goal is to prove that the proxy can reach the service and receive a controlled response.

## Generic Custom Adapter

Use `custom` for any provider where port checks and optional command-based restart are enough.

```bash
PD_PROVIDER=custom
PD_HTTP_PROXY=http://127.0.0.1:7890
PD_SOCKS_PROXY=socks5h://127.0.0.1:7891
```

For guarded restart, add a trusted command:

```bash
PD_RESTART_COMMAND='launchctl kickstart -k "gui/$(id -u)/com.example.proxy"'
```

The command is never executed by `repair` unless both `--allow-restart` and `--apply` are passed.

## Falemon Adapter

The `falemon` adapter is diagnostic by default. It reports process and port health but does not kill Falemon processes.

```bash
PD_PROVIDER=falemon
PD_HTTP_PROXY=http://127.0.0.1:10792
PD_SOCKS_PROXY=socks5h://127.0.0.1:10793
PD_HTTP_PORT=10792
PD_SOCKS_PORT=10793
```

Only add `PD_RESTART_COMMAND` if you have a safe provider-owned restart interface and have tested it locally.

Falemon process checks are configurable because installed paths and process names can differ:

```bash
PD_FALEMON_REQUIRE_PROCESSES=1
PD_FALEMON_CHECK_HTTP_PROCESS=1
PD_FALEMON_CHECK_LF_PROCESS=1
PD_FALEMON_HTTP_PATTERN="$PD_FALEMON_HTTP_BIN"
PD_FALEMON_LF_PATTERN="$PD_FALEMON_LF_BIN"
```

Required process checks and configured ports are treated as hard health signals. If process checks are disabled and no ports are configured, the adapter fails instead of reporting a false healthy state.

## Compact Threshold Detector

The compact detector does not ship a fixed token threshold. It learns a per-agent suggestion from observed compact results:

```bash
proxy-doctor --config .env --agent codex compact observe --result success --tokens 40000 --bytes 160000
proxy-doctor --config .env --agent codex compact observe --result failure --tokens 50000 --bytes 200000
proxy-doctor --config .env --agent codex compact status
```

If failures exist, the suggestion is below the lowest observed failure using `PD_COMPACT_FAILURE_MARGIN_PERCENT`. If only successes exist, the suggestion is below the highest observed success using `PD_COMPACT_SUCCESS_MARGIN_PERCENT` and is marked low confidence.

`compact scan --log-file FILE` can import bounded metrics from local logs. It recognizes key/value records such as `result=failure last_api_response_total_tokens=62500` and JSON/colon-style records such as `"result":"failure"` or `"last_api_response_total_tokens":62500`. It stores compact observations, not raw log lines. By default it scans only the last `1048576` bytes of the file and imports at most `200` observations per run. Tune `PD_COMPACT_SCAN_MAX_BYTES` and `PD_COMPACT_SCAN_MAX_OBSERVATIONS` for larger or smaller local logs.
