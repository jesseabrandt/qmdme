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

## 2026-06-10 — wire() becomes a doer: yaml read-modify-write with backup
- **Choice:** Reworked per Jesse's PR#2 correction. wire() (was read-only) now EDITS the root _quarto.yml to add qmd to website.sidebar.contents and project.render (when those are explicit lists), via yaml read_yaml/write_yaml round-trip; writes _quarto.yml.bak first (backup=TRUE default). Detection stays on lightweight readLines/grep; yaml used only for the edit. Added yaml to Imports (Jesse pre-verified installed).
- **Why:** Jesse: 'wire should make edits ... if we do export wire() it should make the changes.' yaml round-trip is robust across YAML shapes where textual insertion is fragile; cost is dropped comments, mitigated by default backup + honest messaging. Comment-dropping flagged in PR per Jesse's instruction.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-10 — init() auto-detects site and instructs; sync() warns suppressibly
- **Choice:** Auto-detect + exact instructions moved into init() (embed mode prints a detection-driven next-step: run wire() for a quarto site, init(scope=website) for none/pkgdown). sync() gains warn_no_site = getOption('qmdme.warn_no_site', TRUE) and fires a suppressible warning when companions aren't connected to a site. detect_site()+guidance moved to R/detect.R, shared by init/sync/wire.
- **Why:** Jesse: 'auto-detect/instructions should happen on init(); possibly also fire a warning on sync() which user should be able to turn off.' Single option-backed arg serves both per-call and global off-switch, idiomatic R.
- **Reversible:** yes · **Decided by:** agent

## 2026-07-29 — Installable under the exolaunch palace catalog (SOFTWARE)
- **Choice:** Added a repo-root executable `deploy-hook` and a committed `.exolaunch.json` so qmdme installs under the exolaunch palace catalog SOFTWARE contract (approved by Jesse 2026-07-29, delegated via thread coord1). The hook runs `remotes::install_local(getwd(), upgrade = "never", force = TRUE)` — chosen over `R CMD INSTALL` because it resolves the DESCRIPTION Imports (fs, yaml) rather than failing on them, and over a plain install because the dev version `0.0.0.9000` never bumps, so `force = TRUE` is required for palace-cd's re-run-on-deploy to actually land new code. No unit ships, so the catalog installs qmdme as SOFTWARE (pull-only `-` row, no systemctl). `.exolaunch.json` (`format: exolaunch-project`) declares two dev run targets, `test` (`devtools::test()`) and `document` (`devtools::document()`), matching the repo's documented devtools workflow. Both files are build-ignored (`^deploy-hook$`, `^\.exolaunch\.json$`) so `R CMD check` stays 0/0/0.
- **Why:** Palace catalog installability was the ask. `remotes::install_local` is the smallest robust install that self-heals dependencies on a fresh box; `R CMD INSTALL` would have needed deps pre-provisioned. Verified end-to-end: `R CMD build` + `R CMD INSTALL` clean from a fresh checkout, the deploy-hook installs qmdme on a bare R 4.6.1 library, and the full test suite passes (86 tests / 209 assertions, 0 failures).
- **Reversible:** yes · **Decided by:** agent
