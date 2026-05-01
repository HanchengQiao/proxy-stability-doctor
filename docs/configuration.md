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
| `PD_HTTP_PROXY` | `HTTP_PROXY` or `http_proxy` | HTTP proxy URL such as `http://127.0.0.1:7890`. |
| `PD_SOCKS_PROXY` | `ALL_PROXY` or `all_proxy` | SOCKS proxy URL such as `socks5h://127.0.0.1:7891`. |
| `PD_HTTP_PORT` | parsed from `PD_HTTP_PROXY` | Explicit local HTTP port. |
| `PD_SOCKS_PORT` | parsed from `PD_SOCKS_PROXY` | Explicit local SOCKS port. |
| `PD_STATE_DIR` | `$XDG_STATE_HOME/proxy-stability-doctor` or `$HOME/.local/state/proxy-stability-doctor` | Compact event log and lock directory. |
| `PD_LOG_MAX_LINES` | `200` | Maximum retained compact event lines. |
| `PD_LOG_MAX_LINE_BYTES` | `600` | Maximum bytes retained per compact event line. |
| `PD_PROBE_TIMEOUT_SECONDS` | `8` | Timeout for outbound probe requests. |
| `PD_PROBE_TARGETS_FILE` | unset | Custom probe target file. |
| `PD_SKIP_NETWORK_PROBES` | unset | Set to `1` to skip outbound network probes. |
| `PD_RESTART_COMMAND` | unset | Trusted local shell command used by adapters that support command-based restart. |

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
http://***:***@127.0.0.1:7890
```

## Probe Targets

Probe files use one target per line:

```text
label|url|allowed_status_codes
```

Example:

```text
api.openai.com models|https://api.openai.com/v1/models|200,401,403
chatgpt.com home|https://chatgpt.com/|200,301,302,307,308,403
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

