# Changelog

## Unreleased

- Hardened the installer with source validation, version smoke checks, reinstall backups, rollback on failure, and clearer next-step output.
- Simplified first-run documentation so users can install once and run a no-config diagnostic immediately.
- Added generic agent profiles for Codex/OpenAI, Claude/Anthropic, generic, and custom workflows.
- Added learned compact-threshold suggestions based on observed success/failure metrics instead of hard-coded limits.
- Added compact observation and log-scan commands with bounded key/value state.
- Added automatic writable state-directory selection with source reporting and strict validation for explicit paths.
- Improved compact log scans with recent-tail limits, observation caps, and a single batched threshold recalculation.
- Added runtime tool diagnostics for missing `curl`, `lsof`, and `nc`, plus safer local-only `repair --no-probes` flows.
- Added config normalization and validation for provider names, agent aliases, ports, timeouts, log limits, and compact margins.
- Added JSON/colon-style compact log metric scanning alongside key/value logs.
- Hardened Falemon health checks with configurable process signals and explicit failure when no required health signal is configured.

## 0.1.0 - 2026-05-01

- Published the initial open-source project skeleton.
- Added adapter-first CLI commands: `doctor`, `status`, `repair`, and `version`.
- Added generic `custom` and diagnostic-first `falemon` adapters.
- Added configurable HTTP/SOCKS proxy URLs, ports, probes, and state directory.
- Added guarded repair flow with dry-run default, explicit apply flags, preflight, and post-restart verification.
- Added bounded compact event logging and redacted proxy output.
- Added mock-adapter tests and GitHub Actions CI.
