# GLIC / UGLIC Check Examples

Real-world examples demonstrating the expected quality and style. Project
and skill names are anonymized; the structure, severity logic, and citation
style are real.

---

## Example 1: Code Check — `send_message.py` card-rendering refactor

Target: `send_message.py` recent changes (card entity creation + broadcast path)

### G — Grammar
✅ No issues
- Private function `_get_or_create_card_entity` follows project's underscore-prefix convention
- Constant `CARD_ENTITY_CACHE` is uppercase, consistent with `SEND_LOG_FILE` etc.
- `nonlocal card_schema_str` usage is correct

### L — Logic
⚠️ **L1: Possible duplicate entity creation on retry?**
`do_send` checks `if args.card_id and card_schema_str is None` to decide whether to create the entity. On retry `card_schema_str` is no longer `None` (assigned on first attempt), so no duplication — but the correctness depends on a `nonlocal` side effect, which is a maintenance risk.

⚠️ **L2: `card_schema_str` may leak state across batch recipients**
`card_schema_str` is set via `nonlocal` on the first recipient and reused for the rest. Fine for the current "same card to everyone" requirement, but will break if a future feature wants "per-recipient cards".

### I — Integrity
❌ **I1: SKILL.md does not match code behavior**
SKILL.md example shows `--card-schema` accepting a full Schema JSON, but the code now expects only the `bizData` dynamic payload. Users following the doc will pass the wrong value.

❌ **I2: Parameter description table is stale**
The `--card-schema` parameter description still uses the old semantics.

⚠️ **I3: Card-entity cache has no expiry**
`card_entity_cache.json` is never invalidated; after a schema update, stale `entityId` will silently render the wrong card.

### C — Containment
⚠️ **C1: `args.ref_id = ""` mutates `args` in place**
Consistent with elsewhere in the codebase, but the side effect reaches the entire call chain.

## Summary
| # | Dim | Issue | Severity |
|---|-----|-------|----------|
| L1 | Logic | nonlocal side effect carries retry correctness | ⚠️ WARN |
| L2 | Logic | nonlocal batch-send state reuse risk | ⚠️ WARN |
| I1 | Integrity | SKILL.md example out of sync with code | ❌ ERR |
| I2 | Integrity | SKILL.md parameter table out of sync | ❌ ERR |
| I3 | Integrity | Cache has no invalidation | ⚠️ WARN |
| C1 | Containment | `args.ref_id = ""` mutates global state | ⚠️ WARN |

**Must fix: I1, I2 (SKILL.md doc alignment)**

---

## Example 2: Skill Check — `copy-my-profile`

Target: `skills/copy-my-profile/` entire directory

### G — Grammar
❌ **G1: frontmatter description mixes quote styles**
description uses both straight and CJK quotes: `"I want to copy to other agents"`

### L — Logic
⚠️ **L1: Trigger phrases too broad**
"copy my profile" in description may collide with other skills' triggers; consider a qualifier.

### I — Integrity
⚠️ **I1: SKILL.md references `resources/` but the directory does not exist**
SKILL.md mentions `references/` but the directory was never created.

### C — Containment
⚠️ **C1: SKILL.md exceeds 500 lines**
Body is too long; some content should be moved to `references/`.

## Summary
| # | Dim | Issue | Severity |
|---|-----|-------|----------|
| G1 | Grammar | frontmatter mixed quotes | ❌ ERR |
| L1 | Logic | trigger may be too broad | ⚠️ WARN |
| I1 | Integrity | references nonexistent dir | ⚠️ WARN |
| C1 | Containment | SKILL.md too long | ⚠️ WARN |

**Must fix: G1**

---

## Example 3: Mixed Target — skill with scripts

Target: full skill directory (SKILL.md + send.py + scripts/)

### G — Grammar
⚠️ **G1: 4 leftover `print()` debug statements in `send.py`**
Located at `send.py:1204`, `1210`, `1245`, `1251`; switch to `logging` or remove.

### L — Logic
✅ No issues

### I — Integrity
❌ **I1: SKILL.md claims "file upload supported" but `send.py` does not handle empty files**
`send.py:892` does not check file size; an empty file causes an API error.

⚠️ **I2: `credentials.json` is in `.gitignore` but SKILL.md does not say how to obtain it**
New users following SKILL.md will hit an auth failure.

### C — Containment
⚠️ **C1: `send.py` writes runtime files under `~/.<app>/` without documenting it**
A user cleaning their home directory may delete the runtime cache and lose data.

## Summary
| # | Dim | Issue | Severity |
|---|-----|-------|----------|
| G1 | Grammar | 4 leftover `print()` | ⚠️ WARN |
| I1 | Integrity | Empty-file upload not handled | ❌ ERR |
| I2 | Integrity | How to obtain credentials not documented | ⚠️ WARN |
| C1 | Containment | Runtime file path not documented | ⚠️ WARN |

**Must fix: I1**

---

## Example 4: UGLIC Skill Check — `glic-check` itself

Target: `skills/glic-check/` entire directory. Mode: UGLIC.

### U — User Experience

⚠️ **U1: Step 4 "Severity Escalation" rules are split across multiple places**
Agents must read both step 4 (general rules) and `dimensions.md` (U-specific rules) to get the complete ERR definition. Risk: if an agent only reads the step 4 table and skips the U-specific block, U-dimension severity judgments will be inconsistent.

⚠️ **U2: Mode detection depends on the agent correctly parsing trigger phrases**
SKILL.md lists trigger phrases, but natural language is flexible ("do a uglic on this", "check this with uglic mode"). If the phrasing is outside the list, the agent may fall back to GLIC silently.

ℹ️ **U3: Closing prompt could be tighter**
Step 6's "fix these?" is concise and effective; suggest stronger wording when U has ERR items: "U-dimension ERR directly blocks the user — fix first."

### G — Grammar
✅ No issues

### L — Logic
✅ No issues

### I — Integrity
✅ No issues

### C — Containment
✅ No issues

## Summary
| # | Dim | Issue | Severity |
|---|-----|-------|----------|
| U1 | User Experience | Severity rules split, agents may miss U-specific block | ⚠️ WARN |
| U2 | User Experience | Trigger list may not cover all natural phrasings | ⚠️ WARN |
| U3 | User Experience | Closing prompt does not differentiate GLIC/UGLIC | ℹ️ INFO |

**No must-fix items.** Watch: U1, U2

---

## What These Examples Demonstrate

1. **ERR vs WARN judgment**: ERR = real breakage, doc-code drift, or user fundamentally blocked. WARN = future risk, maintainability, minor inconsistency, or user friction.
2. **Citation specificity**: Every finding cites `file:line` or section heading.
3. **Severity escalation**: Multiple related WARNs do not auto-escalate to ERR — only escalate when the same issue appears 3+ times.
4. **Dimension coverage**: Not every check produces findings. It's fine for a dimension to have zero issues.
5. **Proportionality**: Don't list 20 nits for a 50-line change. Focus on what matters. If the target is fundamentally broken, say so upfront rather than enumerating symptoms.
6. **U dimension targeting**: U is most valuable for skills and tools. On pure code/config, fewer U findings is normal — don't force findings where there is no user-facing surface.
7. **UGLIC vs GLIC**: U findings focus on the experience of using/consuming the skill, not its internal quality. U and G/L/I/C findings can overlap (e.g., a broken instruction is both an Integrity and a User issue) — cite where it matters most.
