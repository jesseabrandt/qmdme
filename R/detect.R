# Site detection shared by init() (turns it into next-step instructions), sync()
# (turns it into a suppressible "not connected" warning), and wire() (decides
# whether and what to edit). Detection is deliberately lightweight -- readLines +
# a grep -- so it stays cheap and dependency-free; only wire()'s actual edit
# reaches for the yaml parser.

#' Inspect the project root and classify its site
#'
#' Returns a list with `type` (`"quarto"`, `"qmd_website"`, `"pkgdown"`,
#' `"rmarkdown_site"`, or `"none"`), `file` (the detected config, or `NA`), and
#' `wired` (`TRUE` when a root `_quarto.yml` already references `qmd`). Pure:
#' reads files, never writes.
#' @keywords internal
detect_site <- function(path) {
  root_quarto <- fs::path(path, "_quarto.yml")
  qmd_quarto  <- fs::path(path, "qmd", "_quarto.yml")

  if (fs::file_exists(root_quarto)) {
    return(site_result("quarto", root_quarto,
                       quarto_references_qmd(root_quarto)))
  }
  if (fs::file_exists(qmd_quarto)) {
    return(site_result("qmd_website", qmd_quarto, FALSE))
  }
  pkgdown <- fs::path(path, "_pkgdown.yml")
  if (fs::file_exists(pkgdown)) {
    return(site_result("pkgdown", pkgdown, FALSE))
  }
  rmd_site <- fs::path(path, "_site.yml")
  if (fs::file_exists(rmd_site)) {
    return(site_result("rmarkdown_site", rmd_site, FALSE))
  }
  site_result("none", NA_character_, FALSE)
}

#' Assemble a `detect_site()` result list
#' @keywords internal
site_result <- function(type, file, wired) {
  list(type = type, file = as.character(file), wired = wired)
}

#' Will the qmd companions reach this site's navigation?
#'
#' `TRUE` for a standalone `qmd/` website (it *is* the site) and for a root
#' Quarto site that already references `qmd`. Everything else -- an unwired
#' Quarto site, a pkgdown / R Markdown site, or no site -- counts as not yet
#' connected, which is what `sync()`'s warning keys off.
#' @keywords internal
site_connected <- function(site) {
  site$type == "qmd_website" || (site$type == "quarto" && site$wired)
}

#' Does a root `_quarto.yml` already reference the `qmd` directory?
#'
#' Tokenizes the config and looks for the `qmd` *directory* -- a bare `qmd`
#' token or a `qmd/...` path. Crucially this does **not** match a `.qmd`
#' *filename* like `index.qmd`, which would otherwise make every contents list
#' look already-wired (the extension ends in "qmd"). The token split is on YAML
#' punctuation (whitespace, `-`, `:`, `,`, brackets, quotes), so `qmd`,
#' `- qmd`, and `qmd/index.qmd` all count while `index.qmd` does not.
#' @keywords internal
quarto_references_qmd <- function(quarto_yml) {
  lines <- readLines(quarto_yml, warn = FALSE)
  tokens <- unlist(strsplit(lines, "[][[:space:],:\"'-]+"))
  tokens <- tokens[nzchar(tokens)]
  any(tokens == "qmd" | startsWith(tokens, "qmd/"))
}

#' Next-step instructions for `init()`, given a detected site
#'
#' `init()` scaffolds `qmd/`, then this turns the detection into a concrete
#' "here's what to do next" message: run `wire()` for an unwired Quarto site,
#' or `init(scope = "website")` when there is nothing to embed into.
#' @keywords internal
init_site_guidance <- function(site) {
  switch(site$type,
    quarto = if (site$wired) {
      c(sprintf("Found a Quarto site (%s) that already references `qmd`.",
                fs::path_file(site$file)),
        "You're set -- run `quarto render` to rebuild it.")
    } else {
      c(sprintf("Found a Quarto site: %s", fs::path_file(site$file)),
        "Run `qmdme::wire()` to connect `qmd/` to it (it edits the config",
        "for you, after backing it up).")
    },
    qmd_website = c(
      "`qmd/` is already a standalone Quarto site (qmd/_quarto.yml).",
      "Nothing to wire -- run `quarto render qmd` to build it."),
    pkgdown = ,
    rmarkdown_site = c(
      sprintf("Found a %s site (%s), which doesn't build from loose `.qmd`",
              if (site$type == "pkgdown") "pkgdown" else "R Markdown",
              fs::path_file(site$file)),
      "files. Run `qmdme::init(scope = \"website\")` for a standalone site",
      "rooted at `qmd/`."),
    none = c(
      "No website found at the project root.",
      "Run `qmdme::init(scope = \"website\")` to make `qmd/` a standalone,",
      "navigable Quarto site, or wire `qmd/` into a `_quarto.yml` later with",
      "`qmdme::wire()`.")
  )
}
