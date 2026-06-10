#' Connect the `qmd/` companions to your existing Quarto site
#'
#' After `init()` and `sync()` you have a `qmd/` directory full of companion
#' pages. `wire()` edits your project's root `_quarto.yml` so those companions
#' show up in the site -- you don't have to go spelunking through YAML to find
#' the right key.
#'
#' `wire()` edits **only when an edit is actually needed**, which keeps it
#' honest about how Quarto works:
#'
#' * If the site has an explicit sidebar `contents:` list that omits `qmd`,
#'   `wire()` adds `qmd` to it.
#' * If the `project:` block has an explicit `render:` allowlist that omits
#'   `qmd`, `wire()` adds `qmd/*.qmd` to it.
#' * If the site already surfaces `qmd` automatically -- an `auto` sidebar or no
#'   `render:` restriction, the common minimal config -- there is nothing to do,
#'   and `wire()` says so without touching the file.
#'
#' When there is no root `_quarto.yml` to edit (a standalone `qmd/` site, a
#' pkgdown / R Markdown site, or no site at all), `wire()` does not edit
#' anything; it explains the situation and points you at
#' `init(scope = "website")`.
#'
#' **Comments and formatting.** The edit is a `yaml` read-modify-write, and the
#' `yaml` package does not preserve comments or exact formatting. `wire()`
#' therefore writes a `_quarto.yml.bak` backup before editing (disable with
#' `backup = FALSE`) so your original is never lost. If your `_quarto.yml` is
#' heavily commented, prefer to add `qmd` by hand.
#'
#' @param path Project root. Defaults to the current directory.
#' @param backup Write a `_quarto.yml.bak` copy before editing? Default `TRUE`.
#' @return Invisibly, a list: `type` (the detected site type), `file` (the
#'   config edited or inspected, or `NA`), `changed` (`TRUE` if `wire()` wrote a
#'   change), and `backup` (path to the backup written, or `NA`).
#' @examples
#' proj <- file.path(tempdir(), "qmdme-wire")
#' dir.create(proj, showWarnings = FALSE)
#' writeLines(c("project:", "  type: website", "website:", "  sidebar:",
#'              "    contents:", "      - index.qmd"),
#'            file.path(proj, "_quarto.yml"))
#' wire(proj)
#' readLines(file.path(proj, "_quarto.yml"))
#' @seealso [init()] to scaffold `qmd/`, [sync()] to generate companions.
#' @export
wire <- function(path = ".", backup = TRUE) {
  site <- detect_site(path)

  if (site$type != "quarto") {
    for (line in init_site_guidance(site)) message(line)
    return(invisible(wire_result(site$type, site$file, FALSE, NA_character_)))
  }

  edit <- plan_quarto_edit(site$file)
  if (!edit$changed) {
    message(edit$message)
    return(invisible(wire_result("quarto", site$file, FALSE, NA_character_)))
  }

  bak <- NA_character_
  if (backup) {
    bak <- paste0(site$file, ".bak")
    fs::file_copy(site$file, bak, overwrite = TRUE)
  }
  yaml::write_yaml(edit$yml, site$file)
  message(edit$message,
          if (backup) sprintf(" (backup: %s)", fs::path_file(bak)) else "",
          "\nNote: writing the config drops YAML comments and reformats it",
          if (backup) "; the original is in the .bak file." else ".")
  invisible(wire_result("quarto", site$file, TRUE, bak))
}

#' @keywords internal
wire_result <- function(type, file, changed, backup) {
  list(type = type, file = as.character(file), changed = changed,
       backup = as.character(backup))
}

#' Work out whether and how to edit a root `_quarto.yml`
#'
#' Parses the config and returns a list with `changed` (logical), the modified
#' `yml` (when `changed`), and a human-readable `message`. Pure: decides the
#' edit but does not write it. See [wire()] for the rules.
#' @keywords internal
plan_quarto_edit <- function(quarto_yml) {
  if (quarto_references_qmd(quarto_yml)) {
    return(list(changed = FALSE, yml = NULL,
                message = "`qmd` is already referenced in _quarto.yml -- nothing to change."))
  }

  yml <- yaml::read_yaml(quarto_yml)
  changed <- FALSE
  did <- character(0)

  # 1. Explicit sidebar contents list that omits qmd -> add it. `contents: auto`
  # is Quarto's "list every page yourself? no, auto-generate" keyword, so the
  # companions already appear -- leave it alone.
  contents <- yml[["website"]][["sidebar"]][["contents"]]
  if (is_simple_list(contents) && !identical(as.character(contents), "auto")) {
    yml[["website"]][["sidebar"]][["contents"]] <-
      c(as.list(contents), "qmd")
    changed <- TRUE
    did <- c(did, "the sidebar")
  }

  # 2. Explicit project render allowlist that omits qmd -> add it.
  render <- yml[["project"]][["render"]]
  if (is_simple_list(render)) {
    yml[["project"]][["render"]] <- c(as.list(render), "qmd/*.qmd")
    changed <- TRUE
    did <- c(did, "the render list")
  }

  if (!changed) {
    return(list(changed = FALSE, yml = NULL,
                message = paste0(
                  "Your site already surfaces `qmd` automatically (auto ",
                  "sidebar / no render restriction) -- nothing to change. ",
                  "Run `quarto render`.")))
  }
  list(changed = TRUE, yml = yml,
       message = sprintf("Added `qmd` to %s in _quarto.yml.",
                         paste(did, collapse = " and ")))
}

#' Is `x` a flat list/vector of scalars (a YAML sequence we can append to)?
#'
#' `yaml::read_yaml` returns a sequence of scalars as a character vector or a
#' list of length-1 atoms. A sequence containing maps (nested `section:` /
#' `contents:` structures) comes back as a list with non-scalar elements -- we
#' leave those alone rather than risk mangling a hand-built nav tree.
#' @keywords internal
is_simple_list <- function(x) {
  if (is.null(x)) return(FALSE)
  if (is.character(x) && length(x) >= 1) return(TRUE)
  is.list(x) && length(x) >= 1 &&
    all(vapply(x, function(e) is.atomic(e) && length(e) == 1, logical(1)))
}
