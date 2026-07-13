# Open-Source Precedents — patterns by skill type

> Lessons distilled from open-sourcing many skills. Before open-sourcing a new one,
> skim this + the matching-type pattern below — you can cover the first ~60% of the
> work quickly.

## Patterns by skill type

| Skill type | Key teaching points |
|---|---|
| **Basic git / workspace tool** | The origin of the 11-rule strip checklist; keep path resolution env-var driven, never assume an agent-home path |
| **Environment self-check** | Add CLI design decisions + cross-platform fallbacks; frontmatter cross-agent compat often needs 2-3 iterations to settle |
| **Python + LLM tool** | Replace any internal CDN with public multi-source fallback (PyPI / mirrors); don't hardcode a single internal endpoint |
| **Session / recovery tool** | `sign.key` must be deleted (contains internal identity); scope the first version to the platforms you actually tested |
| **CLI tool with language output** | `--lang` must use locale detection, never hardcode `zh`; keep UI title vs. stored label as independent concerns |
| **Multi-agent / multi-workspace** | Great open-source positioning (attracts CC / Cursor users); agent discovery = explicit > auto-discovery-with-confirm > single-agent-skip |
| **Platform UX gap filler** | Let the user decide profile names (e.g. quick / normal / patient) rather than inventing them |
| **Pure LLM workflow (0 scripts)** | Position it as a cross-tool asset; ship import-prompt templates for each target tool |
| **P2P / networking** | Use XDG paths; stub out sync commands that need infra; fix real bugs in both internal and open versions |
| **Native platform extension** | Port tiered presets (e.g. conservative / balanced / aggressive) so users get sensible defaults |
| **Audit / check tool** | Self-check + three-tier samples surface the tool's own gaps — fix them into the next patch; a semi-automated antipattern grep script helps |

## Distilled experience

### Decisions
- **Fork vs. evolve**: internal users still depend on it → fork; only minor internal details → evolve
- **First version**: hub first release **starts at v1.0.0**, don't carry the internal number
- **Suite repos**: members release independently; the README lists a stages table (with 🚧 placeholders)

### Refactoring
- **CLI design**: env vars + flags dual-track; env vars carry a skill prefix; user-authorization flags (`--i-am-sure` / `--force` / `--yes`) are **never self-decided**
- **Cross-platform fallbacks**: depth by audience (Linux-only can skip; macOS / Windows Git Bash must do them)
- **locale detection**: don't hardcode `zh`; detect from `$LC_ALL` / `$LC_MESSAGES` / `$LANG`

### Platform behaviors
- **clawhub**: absolute path required + forces MIT-0 + no visibility param (hide/unhide)
- **GitHub over restricted network**: Basic Auth header injection (bearer no longer accepted) + retry 3-5 times on 502
- **skills.sh**: auto-synced via the GitHub repo; index lags ~24h
- **Restricted publishing envs**: never self-decide `--visibility private` as a workaround; omit the flag so the tool refills the hub's current value

### Memory notes
- After each open-source, record `memory/project_<slug>_opensource_fork.md` (chained continuity)
- Promote general lessons into `memory/feedback_*.md`, e.g.:
  - slug-collision pre-check
  - new-repo git-config-first
  - self-check uncovers tool gaps
  - cross-check audit tools before release
  - SKILL.md author/repo/license discipline
