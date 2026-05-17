# Directories skipped during source discovery. `qmd` is the critical entry --
# sync() writes there, so without skipping it we would recurse on our own
# output. Matched against project-relative paths (see walk_sources()).
IGNORE_DIRS <- c(".git", ".Rproj.user", "renv", ".venv", "node_modules",
                 "_freeze", "_site", "qmd")

#' Escape regex metacharacters
#' @keywords internal
escape_re <- function(x) {
  gsub("([\\^$.|?*+(){}\\[\\]])", "\\\\\\1", x, perl = TRUE)
}

#' List source files in scope
#'
#' Walks the project tree for files matching the configured extensions,
#' skipping standard ignore directories and the qmd output directory.
#'
#' `paths` are validated: entries that don't resolve to a directory under
#' `root` are warned about and skipped (typos, absolute paths, `..`-escapes).
#'
#' @param root Project root directory.
#' @param paths Character vector of paths under `root` to narrow scope, or
#'   NULL to walk from `root`.
#' @param extensions Named character vector mapping extension -> chunk-lang.
#' @return Character vector of absolute file paths.
#' @keywords internal
walk_sources <- function(root, paths, extensions) {
  search_dirs <- resolve_search_dirs(root, paths)
  if (length(search_dirs) == 0) return(character(0))

  ext_pattern <- paste0("\\.(",
                        paste(escape_re(names(extensions)), collapse = "|"),
                        ")$")
  files <- unlist(lapply(search_dirs, function(d) {
    as.character(fs::dir_ls(d, recurse = TRUE, type = "file",
                            regexp = ext_pattern, ignore.case = TRUE))
  }))
  if (length(files) == 0) return(character(0))

  # Anchor IGNORE_DIRS match to project-relative paths so an ancestor directory
  # named like an ignore entry (e.g. the project rooted under a dir called
  # `qmd`) does not silently filter out every source file.
  rel <- as.character(fs::path_rel(files, root))
  ignore_pattern <- paste0("(^|/)(", paste(IGNORE_DIRS, collapse = "|"),
                           ")(/|$)")
  files <- files[!grepl(ignore_pattern, rel)]
  unique(files)
}

#' Resolve and validate the directories that `walk_sources()` should search
#'
#' Each entry in `paths` must resolve to an existing directory under `root`.
#' Non-directory entries (typos, files) and out-of-root entries (absolute
#' paths, `..`-escapes) produce a warning and are dropped.
#' @keywords internal
resolve_search_dirs <- function(root, paths) {
  if (is.null(paths)) return(root)

  candidates <- fs::path(root, paths)

  # Out-of-root check: real-path of each candidate must descend from real-path
  # of root. We resolve the *parent* if the candidate itself doesn't exist, so
  # typos and traversal escapes are both caught.
  real_root <- as.character(fs::path_real(root))
  is_under_root <- vapply(candidates, function(c) {
    parent <- if (fs::file_exists(c)) c else fs::path_dir(c)
    if (!fs::file_exists(parent)) return(FALSE)
    real <- as.character(fs::path_real(parent))
    real == real_root || startsWith(real, paste0(real_root, "/"))
  }, logical(1))
  if (any(!is_under_root)) {
    warning("Skipping paths outside root: ",
            paste(paths[!is_under_root], collapse = ", "),
            call. = FALSE)
  }
  candidates <- candidates[is_under_root]
  paths <- paths[is_under_root]
  if (length(candidates) == 0) return(character(0))

  is_dir <- fs::dir_exists(candidates)
  if (any(!is_dir)) {
    warning("Skipping paths that are not directories: ",
            paste(paths[!is_dir], collapse = ", "),
            call. = FALSE)
  }
  candidates[is_dir]
}
