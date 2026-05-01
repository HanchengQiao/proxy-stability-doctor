# Project Guardrails

## Restart Safety
- Do not kill or restart a real proxy process during development or tests.
- Restart behavior must be exercised with a mock adapter before it is used live.
- Live repair requires an adapter-provided safe restart path and explicit CLI flags.
- A restart is successful only when post-restart health checks pass.

## Logging
- Do not write raw prompts, raw tool output, full process dumps, or long command output to logs.
- Logs should use compact event lines with bounded length and bounded file size.
- Redact credentials from proxy URLs before printing or logging.

## Portability
- Keep provider-specific behavior inside adapters.
- Keep the default provider generic and diagnostic-first.
- macOS helpers are allowed, but the core must remain usable without launchctl.

