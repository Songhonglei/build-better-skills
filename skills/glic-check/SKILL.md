---
name: glic-check
description: >
  Systematic quality check for code, skills, configs, and documents. Two
  modes — GLIC for internal quality (4 dimensions: Grammar / Logic /
  Integrity / Containment) and UGLIC adding User Experience (5 dimensions:
  U + G + L + I + C). Each finding cites file:line; severity is tagged as
  ERR / WARN / INFO with explicit escalation rules (silent-failure = ERR,
  3× repeated WARN → ERR, missing public-param doc = ERR). Use when the
  user says "GLIC check", "UGLIC check", "do a glic", "systematically
  review this", "audit my skill", "quality check this code", or any
  phrasing that asks for a multi-dimension review of code / skills /
  configs / docs.
---

# GLIC / UGLIC Check

Systematic quality review for code, skills, configs, and documents.

- **Version**: 1.0.0
- **License**: MIT
- **Author**: Evan Song · [github.com/Songhonglei](https://github.com/Songhonglei)
- **Repository**: https://github.com/Songhonglei/build-better-skills
- **Part of**: `build-better-skills` suite (creation → audit → release → regression → sediment)

## Modes

| Mode | Trigger Examples | Dimensions |
|------|-----------------|------------|
| **GLIC** | `GLIC check`, `glic`, `glic this` | G + L + I + C (4 dims) |
| **UGLIC** | `UGLIC check`, `UGLIC verify`, `uglic this` | U + G + L + I + C (5 dims) |

## Dimensions

| Dim | Name | Focus |
|-----|------|-------|
| **U** | Usability & User Experience | Two perspectives — **Agent**: executability, unambiguous instructions, declared dependencies, failure recovery; **Human**: usability, onboarding success, error communication, interaction efficiency |
| **G** | Grammar | Syntax errors, naming conventions, formatting consistency, YAML/JSON validity |
| **L** | Logic | Control flow correctness, implicit dependencies, edge cases, branch coverage |
| **I** | Integrity | Completeness, consistency, boundary handling, documentation-code alignment |
| **C** | Containment | Side effects, scope boundaries, security, backward compatibility |

**U is only active in UGLIC mode.** GLIC mode skips U entirely.

## Workflow

### 1. Determine Mode & Scope

Detect mode from the user's message:
- Message contains `UGLIC` → **UGLIC mode** (5 dimensions: U + G + L + I + C)
- Otherwise → **GLIC mode** (4 dimensions: G + L + I + C)

Then, ask or infer what to check:
- **"this change"** / **"the diff"** → `git diff` against base branch / last commit
- **"check this skill"** → entire skill directory
- **"check this code"** → specified file(s)
- **"GLIC/UGLIC verify"** → most recent changes (git diff or last touched files)
- **No target specified** → ask the user what to check

### 2. Read Target Content

Read ALL files in scope before making any judgment. Do not skim.

### 3. Execute Dimension Checks

For each active dimension, go through the checklist in `references/dimensions.md`. Adapt sub-checks to the target type (code / skill / config / document).

**GLIC mode**: Run G → L → I → C.
**UGLIC mode**: Run U → G → L → I → C.

Key rule: **Each finding must cite a specific location** (file:line or section heading).

### 4. Assign Severity

| Tag | Meaning | Action |
|-----|---------|--------|
| ❌ ERR | Functional impact, security risk, documentation misaligns with code, **user fundamentally cannot complete the core task** | Must fix |
| ⚠️ WARN | Maintainability, consistency, future-proofing, implicit risk, **user friction or confusion** | Should fix |
| ℹ️ INFO | Style preference, minor optimization, nice-to-have | Optional |

**U-dimension severity rules:**
- **ERR**: Agent cannot reliably execute the core task (ambiguous instructions, unjudgeable conditions, dead-end on failure) **or** human cannot complete the core task (missing prerequisites, no recovery path, misleading output).
- **WARN**: Agent execution has uncertainty but usually succeeds, **or** human needs extra trial-and-error or unnecessary steps.
- **INFO**: Minor wording improvements, interaction polish, nice-to-have clarity.

Severity escalation (all dimensions):
- A WARN that appears 3+ times in the same check → escalate to ERR
- An issue that could cause silent failure → always ERR
- Missing documentation for a public-facing parameter → always ERR

### 5. Produce Report

Follow `references/output-format.md` for consistent structure:

1. Title: `## GLIC Check — [target description]` (GLIC mode) or `## UGLIC Check — [target description]` (UGLIC mode)
2. One subsection per active dimension
3. Each finding numbered (U1, U2, G1, G2, L1, I1, C1...)
4. Summary table at end with all findings
5. List ERR items that require fix

Assign new numbers per dimension (reset per check).

### 6. Offer to Fix

After report, explicitly ask: ERR items should be fixed first, then WARN items. Do not fix automatically — wait for user confirmation.

## References

- **[dimensions.md](references/dimensions.md)** — Detailed sub-check criteria for each dimension. Load before starting step 3. Adapt context-specific checklists (code vs skill vs config). The U dimension checklist is at the top.
- **[output-format.md](references/output-format.md)** — Report structure template with concrete formatting rules. Includes both GLIC and UGLIC variants. Consult when producing the report in step 5.
- **[examples.md](references/examples.md)** — Real-world GLIC and UGLIC check examples. Load for reference when unsure about severity assignment or output style.

## Principles

- **Must cite location.** Never say "somewhere in the file" — give file:line.
- **Be specific, not vague.** "Naming inconsistent" is not enough — show the two conflicting names.
- **Don't nitpick.** If a finding doesn't affect function, maintainability, security, or user experience, it's not worth a report line.
- **Complexity counts.** Complex or fragile workarounds are themselves WARN-worthy, even if they work correctly.
- **Silent failure = ERR.** Any condition that could fail without visible error is always ERR.

## Part of build-better-skills

This skill is part of the [build-better-skills](https://github.com/Songhonglei/build-better-skills)
suite — a collection of skills that help you build better skills, from
creation through audit, release, regression testing, and sediment:

| Skill | Stage | What it does |
|-------|-------|--------------|
| `skill-creator` | Creation | Scaffold a new skill from intent |
| **`glic-check`** | **Audit** | **Systematic quality review (4 / 5 dimensions)** |
| `skill-regression` | Testing | End-to-end regression testing for skills |
| `skill-release` | Release | Package + publish to hubs |
| `skill-sediment` | Sediment | Promote successful workflows to skills |

(Other suite members ship in separate releases as they are open-sourced.)
