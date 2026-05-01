# Changelog

## Unreleased

- Added generic agent profiles for Codex/OpenAI, Claude/Anthropic, generic, and custom workflows.
- Added learned compact-threshold suggestions based on observed success/failure metrics instead of hard-coded limits.
- Added compact observation and log-scan commands with bounded key/value state.

## 0.1.0 - 2026-05-01

- Published the initial open-source project skeleton.
- Added adapter-first CLI commands: `doctor`, `status`, `repair`, and `version`.
- Added generic `custom` and diagnostic-first `falemon` adapters.
- Added configurable HTTP/SOCKS proxy URLs, ports, probes, and state directory.
- Added guarded repair flow with dry-run default, explicit apply flags, preflight, and post-restart verification.
- Added bounded compact event logging and redacted proxy output.
- Added mock-adapter tests and GitHub Actions CI.
