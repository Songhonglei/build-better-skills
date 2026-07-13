# Strip Checklist — 11 rules + literal-replacement map

> Full checklist. After the Step 3 literal-layer grep hits, use this as the
> per-item handling reference.
>
> ⚠️ **Stay in sync**: `scripts/strip_scan.sh`'s default KEYWORDS table only holds
> **generic** sensitive words. **Company-specific** words (internal domains, platform
> codenames, org names) are user-configured via `setup_profile.sh`
> (→ `strip_keywords.txt`), `OSG_STRIP_KEYWORDS`, or `OSG_STRIP_KEYWORDS_FILE`.
> Below, `<company>` / `<internal-host>` / `<workspace>` are placeholders — substitute
> your own environment's real values when scanning.

## The 11 must-delete / must-change rules

| # | Item | Handling |
|---|---|---|
| 1 | `sign.key`, skill-meta json, `*.json.md` | Delete (internal signatures / agent artifacts; `fork.sh` auto-deletes) |
| 2 | `.install-source.json` | Delete (internal install-source marker; `fork.sh` auto-deletes) |
| 3 | `__pycache__/`, `*.pyc`, `.skill-data/` | Delete (agent runtime cache; `fork.sh` auto-deletes) |
| 4 | `USAGE.md` (if it duplicates SKILL.md) | Delete (avoid bilingual maintenance cost) |
| 5 | Hardcoded internal hosts (e.g. `<service>.<company>.com`, CDN hosts) | Change to runtime concatenation or env vars |
| 6 | Hardcoded internal paths (e.g. `<workspace>`, `~/<agent-home>/`) | Change to `pwd`, user args, or env vars |
| 7 | Internal concept references (company / platform / product names) | Change to generic names (`PROJECT_NAME` / `<your-tool>`); already-public brand names may stay |
| 8 | Internal email examples (e.g. `@<company>.com`) | Replace with `user@example.com` |
| 9 | Internal gitignore artifact paths (e.g. `.skill-data` / `.<internal-tool>`) | Delete; use generic `id_rsa` / `*.p12` / `certs/*.key` |
| 10 | Internal user names / aliases / UIDs | Delete; unify to the user-decided public identity (via `OSG_AUTHOR_NAME` / `OSG_STRIP_WHITELIST`) |
| 11 | Business-system fallbacks (env / region / namespace codes) | Don't keep; make a user-configurable list (`--probe-env "A,B,C"`) |

## Literal-replacement map

| Internal literal | Open-source replacement | Location |
|---|---|---|
| `<workspace>` default path | `${WORKSPACE_DIR:-$PWD}` | path-resolution block |
| Internal token file (e.g. `~/<agent-home>/token.json`) | `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` env vars | identity-read block |
| Internal identity file read | Delete the whole block | identity-read block |
| `IDENTITY.md`-style parse | Delete; use `basename "$WORKSPACE_DIR"` | project-name detection |
| `AGENT_NAME` variable | `sed -i s/AGENT_NAME/PROJECT_NAME/g` | whole file |
| `"<Platform> Agent"` copy | `"project"` or `"workspace"` | all echo/info |
| `.skill-data` / `.<internal-tool>` | generic `id_rsa` / `*.p12` / `*.keystore` / `**/certs/*.key` | `.gitignore` + `SENSITIVE_PATTERNS` |
| Internal container / CRLF context | generalize | autocrlf hint |
| `name@<company>.com` | `jane@example.com` | user prompts |
| `signed_by: <internal-name>` | Delete the whole `sign.key` file | skill root |
| Internal build/CI host | Delete `.install-source.json` | skill root |

## Generic code snippets

### Path priority

```bash
WORKSPACE_DIR="${WORKSPACE_DIR:-$PWD}"
# Don't assume any specific agent-home path
```

### Project-name detection

```bash
# Old (internal):
PROJECT_NAME=$(grep '^name:' IDENTITY.md | awk '{print $2}')

# New (open-source):
PROJECT_NAME="${PROJECT_NAME:-$(basename "$WORKSPACE_DIR")}"
```

### git identity read

```bash
# Old (internal): read from an internal token file
# New (open-source): prefer git config, fall back to env vars
USER_NAME="${GIT_AUTHOR_NAME:-$(git config user.name 2>/dev/null || echo '')}"
USER_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email 2>/dev/null || echo '')}"
if [[ -z "$USER_NAME" || -z "$USER_EMAIL" ]]; then
  echo "Set git user or GIT_AUTHOR_NAME/EMAIL env vars" >&2
  exit 1
fi
```

### locale detection

```bash
# Don't hardcode a language; detect from $LC_ALL / $LC_MESSAGES / $LANG
detect_lang() {
  local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-en_US.UTF-8}}}"
  case "$raw" in
    zh*) echo "zh" ;;
    *)   echo "en" ;;
  esac
}
LANG_DEFAULT="$(detect_lang)"
```
