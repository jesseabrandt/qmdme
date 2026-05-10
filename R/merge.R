#' Replace everything from the sentinel line down with a fresh code section
#'
#' Preserves user-authored prose above the sentinel verbatim. If the sentinel
#' is missing (e.g. the user deleted it), the fresh code section is appended
#' to the end of the existing contents so `sync()` is self-healing.
#'
#' @param existing Current file contents (single string).
#' @param new_section New code section, including its sentinel line.
#' @return Merged file contents.
#' @keywords internal
merge_with_sentinel <- function(existing, new_section) {
  lines <- strsplit(existing, "\n", fixed = TRUE)[[1]]
  hit <- which(startsWith(lines, SENTINEL_PREFIX))
  if (length(hit) == 0) {
    sep <- if (nzchar(existing)) "\n\n" else ""
    return(paste0(existing, sep, new_section))
  }
  prose_lines <- if (hit[1] == 1) character(0) else lines[seq_len(hit[1] - 1)]
  paste0(
    paste(prose_lines, collapse = "\n"),
    if (length(prose_lines) > 0) "\n" else "",
    new_section
  )
}
