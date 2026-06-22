# skill-hub-united

> One installer for multiple skill hubs — clawhub, skills.sh, the official
> Anthropic skills repo, and your own self-hosted hub.

Skill ecosystems are fragmented across several hubs, each with its own CLI and
conventions. `skill-hub-united` gives an AI agent a single, predictable way to
install a skill from whichever hub the user means — and lets you plug in your
own private/self-hosted hub with one environment variable.

## Sources

| Source | What it is | Auth |
|--------|------------|------|
| **`clawhub`** (default) | [clawhub.ai](https://clawhub.ai) public hub (REST + `npx clawhub` fallback) | none |
| **`skills_sh`** | [skills.sh](https://skills.sh) / `npx skills` CLI (GitHub-based) | none |
| **`anthropic`** | the official [`anthropics/skills`](https://github.com/anthropics/skills) repo (sparse-checkout) | none |
| **`custom`** | **your own self-hosted hub** — any `GET <base>/<slug>` endpoint that returns a skill zip/tar | your choice |

## Quick start

The skill is invoked by an LLM agent (Claude Code, OpenClaw, Cursor, etc.).
Once installed, just ask:

```
"install my-tool"                 → clawhub (default)
"install my-tool from clawhub"
"use skills.sh to add obra/superpowers"
"install the anthropic webapp-testing skill"
"install my-tool from my hub"     → custom (self-hosted)
```

The agent runs the installer and handles structured exit codes (name
conflicts, license gating, multi-skill repos, missing custom-hub config).

## Self-hosted "custom" hub

The `custom` source installs from **your own hub** — useful for private,
enterprise, or air-gapped registries.

### 1. Configure the URL (one-time)

Set `SKILL_HUB_CUSTOM_URL` to your hub's **download base**. Write it to your
shell rc so you never re-type it:

```bash
# one-time
echo 'export SKILL_HUB_CUSTOM_URL="https://my-hub.example.com/api/skill/download"' >> ~/.bashrc
source ~/.bashrc
echo "$SKILL_HUB_CUSTOM_URL"   # verify
```

If `SKILL_HUB_CUSTOM_URL` is unset, `--source custom` exits `5` with an
actionable message and makes **no** network call.

### 2. Install

```bash
python3 scripts/install_skill.py my-tool --source custom
# or just tell the agent: "install my-tool from my hub"
```

### Server-side contract

Your hub only needs **one** endpoint. The installer builds the request URL by
appending `/<slug>` to your configured base:

```
GET  <SKILL_HUB_CUSTOM_URL>/<slug>
```

For example, with the base above, `install my-tool` requests:

```
GET https://my-hub.example.com/api/skill/download/my-tool
```

Your endpoint must respond with:

| Response | Meaning | Installer behavior |
|----------|---------|--------------------|
| `200` + **zip or tar** body | the skill archive | extracted into your skills dir (a single top-level folder prefix is stripped automatically) |
| `404` | skill not found | clear "not found" error, exit `1` |
| `403` | no access / private | clear "no access" error, exit `1` |
| `200` + JSON `{"code":403,"message":"..."}` | soft error masquerading as a body | detected and reported (exit `1`) |

**Archive layout** — the zip/tar may either contain the skill files at the
root, or wrap them in a single top-level directory (e.g. `my-tool/SKILL.md`);
both work, the wrapper folder is stripped on extraction. `SKILL.md` must end up
at the skill root.

### Limitations & notes

- **No auth headers.** The `custom` source sends only an `Accept` header — it
  does **not** send tokens, cookies, or basic-auth. For private hubs, gate
  access by network (VPN / internal DNS / IP allowlist) rather than per-request
  credentials. (Need authenticated downloads? Open an issue.)
- **Slug charset.** Slugs are validated to `[a-zA-Z0-9._-]` before the request,
  so your endpoint never receives path-traversal or special characters.
- **Replace semantics.** If a skill of the same name already exists locally, the
  target directory is wiped before extraction so no stale files linger. (A
  different *local* name can be chosen with `--rename`.)

### Minimal reference server

Any static file host works if it can map `/<slug>` to a zip. A tiny Python
example:

```python
# serve.py — python3 serve.py  (then SKILL_HUB_CUSTOM_URL=http://localhost:8000/download)
import http.server, os, urllib.parse

SKILLS = "/path/to/your/skill-zips"   # contains my-tool.zip, other-tool.zip, ...

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # path looks like /download/<slug>
        slug = urllib.parse.unquote(self.path.rsplit("/", 1)[-1])
        zip_path = os.path.join(SKILLS, slug + ".zip")
        if not os.path.isfile(zip_path):
            self.send_response(404); self.end_headers(); return
        self.send_response(200)
        self.send_header("Content-Type", "application/zip"); self.end_headers()
        with open(zip_path, "rb") as f:
            self.wfile.write(f.read())

http.server.HTTPServer(("0.0.0.0", 8000), H).serve_forever()
```

Each `my-tool.zip` should contain the skill (with `SKILL.md` at root, or under
a single `my-tool/` folder).

### Where skills install to

Resolved in order: `SKILL_HUB_SKILLS_DIR` → `OPENCLAW_SKILLS_DIR` →
`~/.claude/skills/` → `~/.openclaw/workspace/skills/` → `~/.config/skills/`
(first existing wins). Override with `SKILL_HUB_SKILLS_DIR` (same one-time
rc-file approach).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Installed successfully |
| `1` | Failure (not found / no permission / network / extract error / unsafe archive) |
| `2` | Name conflict, no `--rename` given — agent asks the user |
| `3` | Anthropic source-available license, no `--force-license` |
| `4` | skills.sh repo has multiple skills — pick one with `repo#name` |
| `5` | `custom` source selected but `SKILL_HUB_CUSTOM_URL` not set |

## Safety

- **Path-traversal-safe extraction**: zip/tar members that escape the target
  directory are rejected.
- **Slug validation**: `..`, absolute paths, and special characters are
  rejected at entry.
- **No silent overwrite**: a same-named local skill is never overwritten
  unless the user explicitly chooses to.
- **License gating**: Anthropic source-available skills (`docx`, `xlsx`,
  `pdf`, `pptx`, `doc-coauthoring`, `internal-comms`) require an explicit
  `--force-license`.

## Compatibility

Follows the
[Anthropic Skills spec](https://docs.claude.com/en/docs/build-with-claude/skills)
and runs in any compatible agent runtime (Claude Code, OpenClaw, Cursor, and
other frameworks that support the Skills spec).

## Files

```
skill-hub-united/
├── SKILL.md              ← agent entry point + routing + workflow
├── README.md             ← this file
├── LICENSE               ← MIT
├── .gitignore
└── scripts/
    └── install_skill.py  ← the multi-source installer
```

## Part of build-better-skills

This skill is part of the
[build-better-skills](https://github.com/Songhonglei/build-better-skills)
suite — open-source skills that help you build better skills, end-to-end:

| Stage | Skill | Status |
|-------|-------|--------|
| Creation | `skill-creator` | 🚧 Not yet released |
| **Install** | **`skill-hub-united`** | ✅ **v1.0.0** |
| **Audit** | **`glic-check`** | ✅ **v1.0.x** |
| **Audit** | **`skill-deep-audit`** | ✅ **v1.0.0** |
| **Audit** | **`skill-release-audit`** | ✅ **v1.0.x** |
| Release | `skill-release` | 🚧 Not yet released |
| Testing | `skill-regression` | 🚧 Not yet released |
| Sediment | `skill-sediment` | 🚧 Not yet released |

`skill-hub-united`, `glic-check`, `skill-deep-audit`, and `skill-release-audit`
are installable today. The other entries are roadmap placeholders.

## Changelog

### v1.0.2 (2026-06-22)

- Docs: full self-hosted `custom` hub guide — server-side contract (exact
  request URL, accepted zip/tar response, 404/403/JSON-error semantics, archive
  layout), limitations (no auth headers; gate by network), and a minimal
  reference server example. No code changes.

### v1.0.1 (2026-06-21)

- Docs: correct the suite stages table (the comprehensive auditor is
  `skill-deep-audit`, and `skill-release-audit` was added as a third audit
  tool). No code changes.

### v1.0.0 (2026-06-21)

- Initial open-source release
- Four sources: clawhub (default), skills.sh, anthropic, and a configurable self-hosted `custom` hub
- Structured exit codes for conflict / license / multi-skill / missing-config handling
- Path-traversal-safe extraction and slug validation

## License

MIT — see [LICENSE](./LICENSE).

## Author

Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
