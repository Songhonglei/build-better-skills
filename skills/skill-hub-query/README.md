# skill-hub-query

> Drive any compatible Skill Hub from the command line — search, install,
> update, and edit AI agent skills via a single predictable interface.
> Works with self-hosted Hubs that implement the documented API contract.

`skill-hub-query` is a thin, scriptable AgentSkill that talks to any Skill Hub
exposing a small, documented REST contract. It is the **Install stage** of the
[`build-better-skills`](../..) suite, complementing
[`skill-hub-united`](../skill-hub-united/) (the multi-hub installer for
clawhub.ai / skills.sh / Anthropic skills) by adding **deep CRUD** for one
target Hub at a time.

## When to use this skill

Use `skill-hub-query` when you need to:

| Need | Action |
|------|--------|
| Search the Hub by keyword / author / time / source | `bash scripts/query.sh ...` (local-cache, sub-ms) |
| Install or upgrade a specific version of a skill | `bash scripts/install.sh <slug> [version] --yes` |
| Inspect a skill's version history / single-version detail | `bash scripts/query.sh slug <name>` |
| Edit a skill's card metadata (display name, tags, visibility, summary, ...) | `bash scripts/edit.sh <slug> --show` |
| Drive a private / self-hosted Hub from automation | All scripts |

Use [`skill-hub-united`](../skill-hub-united/) instead when you want one CLI to
install from **any** of clawhub.ai / skills.sh / Anthropic / a configurable
custom hub URL.

## Heads-up: this tool is NOT clawhub.ai specific

`skill-hub-query` targets Hubs that implement the API contract documented in
[`references/api.md`](references/api.md). [clawhub.ai](https://clawhub.ai) has
its own API surface and an official CLI (`clawhub`); use that CLI for
clawhub.ai.

This tool is for private / self-hosted / compatible Hubs.

## Quick start

```bash
# 1. Configure your Hub URL (and optionally a token)
export SKILL_HUB_URL="https://hub.your-company.com"
export SKILL_HUB_TOKEN="<your-token>"          # optional; needed for private skills

# 2. Diagnose
bash scripts/doctor.sh

# 3. Sync the local cache
bash scripts/sync.sh

# 4. Use it
bash scripts/query.sh keyword calendar
bash scripts/install.sh calendar --yes         # --yes requires user authorization
bash scripts/edit.sh my-skill --show
```

See [`SKILL.md`](SKILL.md) for the full agent workflow, configuration
reference, scenarios, and API contract.

## Features

- **Dual-channel routing**: with a token uses the OpenAPI-style authenticated
  channel; without a token automatically falls back to the legacy
  unauthenticated channel (search & install public skills).
- **Local cache (jq, sub-ms queries)**: full + incremental sync with safe
  cursor handling (server-side `updatedAt`, not local wall-clock).
- **Path-traversal-safe install**: rejects unsafe ZIP entries; atomic
  whole-dir replace (no ghost files from old versions); rollback on failure.
- **Five-stage safe `edit.sh`**: GET -> diff -> backup -> PUT -> dual-channel
  verify with retry -> auto-rollback. Owner pre-check + visibility edge-case
  awareness.
- **Self-hosted-friendly**: every endpoint, auth header, and credentials path
  is configurable via env vars; XDG-compliant cache / credentials directories.
- **Agent-callable**: structured exit codes, non-interactive refusal where
  user authorization (`--yes`) is missing, friendly errors with actionable
  guidance.

## Configuration

All configuration is via env vars (with credentials-file fallback). See
[`SKILL.md`](SKILL.md#configuration) for the full table; the minimum is
`SKILL_HUB_URL`.

| Env variable | Default | Notes |
|---|---|---|
| `SKILL_HUB_URL` | **must be set** | Hub base URL |
| `SKILL_HUB_TOKEN` | (unset) | API token (optional; for private skills) |
| `SKILL_HUB_AUTH_HEADER` | `Authorization` | e.g. `X-API-Key` for API-key auth |
| `SKILL_HUB_AUTH_SCHEME` | `Bearer ` | e.g. `""` for API-key auth |
| `SKILL_HUB_DISABLE_EDIT` | `0` | Set to `1` if your Hub does not implement `/edit` |

## Hub compatibility

Your Hub must implement these endpoints (response envelope `{code, message, data}`):

```
GET  <base><SKILL_HUB_API_PREFIX>/search?page=N&size=N           -> {data:{records:[],total:N}}
GET  <base><SKILL_HUB_API_PREFIX>/versions/<slug>?limit=N        -> {data:{items:[...]}}
GET  <base><SKILL_HUB_API_PREFIX>/versions/<slug>/<version>      -> {data:{version:{...}}}
GET  <base><SKILL_HUB_LEGACY_API_PREFIX>/download/<slug>         -> zip bytes
```

Optionally for `edit.sh`:

```
PUT  <base><SKILL_HUB_EDIT_PREFIX>/edit/<slug>                    (json patch; empty body returns current state)
GET  <base><SKILL_HUB_EDIT_PREFIX>/detail/<slug>                  (cross-check channel)
```

Full details: [`references/api.md`](references/api.md).

## Safety

- **Path-traversal-safe extraction**: zip members that escape the target
  directory are rejected before unzip.
- **Atomic whole-dir replace**: a failed install rolls back to the previous
  version; no ghost files from old releases.
- **`--yes` is a user-authorization flag**: an LLM/agent caller must NOT add
  it on its own; without it, `install.sh` / `edit.sh` refuse in non-interactive
  mode.
- **Token hygiene**: tokens are masked in logs, never written outside the
  XDG-compliant credentials directory (mode 600), never committed to git.
- **Owner pre-check**: `edit.sh` verifies you own the skill before sending
  a PUT (server-side 403 is the ultimate safety net).

## Files

```
skill-hub-query/
├── SKILL.md                          # agent workflow + configuration + scenarios
├── README.md                         # this file
├── LICENSE                           # MIT
├── credentials.example.json          # template for the credentials file
├── references/
│   └── api.md                        # detailed API contract reference
└── scripts/
    ├── _lib.sh                       # path discovery + token + curl wrapper (sourced)
    ├── _edit_lib.sh                  # edit.sh internals (sourced)
    ├── doctor.sh                     # one-shot self-check
    ├── sync.sh                       # full / incremental cache sync
    ├── query.sh                      # query the local cache
    ├── install.sh                    # download + safe extract + atomic dir replace
    └── edit.sh                       # five-stage safe metadata editor (optional Hub features)
```

## Compatibility

Follows the [Anthropic Skills spec](https://docs.claude.com/en/docs/build-with-claude/skills);
runs in any compatible agent runtime (Claude Code, OpenClaw, Cursor, etc.).

## License

MIT — see [LICENSE](LICENSE).

## Part of `build-better-skills`

This skill is part of the [`build-better-skills`](../..) suite, which ships
one focused skill per stage of the skill lifecycle (creation, install, audit,
release, testing, sediment).
