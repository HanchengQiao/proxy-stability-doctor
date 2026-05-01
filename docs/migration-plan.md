# Migration Plan

## Phase 1: Clean Open Source Skeleton

- Create a standalone project rather than publishing a local state directory.
- Add a CLI, core library, adapters, examples, docs, tests, and CI.
- Keep all secrets, local logs, sqlite state, and machine-specific config out of git.

## Phase 2: Core Extraction

Reusable pieces migrated from the local reliability scripts:

- Timestamped status output.
- State directory creation.
- Lock acquisition for repair actions.
- Port listening checks.
- HTTP probe execution through a configured proxy.
- Allowed status-code matching.
- Bounded action logging.
- Wait-until-health loops.

Provider-specific pieces intentionally left out of the core:

- Falemon binary paths.
- Falemon process names.
- Falemon LaunchAgent labels.
- Agent-specific assumptions in core logic; these now live behind profiles, adapters, or explicit local config.
- Raw local log persistence.
- Hard-coded HTTP and SOCKS ports.

## Phase 3: Adapter Expansion

Adapters should be added for providers only when their safe status and restart surfaces are understood. If a provider does not expose a safe restart interface, its adapter should remain diagnostic-only.

## Phase 4: Publish

Before publishing to GitHub:

- Review `.gitignore` and `git status`.
- Run `./tests/run_tests.sh`.
- Choose repo owner, repo name, visibility, and license.
- Use a GitHub token or authenticated `gh` session with repo creation and push permissions.
