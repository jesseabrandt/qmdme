# Decision log

Design- and model-affecting choices for this project, from **2026-06-10** forward.
Reversible choices are EXECUTE-and-logged by agents; substantive ones are routed
through `dq` → `/decisions` and recorded here on resolution. This file is the
permanent, inspectable record of *why this project is shaped the way it is*.

**Provenance note:** anything in this repo predating this log is **unattributed and
not settled** — it may be Jesse's choice or an agent's, reviewed or not. `north_star.md`
(if present) is Jesse's, as of its date. Agents: do not cite pre-log code or structure
as "already decided" — promote load-bearing pre-log choices through `dq` (substantive)
or `dlog` (reversible) before building on them.
See `~/workspace/docs/decision-log.md` for the convention.

---

## 2026-06-10 — Add pkgdown site with minimal config
- **Choice:** Minimal _pkgdown.yml (bootstrap 5 template, url set to conventional GitHub Pages address https://jessebrandtdata.github.io/qmdme/); let pkgdown auto-generate reference (only init/sync exported, internal fns are @keywords internal so excluded from index), articles from the vignette, news from NEWS.md, home from README. Added _pkgdown.yml/docs/pkgdown to .Rbuildignore; docs/ already gitignored so build output is not committed.
- **Why:** Standard pkgdown 2.x conventions need no custom config for a 2-function package; keeping it minimal avoids bikeshedding layout. URL is canonical-link metadata only and is reversible; actual Pages publishing stays Jesse-gated.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-10 — Existing-site wiring: read-only wire() detector
- **Choice:** Added one new exported function wire() (provisional name) that detects the site at the project root (root _quarto.yml / standalone qmd/ site / pkgdown / R Markdown / none) and prints the exact file + key to add qmd under, or points at init(scope='website'). It is READ-ONLY: never edits or creates files; returns detection (type/file/wired) invisibly. init()'s vague embed message now hands off to wire().
- **Why:** Jesse's friction was vague guidance + manual YAML spelunking. Detection+precise guidance is the floor he asked for; one read-only export keeps the surface minimal (r-package-ux) and composes as init->sync->wire. Auto-editing an existing _quarto.yml in place is deliberately NOT done — safe in-place YAML editing needs a parser/new dep and risks corrupting a hand-maintained config; website scope already covers the create-a-site path.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-10 — Build-ignore DECISIONS.md
- **Choice:** Added ^DECISIONS\.md$ to .Rbuildignore
- **Why:** DECISIONS.md is workspace governance, not package content; it tripped a single R CMD check NOTE (non-standard top-level file). Ignoring it keeps check at 0/0/0.
- **Reversible:** yes · **Decided by:** agent
