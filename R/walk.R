IGNORE_DIRS <- c(".git", ".Rproj.user", "renv", ".venv", "node_modules",
                 "_freeze", "_site", "qmd")

#' List source files in scope
#'
#' Walks the project tree for files matching the configured extensions,
#' skipping standard ignore directories and the qmd output directory.
#'
#' @param root Project root directory.
#' @param paths Character vector of paths under `root` to narrow scope, or
#'   NULL to walk from `root`.
#' @param extensions Named character vector mapping extension -> chunk-lang.
#' @return Character vector of absolute file paths.
#' @keywords internal
walk_sources <- function(root, paths, extensions) {
  search_dirs <- if (is.null(paths)) root else fs::path(root, paths)
  search_dirs <- search_dirs[fs::dir_exists(search_dirs)]
  if (length(search_dirs) == 0) return(character(0))

  ext_pattern <- paste0("\\.(", paste(names(extensions), collapse = "|"),
                        ")$")
  files <- unlist(lapply(search_dirs, function(d) {
    as.character(fs::dir_ls(d, recurse = TRUE, type = "file",
                            regexp = ext_pattern, ignore.case = TRUE))
  }))

  ignore_pattern <- paste0("(^|/)(", paste(IGNORE_DIRS, collapse = "|"),
                           ")(/|$)")
  files <- files[!grepl(ignore_pattern, files)]
  unique(files)
}
