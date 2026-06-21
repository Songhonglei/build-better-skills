---
name: skill-hub-united
description: >
  Install skills from multiple skill hubs with one tool: clawhub.ai
  (default), skills.sh (npx skills, GitHub-based), the official
  anthropics/skills repo, and your own self-hosted "custom" hub. Routes
  to the right source based on how the user phrases the request, handles
  name collisions (rename/overwrite/abort), Anthropic source-available
  license gating, multi-skill repos, and path-traversal-safe extraction.
  Use when the user says "install skill X", "add skill X", "download
  skill X", "get X from clawhub", "use skills.sh to install X", "npx
  skills add X", "install the claude/anthropic X skill", or "install X
  from my hub". Also triggers in Chinese: "安装skill xxx"、"装一下xxx"、
  "下载skill xxx"、"从 clawhub 装 xxx"、"用 skills.sh 装 xxx"、"装 claude 的 xxx"、
  "从我的 hub 装 xxx"。
---

# Skill Hub United Installer

One installer for multiple skill hubs — picks the right source from how the
user phrases the request.

- **Version**: 1.0.0
- **License**: MIT
- **Author**: Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
- **Repository**: https://github.com/Songhonglei/build-better-skills
- **Part of**: `build-better-skills` suite (creation → install → audit → regression → sediment)

## Sources

| Source | What it is | Auth |
|---|---|---|
| `clawhub` (default) | clawhub.ai public hub (REST, with `npx clawhub` fallback) | none |
| `skills_sh` | skills.sh / `npx skills` CLI (GitHub-source based) | none |
| `anthropic` | the official `anthropics/skills` GitHub repo (sparse-checkout) | none |
| `custom` | your own self-hosted hub — any `GET <base>/<slug>` endpoint that returns a skill zip | up to you |

## 1. Source routing (read first)

| User wording | `--source` |
|---|---|
| no source mentioned / "clawhub" / "openclaw official" / default | `clawhub` (default) |
| "skills.sh" / "npx skills" / "open skills" / "skills cli" | `skills_sh` |
| "anthropic" / "claude official" / "claude skills" / "anthropics/skills" | `anthropic` |
| "my hub" / "custom hub" / "self-hosted" / "private hub" / "company hub" | `custom` |

**Ambiguity**: if the user names multiple sources or is unclear, **ask first**
("Which source — clawhub / skills.sh / anthropic / custom?"); do not guess.

## 2. Workflow

1. **Parse the input**:
   - Extract the slug (e.g. "install my-tool" → slug = `my-tool`)
   - Decide `source` from the table above
   - For skills.sh, the slug must be `org/repo` or `org/repo#skill` or a full git URL — ask if a bare word is given
2. **Call the script**:
   ```bash
   python3 <skill-dir>/scripts/install_skill.py <slug> --source <SRC>
   ```
3. **Handle the structured exit code**:
   - `0` success → relay the script output to the user
   - `1` failure → relay the error and suggest a next step based on the message
   - `2` name conflict → script prints JSON `{"status":"conflict", "base_name", "suggested_rename", ...}`. **Tell the user about the conflict** and let them choose:
     - Rename install (use `suggested_rename`) → re-run with `--rename <name>`
     - Overwrite existing → re-run with `--rename <base_name>` (script overwrites)
     - Abort → stop
   - `3` Anthropic license restriction → script prints JSON `{"status":"license_required", "slug", ...}`. **Ask the user using the script's message verbatim** ("This skill's license only permits use inside Claude — still install?"). On confirmation re-run with `--force-license`
   - `4` skills.sh repo has multiple skills → script prints JSON `{"status":"multi_skill", "available":[...], ...}`. Show the list and let the user pick, then re-run with `<repo>#<skill-name>`
   - `5` custom source selected but `SKILL_HUB_CUSTOM_URL` not set → guide the user to configure it (see section 4 below)
4. **Report**: on success, briefly state which directory it installed to and which source was used.

## 3. Naming convention

On normal install, the package's own `name` is used (no prefix).
**Only on a name collision** does the script offer a source-prefixed
`suggested_rename`:

| Source | Conflict prefix | Example (vs local `coding-agent`) |
|---|---|---|
| custom | `custom-` | `custom-coding-agent` |
| clawhub | `clawhub-` | `clawhub-coding-agent` |
| skills.sh | `sh-` | `sh-coding-agent` |
| anthropic | `claude-` | `claude-coding-agent` |

> After a rename the script syncs the SKILL.md frontmatter `name`, so it won't trigger a new conflict.

## 4. Custom (self-hosted) hub — one-time setup

The `custom` source lets you install from **your own hub** — handy for private,
enterprise, or air-gapped skill registries. The only contract is:

> A `GET <base>/<slug>` request returns the skill packaged as a **zip**.

Configure the base URL once via the `SKILL_HUB_CUSTOM_URL` environment variable.
To avoid re-exporting it every session, write it to your shell rc file once:

```bash
# one-time: append to ~/.bashrc (or ~/.zshrc)
echo 'export SKILL_HUB_CUSTOM_URL="https://my-hub.example.com/api/skill/download"' >> ~/.bashrc
source ~/.bashrc

# verify it's set
echo "$SKILL_HUB_CUSTOM_URL"

# then install from your hub
python3 <skill-dir>/scripts/install_skill.py my-tool --source custom
# → GET https://my-hub.example.com/api/skill/download/my-tool → unzip into the skills dir
```

If `SKILL_HUB_CUSTOM_URL` is unset and `--source custom` is used, the script
exits `5` with an actionable message — it never makes a network call.

### Where skills get installed

The installer resolves the target skills directory in this order:
1. `SKILL_HUB_SKILLS_DIR` (explicit override)
2. `OPENCLAW_SKILLS_DIR` (OpenClaw-specific override)
3. `~/.claude/skills/` → `~/.openclaw/workspace/skills/` → `~/.config/skills/` (first existing wins)

Set `SKILL_HUB_SKILLS_DIR` the same one-time way if your agent uses a non-standard path.

## 5. Source details

### clawhub (default)
- REST first: `https://clawhub.ai/api/v1/download?slug=<slug>`
- Falls back to `npx clawhub@latest install` if REST fails
- Final directory name follows the package's SKILL.md `name` (clawhub slugs often carry an owner prefix)

### skills.sh
- Calls `npx skills@latest add <repo> -y --copy [-s <skill-name>]`
- Source format:
  - `org/repo` → installs all skills in the repo; if multiple, exits `4` to ask the user
  - `org/repo#<skill-name>` → installs a single skill (recommended)
  - full URL / git remote — same rules
- A bare word (no `/`) is rejected

### anthropic
- `git clone --depth 1 --filter=blob:none --sparse anthropics/skills` + `sparse-checkout set skills/<slug>`
- **License gating**: `docx/xlsx/pdf/pptx/doc-coauthoring/internal-comms` are source-available (Claude-only). The script blocks these and requires `--force-license`.
- Other subdirs (algorithmic-art / canvas-design / frontend-design / mcp-builder / skill-creator / webapp-testing / ...) are Apache 2.0 and install freely.
- Defaults to a `claude-` prefix to avoid local name collisions.

### custom (self-hosted)
- `GET <SKILL_HUB_CUSTOM_URL>/<slug>` → expects a skill zip
- 404 / 403 / network errors reported clearly; a 200 with a JSON error body (a hub returning an error masquerading as a zip) is detected and reported
- Requires `SKILL_HUB_CUSTOM_URL` (exit `5` if unset)

## 6. Edge cases

- **Wrong slug / 404**: report and suggest checking the hub
- **Illegal slug chars** (`..`, absolute path, special chars): rejected at entry (exit 1) to prevent path traversal
- **Network / timeout**: report and suggest retry
- **npx unavailable**: clawhub/skills.sh paths need Node.js — say so
- **Name collision (exit 2)**: see Workflow step 3 — must ask the user
- **Anthropic source-available limit (exit 3)**: see Workflow step 3 — use the script's message verbatim
- **skills.sh multi-skill repo (exit 4)**: see Workflow step 3 — show `available` and let the user pick
- **Custom hub not configured (exit 5)**: guide the user through section 4
- **Malicious archive (path traversal)**: the script verifies zip/tar member paths don't escape the target dir and rejects malicious packages

## 7. Out of scope

- ❌ No cross-source auto-fallback (if not found, report clearly and let the user decide)
- ❌ No cross-source aggregated search (that's a different concern)
- ❌ Anthropic source-available skills are never installed by default — `--force-license` required
- ❌ Never overwrites a local same-named skill without the user asking

## Part of build-better-skills

This skill is part of the
[build-better-skills](https://github.com/Songhonglei/build-better-skills)
suite — open-source skills that help you build better skills, end-to-end:

| Stage | Skill | Status | What it does |
|-------|-------|--------|--------------|
| Creation | `skill-creator` | 🚧 Not yet released | Scaffold a new skill from intent |
| **Install** | **`skill-hub-united`** | ✅ **v1.0.0** | Install skills from clawhub / skills.sh / anthropic / your own hub |
| **Audit** | **`glic-check`** | ✅ **v1.0.x** | Fast qualitative multi-dimension review (G/L/I/C + U) |
| **Audit** | **`skill-deep-audit`** | ✅ **v1.0.0** | Comprehensive dryRun-level exam — 7 dimensions, 115-pt score |
| **Audit** | **`skill-release-audit`** | ✅ **v1.0.x** | Final mechanical gate — 6 static modules, no LLM/network |
| Release | `skill-release` | 🚧 Not yet released | Package + publish to hubs |
| Testing | `skill-regression` | 🚧 Not yet released | End-to-end regression testing |
| Sediment | `skill-sediment` | 🚧 Not yet released | Promote successful workflows into new skills |

`skill-hub-united`, `glic-check`, `skill-deep-audit`, and `skill-release-audit`
ship today. The other entries are roadmap placeholders — they will appear in
the suite repo as they are open-sourced.
