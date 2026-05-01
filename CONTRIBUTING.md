# Contributing

Thanks for helping make local proxy diagnostics safer and more portable.

## Local Setup

```bash
git clone https://github.com/HanchengQiao/proxy-stability-doctor.git
cd proxy-stability-doctor
./tests/run_tests.sh
```

No package install is required for the core test suite. `shellcheck` is optional; when present, the test runner reports shellcheck warnings before running behavioral tests.

## Safety Rules

- Do not kill live provider processes in tests.
- Do not add a destructive restart path as a default.
- Prefer diagnostic-only fallback when a provider does not expose a safe restart interface.
- Treat `PD_RESTART_COMMAND` as trusted local configuration.
- A restart is not successful until adapter status and probes are healthy afterward.
- Keep logs compact, bounded, and redacted.

## Adding An Adapter

1. Add a file under `lib/proxy_doctor/adapters/`.
2. Implement the functions documented in `docs/adapter-design.md`.
3. Keep provider paths, labels, and default ports configurable.
4. Add tests with a mock adapter or sandbox fixture.
5. Document any provider-specific environment variables.

Adapter pull requests should clearly answer:

- What read-only status signal proves the provider is usable?
- What restart mechanism is safe and provider-owned?
- What happens when restart is unavailable?
- How is post-restart health verified?

## Pull Request Checklist

- `./tests/run_tests.sh` passes.
- No secrets, local logs, sqlite files, or machine-specific state are committed.
- User-visible behavior is documented.
- New restart behavior is covered by tests and remains opt-in.

