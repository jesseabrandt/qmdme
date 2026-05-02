#' Initialize qmdme in a project
#'
#' Creates the `qmd/` output directory and a stub `qmd/index.qmd`. Both are
#' non-destructive: existing files and directories are left alone, with a
#' message naming what was skipped. Prints a one-line instruction telling
#' the user to wire `qmd/` into their `_quarto.yml` site navigation.
#'
#' @param path Project root. Defaults to the current directory.
#' @return Invisibly, the absolute path to the qmd directory.
#' @export
init <- function(path = ".") {
  qmd_dir <- fs::path(path, "qmd")
  index <- fs::path(qmd_dir, "index.qmd")

  skipped <- character(0)
  if (fs::dir_exists(qmd_dir)) {
    skipped <- c(skipped, "qmd/")
  } else {
    fs::dir_create(qmd_dir)
  }

  if (fs::file_exists(index)) {
    skipped <- c(skipped, "qmd/index.qmd")
  } else {
    writeLines(
      c("---", 'title: "Code companions"', "---", "",
        "Code companions for the source files in this project.",
        "Each `.qmd` mirrors a source file with the original code in an",
        "`eval=FALSE` chunk."),
      index
    )
  }

  if (length(skipped) > 0) {
    message("Skipped existing: ", paste(skipped, collapse = ", "))
  }
  message("Add `qmd/` to your `_quarto.yml` site navigation.")
  invisible(qmd_dir)
}
