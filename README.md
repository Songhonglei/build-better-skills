# build-better-skills

> A suite of open-source skills that help you build better skills —
> from creation through audit, release, regression testing, and sediment.

Skills are how AI agents extend their own capabilities. As skill ecosystems
mature, building good skills is itself a discipline: writing clear triggers,
keeping doc/code in sync, catching regressions, signing releases, and
promoting successful workflows into reusable skills.

This suite ships one focused skill per stage of that lifecycle.

## Stages

| Stage | Skill | Status |
|-------|-------|--------|
| Creation | `skill-creator` | Coming soon |
| **Audit** | **[`glic-check`](skills/glic-check/)** | ✅ v1.0.1 |
| **Audit** | **[`skill-deep-audit`](skills/skill-deep-audit/)** | ✅ v1.0.0 |
| **Audit** | **[`skill-release-audit`](skills/skill-release-audit/)** | ✅ **v1.0.0** |
| Release | `skill-release` | Coming soon |
| Testing | `skill-regression` | Coming soon |
| Sediment | `skill-sediment` | Coming soon |

Three complementary audit tools cover different layers of skill quality:

- **`glic-check`** (Audit) — lightweight & qualitative. A fast multi-dimension
  agent review you run right after any edit. Best for tight edit loops.
- **`skill-deep-audit`** (Audit) — heavyweight & quantitative. A full
  dryRun-level exam that grades a skill on a 115-point scale. Best as the
  comprehensive mid-cycle check.
- **`skill-release-audit`** (Audit) — mechanical static gate.
  6 modules, no LLM, no network by default. Best as the **final automated
  gate immediately before publishing** to clawhub / GitHub / skills.sh.

## glic-check (audit · fast review)

Systematic, multi-dimension quality check for skills, code, configs, and docs.

- **GLIC** mode: 4 dimensions (Grammar / Logic / Integrity / Containment)
- **UGLIC** mode: 5 dimensions, adding Usability & User Experience (Agent + Human perspectives)

Every finding cites `file:line`. Severity is tagged `ERR` / `WARN` / `INFO`
with explicit escalation rules (silent-failure = ERR, repeated WARN → ERR).

→ Read [`skills/glic-check/README.md`](skills/glic-check/README.md) for details.

## skill-deep-audit (audit · comprehensive exam)

A read-only, multi-dimensional auditor that grades any skill on a 115-point scale.

- **7 dimensions**: process closure & idempotency, tool/command conventions,
  portability & defense, usability, security & op risk, code & doc quality,
  dependency & footprint health
- **Two depths**: L1 static (~2 min) and L2 dryRun (~5 min, read-only hub +
  reachability checks)
- **Strict pass gate**: total ≥ 90 **and** zero ERR
- **`--fix`**: backup-first, splits auto-safe fixes from business-logic ones

→ Read [`skills/skill-deep-audit/README.md`](skills/skill-deep-audit/README.md) for details.

## skill-release-audit (audit · final mechanical gate)

The last machine-checkable gate before `clawhub publish` / `git push` /
`npx skills publish`. No LLM, no network by default — pure static analysis.

- **6 static modules**: syntax & logic, feature coverage, edge cases & errors,
  data safety, dependencies (incl. declaration-vs-code env check), documentation
- **5 registry profiles** (`--target`): clawhub / anthropic / github / skillhub / generic
- **Bilingual reporting** (`--lang zh|en`, auto-detects from `$LC_ALL` / `$LANG`)
- **Zero hard dependencies** — Python 3.8+ stdlib only; PyYAML optional
- **Pure auditor** — never edits your files, never publishes

→ Read [`skills/skill-release-audit/README.md`](skills/skill-release-audit/README.md) for details.

## Install

### Via clawhub.com

```bash
# requires clawhub CLI
clawhub install glic-check
```

### Via skills.sh

```bash
npx skills install glic-check
```

### Via git clone

```bash
git clone https://github.com/Songhonglei/build-better-skills.git
# then point your agent at skills/glic-check/
```

## Compatibility

These skills follow the
[Anthropic Skills spec](https://docs.claude.com/en/docs/build-with-claude/skills)
and run in any compatible agent runtime:

- [Claude Code](https://docs.claude.com/en/docs/agents/claude-code)
- [OpenClaw](https://docs.openclaw.ai)
- [Cursor](https://cursor.sh) (via custom skills)
- Any other agent framework that supports the Skills spec

## License

MIT — see [LICENSE](./LICENSE).

## Author

Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
