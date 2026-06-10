# qmdme 0.0.0.9000

* Connecting `qmd/` to an existing site is now split into "detect + instruct"
  (`init()`) and "make the edit" (`wire()`):

  * `init()` (embed mode) detects the site at the project root — a root
    `_quarto.yml`, a standalone `qmd/` site, a pkgdown / R Markdown site, or none
    — and prints the concrete next step (run `wire()`, or
    `init(scope = "website")`).
  * `wire()` (provisional name) is now a **doer**: it edits the root
    `_quarto.yml` to point at `qmd/`, adding `qmd` to an explicit sidebar
    `contents:` list or `project: render:` allowlist that omits it. When the
    site already surfaces `qmd` automatically (an `auto` sidebar / no `render:`
    restriction) it changes nothing and says so. The edit is a `yaml`
    read-modify-write, which does not preserve comments or formatting, so
    `wire()` writes a `_quarto.yml.bak` backup first (`backup = FALSE` to skip).
    It returns `type`, `file`, `changed`, and `backup` invisibly. (`yaml` is now
    a hard dependency.)
  * `sync()` gains `warn_no_site` (default `getOption("qmdme.warn_no_site",
    TRUE)`): it warns when the companions aren't connected to a site yet,
    suppressible per-call or globally via the option for users who don't want a
    site.

* `init()` gains a `scope` argument (`"embed"` or `"website"`). The default
  `"embed"` preserves the previous behavior, seeding only a `qmd/index.qmd`
  stub for an existing Quarto site. `scope = "website"` scaffolds a
  self-contained, navigable Quarto website rooted at `qmd/`: a `_quarto.yml`
  (`project: type: website` with a navbar and an auto sidebar that lists every
  companion), a landing `index.qmd`, and an `about.qmd` starter page. All seed
  files are skip-if-exists, so the new mode is additive and non-destructive.
  The scaffold sets `execute: enabled: false` so `quarto render` starts no
  language kernel — companions are display-only `eval=FALSE` chunks.
