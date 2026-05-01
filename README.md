# Proxy Stability Doctor

Proxy Stability Doctor is a small, adapter-based CLI for diagnosing and safely repairing local proxy setups. It is designed for users who may have different HTTP and SOCKS ports, different proxy providers, and different restart mechanisms.

The default behavior is diagnostic. Repair actions are dry-run unless the user explicitly passes restart flags and the selected adapter exposes a safe restart path.

## Quick Start

```bash
cp configs/proxy-doctor.example.env .env
./bin/proxy-doctor --config .env doctor
./bin/proxy-doctor --config .env status
./bin/proxy-doctor --config .env repair
```

To allow a real restart, configure `PD_RESTART_COMMAND` and run:

```bash
./bin/proxy-doctor --config .env repair --allow-restart --apply
```

If no safe restart command is configured, repair falls back to diagnostics only.

## Commands

- `doctor`: run environment, port, adapter, and network checks.
- `status`: print a compact provider status and recent bounded events.
- `repair`: diagnose first, then optionally run adapter restart and verify health.
- `version`: print the CLI version.

## Safety Model

- No live process is killed by the core.
- The generic adapter never restarts anything unless `PD_RESTART_COMMAND` is set.
- The Falemon adapter does not provide a default destructive restart path.
- Real restart requires both `--allow-restart` and `--apply`.
- Success requires post-restart adapter status and probe health.

## Configuration

The CLI reads a shell-style config file with `--config FILE`. Environment variables also work.

Important variables:

- `PD_PROVIDER`: adapter name, defaults to `custom`.
- `PD_HTTP_PROXY`: HTTP proxy URL. Falls back to `HTTP_PROXY` or `http_proxy`.
- `PD_SOCKS_PROXY`: SOCKS proxy URL. Falls back to `ALL_PROXY` or `all_proxy`.
- `PD_HTTP_PORT`: optional explicit HTTP local port.
- `PD_SOCKS_PORT`: optional explicit SOCKS local port.
- `PD_PROBE_TARGETS_FILE`: optional probe target file.
- `PD_RESTART_COMMAND`: trusted local shell command for adapter restart.
- `PD_STATE_DIR`: state and compact event log directory.

See `configs/proxy-doctor.example.env` and `configs/falemon.example.env`.

## Adapter Contract

Adapters are shell files that implement:

- `pd_adapter_name`
- `pd_adapter_capabilities`
- `pd_adapter_status`
- `pd_adapter_preflight`
- `pd_adapter_restart`

See `docs/adapter-design.md`.

## Development

```bash
./tests/run_tests.sh
```

The test suite uses mock adapters and must not touch live proxy processes.

