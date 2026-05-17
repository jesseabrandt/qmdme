#' Generate or update Quarto code companions for source files
#'
#' For each source file matching `extensions`, writes or updates a
#' corresponding `qmd/<mirror>/<name>.qmd` file. Existing companion files
#' have their auto-generated code section refreshed; user-authored prose
#' above the sentinel is preserved. If a companion file is missing its
#' sentinel (e.g. it was edited away), a fresh code section is appended
#' to the bottom and `sync()` issues a warning so the user notices.
#'
#' @param paths Character vector of paths under `root` to narrow scope, or
#'   `NULL` (default) to walk the whole project. Each path is recursed.
#' @param extensions Named character vector mapping file extension to
#'   Quarto chunk-language tag, or `NULL` (default) to use the package
#'   default `c(R = "r", sql = "sql", py = "python")`.
#' @param root Project root. Defaults to the current directory.
#' @return Invisibly, a data frame with one row per source file with
#'   columns `source`, `target`, `action` (`"created"`, `"updated"`, or
#'   `"recovered"`).
#' @export
sync <- function(paths = NULL, extensions = NULL, root = ".") {
  if (is.null(extensions)) extensions <- qmdme_default_extensions()
  files <- walk_sources(root, paths, extensions)
  if (length(files) == 0) {
    return(invisible(empty_sync_result()))
  }
  rows <- lapply(files, sync_one, extensions = extensions, root = root)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(invisible(empty_sync_result()))
  }
  result <- do.call(rbind, rows)
  recovered <- result[result$action == "recovered", , drop = FALSE]
  if (nrow(recovered) > 0) {
    warning("Re-appended code section in ", nrow(recovered),
            " file(s) with no sentinel:\n  - ",
            paste(recovered$target, collapse = "\n  - "), call. = FALSE)
  }
  invisible(result)
}

# Result schema for sync(): columns `source` (chr), `target` (chr),
# `action` (chr in {"created", "updated", "recovered"}).
#' @keywords internal
empty_sync_result <- function() {
  data.frame(source = character(0), target = character(0),
             action = character(0), stringsAsFactors = FALSE)
}

#' Sync a single source file
#'
#' Returns a one-row result data frame, or `NULL` if the source resolves to
#' a target that would escape `<root>/qmd/` (in which case a warning is
#' emitted and the file is skipped).
#' @keywords internal
sync_one <- function(source_path, extensions, root) {
  rel <- fs::path_rel(source_path, root)
  ext <- fs::path_ext(source_path)
  lang <- chunk_lang(ext, extensions)
  code <- paste(readLines(source_path, warn = FALSE), collapse = "\n")
  target <- fs::path_norm(fs::path(root, "qmd", fs::path_ext_set(rel, "qmd")))

  if (!target_under_qmd(target, root)) {
    warning("Skipping source whose target escapes qmd/: ", source_path,
            call. = FALSE)
    return(NULL)
  }
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
  writeLines(merged$contents, target, sep = "")
  row_result(source_path, target,
             if (merged$had_sentinel) "updated" else "recovered")
}

#' @keywords internal
row_result <- function(source, target, action) {
  data.frame(source = as.character(source), target = as.character(target),
             action = action, stringsAsFactors = FALSE)
}

#' Is `target` under `<root>/qmd/`?
#'
#' Compares normalized absolute paths. `target` may not exist yet, so we don't
#' use `fs::path_real()` on it; instead we normalize `..` segments and then
#' check prefix-containment under the real path of `<root>/qmd`. The qmd root
#' itself is guaranteed to exist (created by `init()` or on first write).
#' @keywords internal
target_under_qmd <- function(target, root) {
  qmd_root <- fs::path(root, "qmd")
  if (!fs::dir_exists(qmd_root)) fs::dir_create(qmd_root)
  rq <- as.character(fs::path_real(qmd_root))
  abs_target <- as.character(fs::path_norm(fs::path_abs(target)))
  abs_target == rq || startsWith(abs_target, paste0(rq, "/"))
}
