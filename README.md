# qmdme

Generate Quarto code companions for the source files in a research repository.

For each `.R`, `.sql`, or `.py` file, `qmdme::sync()` writes a
`qmd/<mirror>/<name>.qmd` containing a user-editable prose region above
an `eval=FALSE` chunk that shows the source code verbatim. Code is shown,
not run. The companions are intended to ride along inside an existing
Quarto site so collaborators can read the project's code with light
human framing.

## Install

```r
# install.packages("remotes")
remotes::install_github("jessebrandtdata/qmdme")
```

## Use

```r
library(qmdme)
qmdme::init()    # one-time per project: scaffold qmd/ (detects your site, tells you the next step)
qmdme::sync()    # whenever sources change: generate companions
qmdme::wire()    # edit your _quarto.yml so the companions show up in the site
```

`init()` detects what kind of site you have and tells you what to do next.
`wire()` then does it: it edits your root `_quarto.yml` to point at the `qmd/`
folder — no manual YAML spelunking — but only when an edit is actually needed
(an explicit sidebar `contents:` list or a `render:` allowlist that omits
`qmd`; a minimal site already surfaces the companions automatically). It backs
the config up to `_quarto.yml.bak` first. If there's no site, `init()` and
`wire()` both point you at `init(scope = "website")` (below).

By default `init()` seeds a single `qmd/index.qmd` stub to wire into an
*existing* Quarto site. To instead scaffold a self-contained, navigable Quarto
website rooted at `qmd/` (its own `_quarto.yml` with a navbar and an auto
sidebar that lists every companion), pass `scope = "website"`:

```r
qmdme::init(scope = "website")
qmdme::sync()
# quarto render qmd      # builds qmd/_site
```

See `vignette("qmdme")` for the full walkthrough.
