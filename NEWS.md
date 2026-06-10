# qmdme 0.0.0.9000

* New `wire()` (provisional name) detects the kind of site at the project root
  — a root `_quarto.yml`, a standalone `qmd/` Quarto site, a pkgdown or
  R Markdown site, or none — and tells you exactly which file and key to point
  at the `qmd/` folder, or points you at `init(scope = "website")` when there is
  no Quarto site to wire into. It is read-only (never edits or creates files)
  and returns its findings (`type`, `file`, `wired`) invisibly. `init()`'s
  embed-mode message now hands off to `wire()` instead of the old vague
  "wire `qmd/` into your `_quarto.yml`" line.

* `init()` gains a `scope` argument (`"embed"` or `"website"`). The default
  `"embed"` preserves the previous behavior, seeding only a `qmd/index.qmd`
  stub for an existing Quarto site. `scope = "website"` scaffolds a
  self-contained, navigable Quarto website rooted at `qmd/`: a `_quarto.yml`
  (`project: type: website` with a navbar and an auto sidebar that lists every
  companion), a landing `index.qmd`, and an `about.qmd` starter page. All seed
  files are skip-if-exists, so the new mode is additive and non-destructive.
  The scaffold sets `execute: enabled: false` so `quarto render` starts no
  language kernel — companions are display-only `eval=FALSE` chunks.
