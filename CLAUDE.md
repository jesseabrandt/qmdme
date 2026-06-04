# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package does

`qmdme` generates Quarto code companions for source files in a research repo. For each `.R`, `.sql`, or `.py` file under the project root, `sync()` writes a `qmd/<mirror>/<name>.qmd` containing a user-editable prose region above an `eval=FALSE` chunk that shows the source verbatim. Code is shown, not run. The companion files are designed to live inside an existing Quarto site.

The package itself is small (~230 lines of R, two exported functions: `init()` and `sync()`).

## The sentinel contract (the load-bearing design idea)

Every generated `.qmd` has a single HTML-comment sentinel line that begins:

```
<!-- qmdme:code-below
```

Everything **above** the sentinel is user-authored prose — `sync()` preserves it byte-for-byte on re-run. Everything **at and below** the sentinel is auto-generated and replaced on every `sync()`.

Three behaviors hinge on this:
- **First sync of a source file** → write `build_full_template()`: YAML front matter + `## Notes` heading + sentinel + code chunk.
- **Re-sync of an existing companion with sentinel present** → `merge_with_sentinel()` keeps lines above the sentinel and replaces the rest with `build_code_section()`.
- **Re-sync of an existing companion with sentinel missing** → `merge_with_sentinel()` appends a fresh sentinel + code chunk to the bottom of the existing contents, the row is recorded with `action = "recovered"`, and `sync()` emits a warning so the user notices the file was repaired. `sync()` is self-healing; there is no opt-out / no "skipped" state.

If you change the sentinel format, every existing companion in every downstream project breaks. The constant lives in `R/template.R` (`SENTINEL_PREFIX`).

## Code map

- `R/sync.R` — `sync()` (exported) and `sync_one()` (per-file driver). Returns a data frame of `source/target/action` where action ∈ `created | updated | recovered`. `sync()` warns when any row is `recovered`. The `had_sentinel` check in `sync_one()` is what discriminates `updated` vs `recovered` — `merge_with_sentinel()` itself does not signal which path it took.
- `R/walk.R` — `walk_sources()` plus `IGNORE_DIRS` (`.git`, `.Rproj.user`, `renv`, `.venv`, `node_modules`, `_freeze`, `_site`, **`qmd`**). The `qmd` ignore is critical — without it sync would recurse on its own output. The pattern is matched against project-relative paths so an ancestor directory named like an ignore entry doesn't filter everything out.
- `R/template.R` — `SENTINEL_PREFIX`, `build_code_section()`, `build_full_template()`. Code chunks are written as `` ```{<lang>, eval=FALSE} `` so renders never execute source.
- `R/merge.R` — `merge_with_sentinel()`. Sentinel present → splice. Sentinel absent → append. Always returns merged contents; never `NULL`.
- `R/extensions.R` — default extension → chunk-language map (`R→r`, `sql→sql`, `py→python`) and `chunk_lang()` lookup. Users can pass a custom mapping to `sync(extensions = ...)`.
- `R/init.R` — `init()` (exported), takes `scope = c("embed", "website")`. Non-destructive: every seed file is skip-if-exists. `scope = "embed"` (default) writes only the `qmd/index.qmd` stub and prints the reminder to wire `qmd/` into an existing `_quarto.yml` — historical behavior, backward-compatible. `scope = "website"` scaffolds a standalone navigable Quarto site **rooted at `qmd/`** and prints a `quarto render qmd` hint instead.
- `R/scaffold.R` — `init_files(scope)` returns a named list of `qmd/`-relative path → file-content lines that `init()` writes. Holds the `scope = "website"` builders: `build_site_quarto_yml()` (`project: type: website` + navbar + auto sidebar + **`execute: enabled: false`** so render starts no kernel — critical, since `{python}`/`{sql}` companion chunks would otherwise make Quarto boot a Jupyter kernel even though every chunk is `eval=FALSE`), `build_site_index()`, `build_site_about()`, and the embed-mode `build_embed_index()`.

## Common commands

Use the `r-test` skill for test/document/vignette workflows. Direct equivalents:

```r
# Run all tests
devtools::test()

# Run one test file (filter matches test-*.R basenames)
devtools::test(filter = "sync")
testthat::test_file("tests/testthat/test-sync.R")

# Regenerate man/*.Rd and NAMESPACE from roxygen
devtools::document()

# Build the vignette (vignettes/qmdme.Rmd → vignettes/qmdme.html)
devtools::build_vignettes()

# Full R CMD check
devtools::check()
```

From the shell: `Rscript -e 'devtools::test()'` etc.

After editing roxygen comments, run `devtools::document()` — `man/*.Rd` and `NAMESPACE` are generated, not hand-written.

## Conventions

- Only `fs` is in `Imports` (everything else is `Suggests`). Don't reach for `dplyr`, `purrr`, `stringr`, etc. without a real reason — the package deliberately stays light.
- Paths use `fs::path*()` throughout; don't mix in `file.path()` / `paste0()`.
- User-facing output: `message()` for normal info (e.g. `init()` reminders), `warning(..., call. = FALSE)` for skipped files. No `cat()` or `print()` in non-test code.
- Tests use `withr` for tempdirs; `walk.R` and `sync.R` are designed to be run in any directory by passing `root`.
