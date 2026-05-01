# Adapter Design

The core owns configuration, logging, probe execution, locking, and repair policy. Adapters own provider-specific discovery and restart behavior.

## Required Functions

```bash
pd_adapter_name
pd_adapter_capabilities
pd_adapter_status
pd_adapter_preflight
pd_adapter_restart
```

### `pd_adapter_name`

Prints a short provider name.

### `pd_adapter_capabilities`

Prints a comma-separated capability list such as:

```text
status,diagnose,restart-command
```

### `pd_adapter_status`

Returns zero only when the provider-local status is healthy enough to use. It should print compact human-readable lines and avoid raw process dumps.

### `pd_adapter_preflight`

Returns zero only when a restart can be attempted safely. If no safe restart interface exists, return non-zero and let the core fall back to diagnostics.

### `pd_adapter_restart`

Runs the safe restart action. The core calls this only after `pd_adapter_preflight` succeeds and the user passes both `--allow-restart` and `--apply`.

## Optional Functions

```bash
pd_adapter_summary
```

Prints compact adapter-specific configuration with secrets redacted.

## Rules

- Do not kill live processes by default.
- Do not treat a restart command exit code as final success.
- Do not store unbounded logs.
- Keep provider-specific paths, binary names, labels, and ports in the adapter or user config.

