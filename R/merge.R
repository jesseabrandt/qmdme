#' Replace everything from the sentinel line down with a fresh code section
#'
#' Preserves user-authored prose above the sentinel verbatim.
#'
#' @param existing Current file contents (single string).
#' @param new_section New code section, including its sentinel line.
#' @return Merged file contents, or NULL if no sentinel was found.
#' @keywords internal
merge_with_sentinel <- function(existing, new_section) {
  lines <- strsplit(existing, "\n", fixed = TRUE)[[1]]
  hit <- which(startsWith(lines, SENTINEL_PREFIX))
  if (length(hit) == 0) return(NULL)
  prose_lines <- if (hit[1] == 1) character(0) else lines[seq_len(hit[1] - 1)]
  paste0(
    paste(prose_lines, collapse = "\n"),
    if (length(prose_lines) > 0) "\n" else "",
    new_section
  )
}
