# qmdme 0.0.0.9000

* `init()` gains a `scope` argument (`"embed"` or `"website"`). The default
  `"embed"` preserves the previous behavior, seeding only a `qmd/index.qmd`
  stub for an existing Quarto site. `scope = "website"` scaffolds a
  self-contained, navigable Quarto website rooted at `qmd/`: a `_quarto.yml`
  (`project: type: website` with a navbar and an auto sidebar that lists every
  companion), a landing `index.qmd`, and an `about.qmd` starter page. All seed
  files are skip-if-exists, so the new mode is additive and non-destructive.
  The scaffold sets `execute: enabled: false` so `quarto render` starts no
  language kernel — companions are display-only `eval=FALSE` chunks.
