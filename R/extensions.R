#' Default mapping of source-file extensions to Quarto chunk-language tags
#'
#' @return Named character vector. Names are file extensions (without the dot);
#'   values are Quarto chunk-language tags.
#' @keywords internal
qmdme_default_extensions <- function() {
  c(R = "r", sql = "sql", py = "python")
}

#' Look up the Quarto chunk language for a file extension
#'
#' @param ext File extension (without the dot), case-insensitive.
#' @param extensions Named character vector of extension → chunk-lang mappings.
#' @return Single-element character vector with the chunk-language tag.
#' @keywords internal
chunk_lang <- function(ext, extensions) {
  hit <- which(tolower(names(extensions)) == tolower(ext))
  if (length(hit) == 0) {
    stop("No chunk-language mapping for extension: ", ext, call. = FALSE)
  }
  unname(extensions[hit[1]])
}
