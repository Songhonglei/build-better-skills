# glic-check

> Systematic, multi-dimension quality check for skills, code, configs, and docs.

GLIC and UGLIC are short checklists you can run against any change to catch
the issues that matter — syntax breaks, logic gaps, doc/code drift, scope
leaks, and (in UGLIC) user-experience pitfalls.

## What you get

| Mode | Dimensions | When to use |
|------|------------|-------------|
| **GLIC** | G + L + I + C (4) | Pure code/config quality review |
| **UGLIC** | U + G + L + I + C (5) | Anything users (humans or agents) interact with — skills, CLIs, docs |

**G — Grammar** — syntax, naming, formatting
**L — Logic** — control flow, edge cases, implicit dependencies
**I — Integrity** — completeness, doc/code alignment, boundaries
**C — Containment** — side effects, security, backward compatibility
**U — Usability & UX** (UGLIC only) — Agent executability + Human usability

## Quick start

The skill is invoked by an LLM agent (Claude Code, Cursor, OpenClaw, etc.).
Once installed, just ask:

```
"GLIC check this change"
"UGLIC this skill"
"do a glic on src/render.py"
"audit my-skill with uglic"
```

The agent will:

1. Detect the mode (GLIC vs UGLIC).
2. Read all in-scope files.
3. Run each dimension's checklist.
4. Produce a report with citations (`file:line` for every finding).
5. Tag each finding `❌ ERR` / `⚠️ WARN` / `ℹ️ INFO`.
6. Ask before fixing anything.

## Severity rules

| Tag | Meaning |
|-----|---------|
| ❌ **ERR** | Functional impact, security risk, doc misaligns with code, or user fundamentally cannot complete the core task. **Must fix.** |
| ⚠️ **WARN** | Maintainability, consistency, future risk, or user friction. **Should fix.** |
| ℹ️ **INFO** | Style preference, minor optimization. **Optional.** |

Escalation rules (enforced for every check):
- Same issue × 3+ → escalate to ERR
- Could fail silently → always ERR
- Missing doc for a public parameter → always ERR

## Why this, not "just review my code"

| Without GLIC | With GLIC |
|--------------|-----------|
| Agent reviews one thing at a time, may miss a dimension | Agent runs all dimensions deterministically |
| Findings often vague ("looks off here") | Every finding must cite `file:line` |
| No severity discipline | ERR vs WARN vs INFO with explicit escalation rules |
| Skills/CLIs reviewed only as code | UGLIC adds the user-experience lens (skills, CLIs, docs) |

## Part of build-better-skills

This skill is part of the
[build-better-skills](https://github.com/Songhonglei/build-better-skills)
suite — open-source skills that help you build better skills, end-to-end:

| Stage | Skill | What it does |
|-------|-------|--------------|
| Creation | `skill-creator` | Scaffold a new skill from intent |
| **Audit** | **`glic-check`** | **Systematic quality review (4 / 5 dimensions)** |
| Testing | `skill-regression` | End-to-end regression testing |
| Release | `skill-release` | Package + publish to skill hubs |
| Sediment | `skill-sediment` | Promote successful workflows to skills |

(Suite members ship in separate releases as they are open-sourced.)

## Files

```
glic-check/
├── SKILL.md            ← agent entry point + workflow
├── README.md           ← this file
├── LICENSE             ← MIT
├── .gitignore
└── references/
    ├── dimensions.md   ← detailed sub-check criteria per dimension
    ├── output-format.md ← report template (GLIC + UGLIC variants)
    └── examples.md     ← 4 worked examples with full reports
```

## License

MIT — see [LICENSE](./LICENSE).

## Author

Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
