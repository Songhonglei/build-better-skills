---
name: skill-release-audit
description: >
  Pre-publish quality and safety auditor for AI agent skills (SKILL.md +
  scripts/ + references/ format used by Claude Code, Cursor, OpenAI Codex,
  GitHub Copilot, OpenClaw, ClawHub, and compatible SkillHub registries).
  Six static-check modules (no LLM, no network by default): (1) syntax and
  logic correctness, (2) feature completeness, (3) edge-case and error
  handling, (4) data safety (detects files written inside the skill dir that
  would be lost on update), (5) dependency declaration vs code, (6) SKILL.md
  documentation standards. Per-registry rule profiles via `--target`. Pure
  reporter — never edits your files, never publishes. Use when publishing
  a skill, modifying an existing skill, or diagnosing why a skill behaves
  unexpectedly — run it as the last machine-checkable gate before release.
  Trigger phrases: "skill release audit", "audit before publishing",
  "pre-release check", "release gate", "skill safety check",
  "发版前检查", "skill 发布检查", "审查这个 skill 能不能发版".
---

# skill-release-audit

- **Version**: 1.0.1
- **License**: MIT
- **Author**: Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
- **Repository**: https://github.com/Songhonglei/build-better-skills
- **Part of**: [`build-better-skills`](https://github.com/Songhonglei/build-better-skills) suite — **Audit** stage. Full pipeline: creation → install → audit → release → testing → sediment.

A six-module static inspector that catches mechanical problems machines can
verify — broken Python syntax, undeclared env vars, files written inside the
skill dir that would be lost on update, missing README/LICENSE for GitHub
targets, mismatched docs and scripts. Pairs with [`glic-check`](https://github.com/Songhonglei/build-better-skills/tree/main/skills/glic-check)
which does cognitive UGLIC review; together they cover both layers
(see [Part of build-better-skills](#part-of-build-better-skills)).

Prints a structured `✅/⚠️/❌` report per module with actionable fixes. **Does
not auto-fix.** All fixes require user confirmation.

---

## Agent Behavior Rules (must-read)

This skill is an **Auditor, not a Fixer.**

After running the check, the agent must follow these rules strictly:

1. **Show the full report first** — every module result, every warning / error
   with its specific description.
2. **Suggest fixes per finding, but only as suggestions, not actions.**
3. **Wait for explicit user confirmation** before touching any file.
4. **Never modify SKILL.md, scripts/, references/, or any other file** without
   confirmation.
5. **Never delete files**, even ones that look like leftovers — always ask first.

**Correct output template:**

```
📋 Check report: <skill-name>
[full output of healthcheck.py]

---
Issues found. Please confirm what to do:

✅ Can be ignored (false positives):
- Module 1: cache.json path warning — SKILL.md mentions it as descriptive text,
  not a file reference.

⚠️ Suggested fixes (awaiting your confirmation):
1. Module 3: auto_update.py _log() missing try/except — suggest wrapping.
2. Module 2: guide.py not listed in SKILL.md's module table — suggest adding.

Tell me which to fix and which to ignore. I'll act after you confirm.
```

---

## Usage

```bash
# Full check — report only, does NOT modify your environment (default)
python scripts/healthcheck.py <path/to/skill-dir>

# Opt in to auto pip-install missing Python deps (off by default)
python scripts/healthcheck.py <path/to/skill-dir> --auto-install

# Tune per-package install timeout (only with --auto-install)
python scripts/healthcheck.py <path/to/skill-dir> --auto-install --install-timeout 120

# Validate against a specific publishing target (tunes checks, does NOT publish)
python scripts/healthcheck.py <path/to/skill-dir> --target clawhub

# Report output language: zh or en (default: auto-detected from $LC_ALL / $LANG)
python scripts/healthcheck.py <path/to/skill-dir> --lang en

# Run specific modules only (e.g. deps + docs)
python scripts/healthcheck.py <path/to/skill-dir> --modules 5,6
```

> Default behavior is **report only, do not install** — an auditor should not
> mutate the user's environment. Missing required deps are reported as ERROR;
> with `--auto-install`, install failures are reported as WARN (usually
> network/registry issues, not skill bugs).

## Publishing target (`--target`)

Different registries have different rules. `--target` tunes which checks fire
and at what severity — it **does not publish**.

| target | Use case | Notes |
|--------|----------|-------|
| `generic` (default) | Cross-registry minimum | Loosest, smallest common set |
| `clawhub` | clawhub.com | name+description required, strict slug, 50MB cap, declaration-vs-code consistency |
| `anthropic` | Anthropic-compatible base spec | name≤64 / description≤1024, body recommended <5k tokens |
| `github` | Open-sourcing to GitHub | Requires README + LICENSE |
| `skillhub` | Private SkillHub (vendor-compatibility layers) | Same as clawhub but version required (WARN) |

Profiles live in [`profiles/`](profiles/) as JSON; add your own by dropping a new
`<name>.json` there. See [`references/hub-specs.md`](references/hub-specs.md)
for per-registry specifications encoded by these profiles.

## Report language

Default: auto-detected from `$LC_ALL` / `$LC_MESSAGES` / `$LANG`. Falls back to
`zh` (legacy default). Currently supported: `zh` / `en`.

- CLI: `--lang zh` / `--lang en`
- Env: `SKILL_AUDIT_LANG=en` (lower priority than `--lang`)

All user-facing text is centralized in `scripts/i18n.py` as a bilingual
key-table — add a new check by adding one `zh`/`en` entry; do not hardcode
strings in module files.

Exit codes: `0` = no errors (may have warnings), `1` = errors found,
`2` = invalid input.

## The six modules

| Module | Checks | Script |
|--------|--------|--------|
| 1. Syntax & logic | Python AST parse, Bash `-n` syntax check, internal reference paths, leftover TODO/FIXME | `scripts/check_logic.py` |
| 2. Feature coverage | scripts / references mentioned in SKILL.md, stub-file detection | `scripts/check_features.py` |
| 3. Edge cases | try/except coverage, HTTP timeout, response-status handling, Bash `set -e` | `scripts/check_edges.py` |
| 4. Data safety | Files written *inside* the skill dir (lost on update) | `scripts/check_data_safety.py` |
| 5. Dependencies | Python / Node / Bash deps, optional `--auto-install`, **declaration-vs-code env check** | `scripts/check_deps.py` |
| 6. Documentation | description quality, frontmatter discipline, slug rules, target-specific required files (README / LICENSE) | `scripts/check_docs.py` |

## Data safety hint

Skill directories are overwritten on update. All persistent data must live
**outside** the skill dir. The auditor probes the runtime environment
(OpenClaw / Claude Code / Codex / plain checkout) and suggests a portable path:

```python
from pathlib import Path
DATA_DIR = Path.home() / ".skill-data" / "<skill-name>"   # example, auto-tuned
```

See `references/safe-paths.md` for the full resolution order.

## Declaration vs code env check

Mirrors registry-side security analysis: if your code reads an env var
(`os.environ["X"]`, `os.getenv(...)`, `process.env.X`) that isn't declared in
frontmatter under `metadata.openclaw.requires.env` / `primaryEnv` / `envVars`,
the auditor flags a metadata mismatch (severity is profile-driven). This catches
the most common cause of post-publish runtime failures.

## Dependency declaration convention

In SKILL.md body, add a dependency section:

```markdown
## Dependencies

Auto-installed on first use: requests, pyyaml

System commands (install manually): jq (`brew install jq`)
```

See `references/dep-patterns.md`.

## Dependencies

Core uses Python 3.8+ standard library only — no external installs needed.

Optional enhancement: `pyyaml` (auto-detected). With PyYAML, frontmatter
parsing handles multi-line / list / nested fields strictly. Without it, a
tolerant built-in parser handles inline JSON values (e.g.
`metadata: {"key": "value"}`) so the same checks still work — no functionality
loss.

## Part of build-better-skills

This skill is part of the [build-better-skills](https://github.com/Songhonglei/build-better-skills)
suite — a complete toolchain for the full lifecycle of agent skill development.

| Stage | Skill | Status | What it does |
|---|---|---|---|
| Creation | `skill-creator` | 🚧 Not yet released | Scaffold a new skill from intent |
| Audit | **`glic-check`** | ✅ **v1.0.1** | Cognitive UGLIC quality review (4 / 5 dimensions) |
| Audit | **`skill-deep-audit`** | ✅ **v1.0.0** | Heavyweight quantitative scoring (115-point scale, L1/L2 depths) |
| **Audit** | **`skill-release-audit`** | ✅ **v1.0.0** | **Mechanical pre-publish gate (6 static-check modules)** |
| Release | `skill-release` | 🚧 Not yet released | Package + publish to hubs |
| Testing | `skill-regression` | 🚧 Not yet released | End-to-end regression testing |
| Sediment | `skill-sediment` | 🚧 Not yet released | Promote successful workflows to skills |

Three Audit-stage tools are **complementary**:

- `glic-check` — **cognitive** lightweight review (UGLIC 5 dimensions) — agent
  reads and judges. Use during tight edit loops.
- `skill-deep-audit` — **cognitive** heavyweight scorecard (115-point scale,
  7 dimensions, L1/L2 depths). Use for mid-cycle comprehensive checks.
- `skill-release-audit` — **mechanical** static gate (6 modules, no LLM,
  no network by default). Use as the last automated gate before publishing.

Recommended workflow: `glic-check` during development →
`skill-deep-audit` mid-cycle → `skill-release-audit` right before
`clawhub publish` / `git push` / `npx skills publish`.
