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
| **`custom`** | **your own self-hosted hub** — any `GET <base>/<slug>` endpoint that returns a skill zip | your choice |

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
enterprise, or air-gapped registries. The only contract is:

> A `GET <base>/<slug>` request returns the skill packaged as a **zip**.

Configure it once via an environment variable (write it to your shell rc so you
never re-type it):

```bash
# one-time
echo 'export SKILL_HUB_CUSTOM_URL="https://my-hub.example.com/api/skill/download"' >> ~/.bashrc
source ~/.bashrc
echo "$SKILL_HUB_CUSTOM_URL"   # verify

# then
python3 scripts/install_skill.py my-tool --source custom
```

If `SKILL_HUB_CUSTOM_URL` is unset, `--source custom` exits `5` with an
actionable message and makes **no** network call.

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

### v1.0.0 (2026-06-21)

- Initial open-source release
- Four sources: clawhub (default), skills.sh, anthropic, and a configurable self-hosted `custom` hub
- Structured exit codes for conflict / license / multi-skill / missing-config handling
- Path-traversal-safe extraction and slug validation

## License

MIT — see [LICENSE](./LICENSE).

## Author

Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
