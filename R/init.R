#' Initialize qmdme in a project
#'
#' Creates the `qmd/` output directory and seeds it with starter files. All
#' writes are non-destructive: existing files and directories are left alone,
#' with a message naming what was skipped and what was created.
#'
#' Two scopes are available:
#'
#' * `"embed"` (default) writes only a stub `qmd/index.qmd`, intended to be
#'   wired into an *existing* Quarto site's navigation. This is the historical
#'   behavior.
#' * `"website"` scaffolds a self-contained, navigable Quarto website rooted at
#'   `qmd/` -- a `qmd/_quarto.yml` (`project: type: website`, with a navbar and
#'   an auto sidebar that lists the companions), a landing `index.qmd`, and an
#'   `about.qmd` starter page. The synced companions become pages of the site,
#'   which renders on its own with `quarto render qmd` and never touches a root
#'   `_quarto.yml`.
#'
#' @param path Project root. Defaults to the current directory.
#' @param scope One of `"embed"` (default) or `"website"`. `"embed"` writes
#'   only a `qmd/index.qmd` stub to wire into an existing Quarto site;
#'   `"website"` additionally writes `qmd/_quarto.yml` and `qmd/about.qmd` to
#'   make `qmd/` a standalone, navigable Quarto website. See Details.
#' @return Invisibly, the absolute path to the qmd directory.
#' @seealso [wire()] to connect `qmd/` to an existing site, [sync()] to
#'   generate companions.
#' @examples
#' # Embed mode (default): a stub qmd/index.qmd for an existing Quarto site.
#' demo <- file.path(tempdir(), "qmdme-embed")
#' dir.create(demo, showWarnings = FALSE)
#' init(demo)
#' list.files(file.path(demo, "qmd"))
#'
#' # Website mode: a self-contained, navigable Quarto site rooted at qmd/.
#' site <- file.path(tempdir(), "qmdme-site")
#' dir.create(site, showWarnings = FALSE)
#' init(site, scope = "website")
#' list.files(file.path(site, "qmd"))
#' # After qmdme::sync(), render with: quarto render qmd
#' @export
init <- function(path = ".", scope = c("embed", "website")) {
  scope <- match.arg(scope)
  qmd_dir <- fs::path(path, "qmd")

  created <- character(0)
  skipped <- character(0)

  if (fs::dir_exists(qmd_dir)) {
    skipped <- c(skipped, "qmd/")
  } else {
    fs::dir_create(qmd_dir)
    created <- c(created, "qmd/")
  }

  files <- init_files(scope)
  for (rel in names(files)) {
    target <- fs::path(qmd_dir, rel)
    label <- fs::path("qmd", rel)
    if (fs::file_exists(target)) {
      skipped <- c(skipped, label)
    } else {
      fs::dir_create(fs::path_dir(target))
      writeLines(files[[rel]], target)
      created <- c(created, label)
    }
  }

  if (length(created) > 0) {
    message("Created: ", paste(created, collapse = ", "))
  }
  if (length(skipped) > 0) {
    message("Skipped existing: ", paste(skipped, collapse = ", "))
  }
  if (scope == "website") {
    message("`qmd/` is a standalone Quarto website. ",
            "Run `quarto render qmd` to build it.")
  } else {
    message("Next: run `qmdme::wire()` to connect `qmd/` to your site ",
            "(it finds your `_quarto.yml` and tells you exactly what to add).")
  }
  invisible(qmd_dir)
}
