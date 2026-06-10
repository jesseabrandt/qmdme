#' Connect the `qmd/` companions to your site
#'
#' After `init()` and `sync()` you have a `qmd/` directory full of companion
#' pages. `wire()` looks at the project root, works out what kind of site (if
#' any) you already have, and tells you exactly what to do to make the
#' companions show up in it -- which file to edit and which key to add `qmd`
#' under -- so you never have to go spelunking through YAML to find the spot.
#'
#' `wire()` is read-only: it inspects and reports, but never edits or creates
#' files. Creating a site is [init()]'s job (`scope = "website"` scaffolds a
#' standalone site rooted at `qmd/`). Wiring `qmd/` into an *existing*
#' `_quarto.yml` is left to you on purpose -- editing a config you maintain by
#' hand is safer than having a tool rewrite it -- but `wire()` hands you the
#' precise snippet to paste.
#'
#' The site types it recognizes:
#'
#' * **`"quarto"`** -- a `_quarto.yml` at the project root. `wire()` reports
#'   whether `qmd` is already referenced and, if not, the key to add it under.
#' * **`"qmd_website"`** -- `qmd/` is already a standalone Quarto site (a
#'   `qmd/_quarto.yml`, e.g. from `init(scope = "website")`). Nothing to wire;
#'   `wire()` reminds you to `quarto render qmd`.
#' * **`"pkgdown"`** / **`"rmarkdown_site"`** -- a site that does not build from
#'   loose `.qmd` files. `wire()` points you at `init(scope = "website")`.
#' * **`"none"`** -- no site found. `wire()` points you at
#'   `init(scope = "website")`.
#'
#' @param path Project root. Defaults to the current directory.
#' @return Invisibly, a list describing what was found: `type` (one of the
#'   strings above), `file` (the detected config file, or `NA`), and `wired`
#'   (`TRUE` if `qmd` is already referenced by a root `_quarto.yml`). The same
#'   guidance printed as a message, so you can branch on it programmatically.
#' @examples
#' # A project with an existing Quarto site:
#' proj <- file.path(tempdir(), "qmdme-wire")
#' dir.create(proj, showWarnings = FALSE)
#' writeLines(c("project:", "  type: website"),
#'            file.path(proj, "_quarto.yml"))
#' wire(proj)
#'
#' # No site yet -> pointed at website mode:
#' bare <- file.path(tempdir(), "qmdme-wire-bare")
#' dir.create(bare, showWarnings = FALSE)
#' wire(bare)
#' @seealso [init()] to scaffold `qmd/`, [sync()] to generate companions.
#' @export
wire <- function(path = ".") {
  site <- detect_site(path)
  for (line in site$guidance) message(line)
  invisible(site[c("type", "file", "wired")])
}

#' Inspect the project root and describe how to connect `qmd/` to its site
#'
#' Returns a list with `type`, `file`, `wired`, and `guidance` (a character
#' vector of message lines). Pure: reads files but never writes. See [wire()]
#' for the recognized site types.
#' @keywords internal
detect_site <- function(path) {
  root_quarto <- fs::path(path, "_quarto.yml")
  qmd_quarto  <- fs::path(path, "qmd", "_quarto.yml")

  if (fs::file_exists(root_quarto)) {
    wired <- quarto_references_qmd(root_quarto)
    return(site_result("quarto", root_quarto, wired,
                       guidance_quarto(root_quarto, wired)))
  }
  if (fs::file_exists(qmd_quarto)) {
    return(site_result("qmd_website", qmd_quarto, FALSE,
                       guidance_qmd_website()))
  }
  pkgdown <- fs::path(path, "_pkgdown.yml")
  if (fs::file_exists(pkgdown)) {
    return(site_result("pkgdown", pkgdown, FALSE,
                       guidance_other("pkgdown", pkgdown)))
  }
  rmd_site <- fs::path(path, "_site.yml")
  if (fs::file_exists(rmd_site)) {
    return(site_result("rmarkdown_site", rmd_site, FALSE,
                       guidance_other("R Markdown", rmd_site)))
  }
  site_result("none", NA_character_, FALSE, guidance_none())
}

#' Assemble a `detect_site()` result list
#' @keywords internal
site_result <- function(type, file, wired, guidance) {
  list(type = type, file = as.character(file), wired = wired,
       guidance = guidance)
}

#' Does a root `_quarto.yml` already reference the `qmd` directory?
#'
#' A deliberately loose check: any line mentioning `qmd` as a path token
#' (`- qmd`, `qmd/`, `qmd/index.qmd`, ...) counts. Over-matching only makes
#' `wire()` say "already wired" when it might not be -- a benign nudge, not a
#' destructive action -- so the cheap heuristic is the right trade.
#' @keywords internal
quarto_references_qmd <- function(quarto_yml) {
  lines <- readLines(quarto_yml, warn = FALSE)
  any(grepl("(^|[^[:alnum:]_])qmd($|[^[:alnum:]_])", lines))
}

#' Guidance lines for a root `_quarto.yml`
#' @keywords internal
guidance_quarto <- function(file, wired) {
  rel <- fs::path_file(file)
  if (wired) {
    return(c(
      sprintf("Found a Quarto site (%s) that already references `qmd`.", rel),
      "You're set -- run `quarto render` to rebuild it."
    ))
  }
  c(
    sprintf("Found a Quarto site: %s", rel),
    "Add `qmd` so the companions appear in it. For a sidebar, put this under",
    "the `website:` key:",
    "",
    "  sidebar:",
    "    contents:",
    "      - qmd",
    "",
    "(If your `project:` sets an explicit `render:` list, add `- qmd` there",
    "too.) Then run `quarto render`."
  )
}

#' Guidance lines for an existing standalone `qmd/` website
#' @keywords internal
guidance_qmd_website <- function() {
  c(
    "`qmd/` is already a standalone Quarto site (qmd/_quarto.yml).",
    "Nothing to wire -- run `quarto render qmd` to build it."
  )
}

#' Guidance lines for a non-Quarto site (pkgdown / R Markdown)
#' @keywords internal
guidance_other <- function(kind, file) {
  rel <- fs::path_file(file)
  c(
    sprintf("Found a %s site (%s), which doesn't build from loose `.qmd`", kind, rel),
    "files. To publish the companions as their own site, run",
    "`qmdme::init(scope = \"website\")` for a standalone site rooted at `qmd/`."
  )
}

#' Guidance lines when no site is found
#' @keywords internal
guidance_none <- function() {
  c(
    "No website found at the project root.",
    "Run `qmdme::init(scope = \"website\")` to make `qmd/` a standalone,",
    "navigable Quarto site."
  )
}
