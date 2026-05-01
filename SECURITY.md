# Security

Proxy Stability Doctor is intended to run on developer machines and inspect local proxy configuration. Treat configuration files as trusted local input.

## Sensitive Data

- Do not commit `.env`, local logs, sqlite files, or state directories.
- Proxy URLs are redacted before printing when credentials are present.
- Compact logs should contain metadata, bounded excerpts, and status summaries only.

## Restart Commands

`PD_RESTART_COMMAND` is a trusted local shell command. The CLI will not run it unless the user passes both:

```bash
--allow-restart --apply
```

If no safe restart command is configured, repair falls back to diagnostics.

## Reporting Issues

When reporting a vulnerability, include:

- Version or commit.
- Operating system.
- Adapter name.
- Minimal reproduction.
- Redacted logs only.

