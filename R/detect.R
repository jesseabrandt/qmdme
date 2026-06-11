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
#' Looks for the `qmd` *directory* appearing as a navigation/render **sequence
#' element** -- a `- qmd` list item, a `qmd/...` path item, or an inline
#' `[qmd, ...]` flow entry. Deliberately strict, for two reasons:
#'
#' * It must **not** match a `.qmd` *filename* like `index.qmd` (the extension
#'   ends in "qmd"), which would make every contents list look already-wired.
#' * It must **not** be fooled by `qmd` appearing as a mapping *value*
#'   (`output-dir: qmd`), inside a hyphenated identifier (`analysis-qmd-v2.R`),
#'   or in a YAML comment (`# - qmd`) -- each of those used to read as
#'   "already wired" and silently disable [wire()] and [sync()]'s warning.
#'
#' Stays textual (no YAML parse) so it never throws on a malformed config and
#' is cheap enough for [sync()] to call on every run. Biased toward
#' under-matching: a missed reference makes `wire()`/`sync()` louder (offer to
#' wire, warn), which is recoverable, whereas a false match fails silently.
#' @keywords internal
quarto_references_qmd <- function(quarto_yml) {
  lines <- strip_yaml_comments(readLines(quarto_yml, warn = FALSE))
  any(vapply(lines, line_references_qmd, logical(1)))
}

#' Strip trailing `# ...` comments from YAML lines
#'
#' A YAML comment is a `#` at line start or preceded by whitespace; a `#` glued
#' to non-space (e.g. inside a URL fragment) is not a comment. Best-effort: does
#' not track multi-line quoted scalars, which `_quarto.yml` nav rarely uses.
#' @keywords internal
strip_yaml_comments <- function(lines) {
  sub("(^|\\s)#.*$", "\\1", lines)
}

#' Does a single (comment-stripped) line reference `qmd` as a sequence element?
#' @keywords internal
line_references_qmd <- function(line) {
  vals <- character(0)
  trimmed <- sub("^\\s+", "", line)
  # Block sequence item: "- value" (the value, not a "- key: ..." mapping item).
  if (grepl("^-\\s+", trimmed)) {
    vals <- c(vals, sub("^-\\s+", "", trimmed))
  }
  # Flow sequence(s): comma-separated items inside [ ... ].
  for (flow in regmatches(line, gregexpr("\\[[^]]*\\]", line))[[1]]) {
    vals <- c(vals, strsplit(gsub("[][]", "", flow), ",")[[1]])
  }
  vals <- trimws(gsub("[\"']", "", vals))
  any(vals == "qmd" | startsWith(vals, "qmd/"))
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
