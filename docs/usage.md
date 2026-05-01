# Usage

The normal workflow is:

1. Configure the provider, HTTP/SOCKS URLs, and optional probes.
2. Run `doctor`.
3. Review `status`.
4. Run `repair` as a dry run.
5. Enable live restart only when adapter preflight and local expectations are clear.

## Diagnostic Check

```bash
proxy-doctor --config .env doctor
```

This reports:

- Provider and adapter capabilities.
- Redacted HTTP/SOCKS proxy settings.
- Local port listening state.
- macOS `launchctl` proxy environment when available.
- Adapter-specific status.
- Outbound probe results.

To stay fully local and skip outbound probes:

```bash
proxy-doctor --config .env doctor --no-probes
```

## Compact Status

```bash
proxy-doctor --config .env status
```

`status` prints provider health and the latest compact events from the state directory. Event logs are bounded by line count and per-line byte count.

## Dry-Run Repair

```bash
proxy-doctor --config .env repair
```

Dry-run repair is the default. It diagnoses health and reports whether a restart would be allowed by adapter preflight, but it does not execute restart.

The explicit form is equivalent:

```bash
proxy-doctor --config .env repair --dry-run
```

## Live Repair

Live repair requires all of the following:

- A selected adapter that implements safe preflight and restart behavior.
- A trusted restart path, usually `PD_RESTART_COMMAND`.
- CLI flags `--allow-restart --apply`.
- Healthy adapter status after restart.
- Healthy probes after restart, unless probes are disabled.

```bash
proxy-doctor --config .env repair --allow-restart --apply
```

To attempt repair even when current health already looks good:

```bash
proxy-doctor --config .env repair --allow-restart --apply --force
```

## Diagnostic Fallback

If a provider has no safe restart interface, `repair` falls back to diagnostics. This is intentional. A failed or missing preflight is safer than pretending that a process kill is a valid repair.

## External Adapter

```bash
PD_ADAPTER_PATH=/path/to/my-provider-adapter.sh proxy-doctor --config .env doctor
```

External adapters should follow the same safety rules as built-in adapters. See `docs/adapter-design.md`.

