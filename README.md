# Proxy Stability Doctor

[![CI](https://github.com/HanchengQiao/proxy-stability-doctor/actions/workflows/ci.yml/badge.svg)](https://github.com/HanchengQiao/proxy-stability-doctor/actions/workflows/ci.yml)

Proxy Stability Doctor is an adapter-first CLI for diagnosing local HTTP/SOCKS proxy health for coding agents, browsers, API clients, and other developer workflows. It runs guarded repair flows only when a provider exposes a safe restart surface.

It started as a stability script for one local setup, but the open-source version treats ports, providers, probes, and restart commands as configuration. The default behavior is diagnostic. Repair remains a dry run unless the user explicitly enables restart and the selected adapter confirms preflight safety.

## Who It Is For

- Developers who depend on local proxies for coding tools, browsers, API clients, or AI tooling.
- Users whose HTTP and SOCKS ports differ from common defaults.
- Teams that want provider-specific adapters without baking private machine paths into a shared script.
- Maintainers who prefer safe diagnostic fallback when no trusted restart interface exists.

## Features

- Adapter model for provider-specific status, preflight, and restart behavior.
- Generic `custom` adapter for any local proxy with configured HTTP/SOCKS endpoints.
- Diagnostic-first `falemon` adapter that does not kill live Falemon processes by default.
- Configurable HTTP proxy, SOCKS proxy, explicit ports, probe targets, and state directory.
- Resilient state-directory selection with visible source reporting for restricted environments.
- Agent profiles for generic, Codex/OpenAI, Claude/Anthropic, and custom workflows.
- `doctor`, `status`, `compact`, `repair`, and `version` commands.
- `repair` is dry-run by default and requires both `--allow-restart` and `--apply` for live restart.
- Post-restart verification checks adapter status and outbound probes before reporting success.
- Learned compact-threshold suggestions from real success/failure observations instead of hard-coded limits.
- Bounded, batched compact log scanning that reads recent metrics without storing raw log lines.
- Bounded diagnostic event logs with redacted proxy credentials.
- macOS `launchctl` proxy environment visibility when available.
- Bash test suite with mock adapters, designed to avoid touching live proxy processes.

## Install

### From Source

```bash
git clone https://github.com/HanchengQiao/proxy-stability-doctor.git
cd proxy-stability-doctor
./tests/run_tests.sh
./bin/proxy-doctor version
```

### Installer

```bash
curl -fsSL https://raw.githubusercontent.com/HanchengQiao/proxy-stability-doctor/main/scripts/install.sh | bash
```

The installer places the project under:

```text
$HOME/.local/share/proxy-stability-doctor
```

and links the executable at:

```text
$HOME/.local/bin/proxy-doctor
```

Make sure `$HOME/.local/bin` is on your `PATH`.

To install a tag or another branch:

```bash
PROXY_DOCTOR_VERSION=v0.1.0 bash scripts/install.sh
PROXY_DOCTOR_VERSION=main bash scripts/install.sh
```

## Quick Start

```bash
cp configs/proxy-doctor.example.env .env
./bin/proxy-doctor --config .env doctor
./bin/proxy-doctor --config .env status
./bin/proxy-doctor --config .env repair
```

Choose an agent profile to use built-in probe targets:

```bash
./bin/proxy-doctor --config .env --agent codex doctor
./bin/proxy-doctor --config .env --agent claude doctor
```

For diagnostic-only local checks without outbound probes:

```bash
./bin/proxy-doctor --config .env doctor --no-probes
```

To allow a real restart, configure `PD_RESTART_COMMAND` in a trusted local config file and run:

```bash
./bin/proxy-doctor --config .env repair --allow-restart --apply
```

If no safe restart command is configured, repair falls back to diagnostics.

To learn a compact threshold from actual agent behavior:

```bash
./bin/proxy-doctor --config .env --agent codex compact observe --result failure --tokens 50000 --bytes 200000
./bin/proxy-doctor --config .env --agent codex compact status
```

## Commands

```text
proxy-doctor [--config FILE] [--provider NAME] [--agent PROFILE] [--state-dir DIR] COMMAND [FLAGS]
```

- `doctor [--no-probes]`: run environment, port, adapter, and network checks.
- `status`: print provider status and recent bounded events.
- `compact status`: print learned compact-threshold suggestions for the selected agent profile.
- `compact observe --result success|failure [--tokens N] [--bytes N]`: record a compact observation.
- `compact scan --log-file FILE`: import bounded compact observations from the recent tail of a local agent log without storing raw log lines.
- `repair [--dry-run] [--allow-restart --apply] [--force]`: diagnose first, optionally restart, then verify health.
- `version`: print the CLI version.

## Configuration

The CLI reads a shell-style config file with `--config FILE`. Environment variables also work.

Important variables:

- `PD_PROVIDER`: adapter name, defaults to `custom`.
- `PD_AGENT_PROFILE`: agent profile, defaults to `generic`. Built-ins include `codex` and `claude`.
- `PD_AGENT_NAME`: optional display name for local reporting.
- `PD_HTTP_PROXY`: HTTP proxy URL. Falls back to `HTTP_PROXY` or `http_proxy`.
- `PD_SOCKS_PROXY`: SOCKS proxy URL. Falls back to `ALL_PROXY` or `all_proxy`.
- `PD_HTTP_PORT`: optional explicit HTTP local port.
- `PD_SOCKS_PORT`: optional explicit SOCKS local port.
- `PD_PROBE_TARGETS_FILE`: optional probe target file.
- `PD_RESTART_COMMAND`: trusted local shell command for adapter restart.
- `PD_STATE_DIR`: state and bounded event log directory. When unset, the CLI chooses the first writable user-state path and reports the source.
- `PD_COMPACT_OBSERVATION_LOG`: bounded compact observation log path.
- `PD_COMPACT_STATE`: learned compact-threshold state path.
- `PD_COMPACT_SCAN_MAX_BYTES`: maximum recent log bytes read by `compact scan`.
- `PD_COMPACT_SCAN_MAX_OBSERVATIONS`: maximum observations imported by one `compact scan`.

Examples:

- `configs/proxy-doctor.example.env`
- `configs/falemon.example.env`
- `configs/probes.example.txt`

Full reference: `docs/configuration.md`.

## Safety Model

- The core never kills live processes.
- The generic adapter never restarts anything unless `PD_RESTART_COMMAND` is set.
- The Falemon adapter is diagnostic by default and does not provide a destructive restart path.
- Live restart requires both `--allow-restart` and `--apply`.
- Adapter preflight must pass before restart is attempted.
- Success requires healthy provider status after restart plus successful probes unless probes are disabled.
- If a provider has no safe restart interface, the accepted fallback is diagnosis only.

## Adapter Model

Adapters are shell files that implement a small contract:

- `pd_adapter_name`
- `pd_adapter_capabilities`
- `pd_adapter_status`
- `pd_adapter_preflight`
- `pd_adapter_restart`

Built-in adapters live in `lib/proxy_doctor/adapters/`. External adapters can be loaded with `PD_ADAPTER_PATH`.

See `docs/adapter-design.md` for the contract and contribution rules.

## Documentation

- `docs/configuration.md`: config variables, probe target format, and examples.
- `docs/usage.md`: day-to-day diagnostic, compact-threshold, and repair workflows.
- `docs/adapter-design.md`: adapter contract and safe restart guidance.
- `docs/migration-plan.md`: how the original local script was split into core and adapters.
- `SECURITY.md`: security expectations and reporting guidance.
- `CONTRIBUTING.md`: local development and contribution checklist.

## Roadmap

- More provider adapters with diagnostic-only fallback when safe restart is unavailable.
- More agent profile presets for common developer workflows.
- JSON output for automation and dashboards.
- Packaged releases for Homebrew and other package managers.
- Linux systemd environment visibility helpers.

## Development

```bash
./tests/run_tests.sh
```

The test suite uses mock adapters and must not touch live proxy processes.
