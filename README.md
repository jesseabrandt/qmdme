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
remotes::install_github("jesseabrandt/qmdme")
```

## Use

```r
library(qmdme)
qmdme::init()    # one-time per project: scaffold qmd/
qmdme::sync()    # whenever sources change: generate companions
qmdme::wire()    # find out exactly how to connect qmd/ to your site
```

`wire()` inspects the project root and tells you precisely which file and key
to point at the `qmd/` folder — no manual YAML spelunking. If it finds no site,
it points you at `init(scope = "website")` (below).

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
