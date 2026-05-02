#' Generate or update Quarto code companions for source files
#'
#' For each source file matching `extensions`, writes or updates a
#' corresponding `qmd/<mirror>/<name>.qmd` file. Existing companion files
#' have their auto-generated code section refreshed; user-authored prose
#' above the sentinel is preserved. Companion files without a sentinel are
#' skipped with a warning.
#'
#' @param paths Character vector of paths under `root` to narrow scope, or
#'   `NULL` (default) to walk the whole project. Each path is recursed.
#' @param extensions Named character vector mapping file extension to
#'   Quarto chunk-language tag, or `NULL` (default) to use the package
#'   default `c(R = "r", sql = "sql", py = "python")`.
#' @param root Project root. Defaults to the current directory.
#' @return Invisibly, a data frame with one row per source file with
#'   columns `source`, `target`, `action` (`"created"`, `"updated"`, or
#'   `"skipped-no-sentinel"`).
#' @export
sync <- function(paths = NULL, extensions = NULL, root = ".") {
  if (is.null(extensions)) extensions <- qmdme_default_extensions()
  files <- walk_sources(root, paths, extensions)
  if (length(files) == 0) {
    return(invisible(empty_sync_result()))
  }
  rows <- lapply(files, sync_one, extensions = extensions, root = root)
  result <- do.call(rbind, rows)
  skipped <- result[result$action == "skipped-no-sentinel", , drop = FALSE]
  if (nrow(skipped) > 0) {
    warning("Skipped ", nrow(skipped), " file(s) with no sentinel: ",
            paste(skipped$target, collapse = ", "), call. = FALSE)
  }
  invisible(result)
}

#' @keywords internal
empty_sync_result <- function() {
  data.frame(source = character(0), target = character(0),
             action = character(0), stringsAsFactors = FALSE)
}

#' Sync a single source file
#' @keywords internal
sync_one <- function(source_path, extensions, root) {
  rel <- fs::path_rel(source_path, root)
  ext <- fs::path_ext(source_path)
  lang <- chunk_lang(ext, extensions)
  code <- paste(readLines(source_path, warn = FALSE), collapse = "\n")
  target <- fs::path(root, "qmd", fs::path_ext_set(rel, "qmd"))
  fs::dir_create(fs::path_dir(target))

  if (!fs::file_exists(target)) {
    contents <- build_full_template(source_path = rel, lang = lang,
                                    code = code)
    writeLines(contents, target, sep = "")
    return(row_result(source_path, target, "created"))
  }

  existing <- paste(readLines(target, warn = FALSE), collapse = "\n")
  new_section <- build_code_section(lang = lang, code = code)
  merged <- merge_with_sentinel(existing, new_section)
  if (is.null(merged)) {
    return(row_result(source_path, target, "skipped-no-sentinel"))
  }
  writeLines(merged, target, sep = "")
  row_result(source_path, target, "updated")
}

#' @keywords internal
row_result <- function(source, target, action) {
  data.frame(source = as.character(source), target = as.character(target),
             action = action, stringsAsFactors = FALSE)
}
