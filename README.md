# build-better-skills

> A suite of open-source skills that help you build better skills —
> from creation through install, audit, release, regression testing, and sediment.

Skills are how AI agents extend their own capabilities. As skill ecosystems
mature, building good skills is itself a discipline: writing clear triggers,
keeping doc/code in sync, catching regressions, signing releases, and
promoting successful workflows into reusable skills.

This suite ships one focused skill per stage of that lifecycle.

## Stages

| Stage | Skill | Description |
|-------|-------|-------------|
| Creation | [`skill‑creator`](https://github.com/anthropics/skills) | Upstream Anthropic skill scaffolder — the &quot;raw&quot; building block. |
| **Creation** | **[`skill‑build‑wizard`](skills/skill-build-wizard/)** | Guided 4-stage workflow built on skill-creator — pre-flight → spec → coding → release. |
| **Install** | **[`skill‑hub‑united`](skills/skill-hub-united/)** | One installer for every skill hub. |
| **Install** | **[`skill‑hub‑query`](skills/skill-hub-query/)** | Search, install, edit any compatible hub via API. |
| **Audit** | **[`glic‑check`](skills/glic-check/)** | Fast 4-/5-dimension quality review after every edit. |
| **Audit** | **[`skill‑deep‑audit`](skills/skill-deep-audit/)** | Deep 7-dimension scorecard on a 115-point scale. |
| **Audit** | **[`skill‑release‑audit`](skills/skill-release-audit/)** | Final mechanical gate before publish — no LLM, no network. |
| **Release** | **[`skill‑sign`](skills/skill-sign/)** | Ed25519 signature proves authorship and integrity. |
| **Release** | **[`skill‑release‑plus`](skills/skill-release-plus/)** | Sign, pack, and fan-out publish to many hubs in one command. |
| **Documentation** | **[`skill‑introduction`](skills/skill-introduction/)** | Auto-generate a polished HTML intro page for any skill. |
| **Testing** | **[`skill‑regression`](skills/skill-regression/)** | End-to-end regression testing with script + LLM-as-judge. |
| **Sediment** | **[`skill‑sediment`](skills/skill-sediment/)** | Distill successful conversations into auto-generated SKILL.md, then promote them into `skills/`. |

## skill-hub-united (install · fetch)

One installer for multiple skill hubs — picks the right source from how the
request is phrased, and lets you plug in your own private hub.

- **Sources**: clawhub (default), skillhub.cn, skills.sh, the official
  `anthropics/skills` repo, and a configurable self-hosted `custom` hub
  (`SKILL_HUB_CUSTOM_URL`)
- Structured exit codes for name conflicts, license gating, multi-skill repos,
  and missing custom-hub config
- Path-traversal-safe extraction and strict slug validation

→ Read [`skills/skill-hub-united/README.md`](skills/skill-hub-united/README.md) for details.

## skill-hub-query (install · manage)

Deep CRUD against a single target Hub via a documented compatible API
contract. Use this when you operate a private / self-hosted Hub or want to
manage your own published skills.

- **Configurable**: every endpoint, auth header, and credentials path
  overridable via env vars (XDG-compliant by default)
- **Dual-channel**: authenticated OpenAPI path with token; legacy
  unauthenticated fallback without
- **Local cache (jq, sub-ms queries)**: full + incremental sync with safe
  server-side `updatedAt` cursor
- **Safe install**: path-traversal-safe zip extract, atomic whole-dir replace,
  rollback on failure
- **Five-stage safe `edit.sh`**: GET -> diff -> backup -> PUT -> dual-channel
  verify with retry -> auto-rollback

→ Read [`skills/skill-hub-query/README.md`](skills/skill-hub-query/README.md) for details.

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

## skill-sign (release · cryptographic signature)

Sign and verify skill directories with Ed25519 — so recipients can verify
authenticity and detect tampering, even on machines that never met the author.

- **Real public-key cryptography** — not just a SHA-256 hash. Recipients
  verify with your public key (safe to share); only you hold the private key.
- **Pure Python, zero `pip install`** — ships a vendored RFC 8032
  Appendix A reference implementation (public domain).
- **XDG-compliant key storage** at `~/.config/skill-sign/` with chmod 600.
- **Two verification modes**: self-verify (detects tampering) and
  trust-verify (detects tampering + author substitution).

→ Read [`skills/skill-sign/README.md`](skills/skill-sign/README.md) for details.

## skill-release-plus (release · multi-hub publisher)

Sign → Pack → Publish to **multiple skill hubs in one command**. Pluggable
adapter framework lets you target any custom hub via a user-hook script.

- **3 real adapters**: clawhub.com (CLI wrap), skillhub.cn (Tencent
  Bearer multipart), GitHub Releases (git + REST API)
- **`--target user-hook:./script.sh`** for any custom hub (subprocess + JSON envelope)
- **Single source of truth**: one `exclude.json` + one signing pass +
  one tar.gz, fan out to N targets
- **Fail-open dispatch**: one target's failure does not block others
- **Rate-limit aware** (skillhub.cn 429 auto-retry); **stdlib-only** (PyYAML optional)

→ Read [`skills/skill-release-plus/README.md`](skills/skill-release-plus/README.md) for details.

## skill-regression (testing · end-to-end regression suite)

A regression testing framework for skills: analyze a target skill, run
script-layer assertions and AI-layer semantic scoring, output a Markdown
report — in one pipeline.

- **Dual backend** auto-detected:
  - `api` — any OpenAI-compatible LLM acts as the agent following SKILL.md
    (stateless, works anywhere)
  - `openclaw` — real OpenClaw agent end-to-end via cron probe job
    (when `openclaw` CLI is present)
- **TEST.md format** with placeholders (`{SKILL_DIR}`, `{TESTRES_DIR}`,
  `{WORK_DIR}`) for scriptable assertions
- **LLM-as-judge** scoring (0-10, configurable threshold) for semantic match
- **Interactive onboarding** + `.env` support (private `SR_*` namespace)
- **`--rerun` failures only**, **`--detail`** mode, **upload hook** for reports

→ Read [`skills/skill-regression/README.md`](skills/skill-regression/README.md) for details.

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

