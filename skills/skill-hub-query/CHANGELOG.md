# Changelog

All notable changes to this skill are documented here.

### v1.1.4 (2026-07-17)
- Docs: move changelog out of SKILL.md into this standalone CHANGELOG.md (open-source convention)
- **v1.0.1** (2026-06-22): UGLIC patch — all 3 ERR + 4 WARN + 2 INFO fixed.
  - **L1 (ERR)** Fix `require_hub_url` exit-in-cmdsub trap: `endpoint="$(require_hub_url)"` silently dropped the exit because `exit` only kills the subshell. Refactored to `require_hub_url || exit $?; endpoint="$(load_endpoint)"` (api_get / api_download / edit.sh). Adds an explicit doc-comment so callers don't regress.
  - **L2 (ERR)** All curl calls now set `--max-time`: 30s for JSON API (api_get / _edit_lib `PUT`/`GET`) and 120s for ZIP downloads (overridable via `SKILL_HUB_DOWNLOAD_TIMEOUT`). Previously a hung Hub would hang the entire skill indefinitely.
  - **L3 (WARN)** `sync.sh` now validates the first-page response is non-empty JSON before computing `total / pages`, instead of silently reporting "Hub has 0 skill(s)" on failure.
  - **U1 (ERR)** Auto-fixed by L1: misleading legacy-fallback notice no longer appears before the real "no Hub URL" error in sync.sh.
  - **U2 (WARN)** `edit.sh` now calls `require_hub_url` before printing any step output (previously: empty `[edit] Hub URL :` and `[1/5] fetching...` were printed before the actual error).
  - **U3 (INFO)** `load_auth_scheme` now auto-appends a trailing space if non-empty and missing one (so `SKILL_HUB_AUTH_SCHEME="Bearer"` works, not just `"Bearer "`); explicit empty (X-API-Key style) still keeps no space.
  - **I1 (WARN)** Documented previously-undocumented env vars: `SKILL_HUB_BACKUP_RETENTION` (edit.sh backups) and the new `SKILL_HUB_DOWNLOAD_TIMEOUT`.
  - **C1 (WARN)** `sync.sh` and `doctor.sh` now register `trap` EXIT handlers that prune their `mktemp` temp files on any exit path (success / error / Ctrl-C). install.sh already had one.
- **v1.0.0** (2026-06-22): Initial open-source release of `skill-hub-query`.
  Generalized fork of an internal Hub query tool:
  - `SKILL_HUB_URL` / `SKILL_HUB_AUTH_HEADER` / `SKILL_HUB_API_PREFIX` / `SKILL_HUB_LEGACY_API_PREFIX` env-driven configuration (no baked-in default; see Hub compatibility note)
  - XDG-compliant cache and credentials directories
  - Owner pre-check via `git config user.email` (no internal-network-specific paths)
  - `edit.sh` made truly optional via `SKILL_HUB_DISABLE_EDIT=1` for Hubs without `/edit` endpoint
  - Full five-stage safety flow for metadata edits (GET -> diff -> backup -> PUT -> dual-channel verify -> rollback)
  - English-first, no organization-specific identifiers
