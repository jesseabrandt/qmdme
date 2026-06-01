#!/usr/bin/env Rscript

# End-to-end demo + smoke test for qmdme.
#
# Walks the full lifecycle against a throwaway project:
#   1. write mock R / SQL / Python sources
#   2. init()  -> qmd/ + qmd/index.qmd
#   3. sync()  -> companions created
#   4. add prose above the sentinel in each companion AND edit each source
#   5. sync()  -> prose preserved, code refreshed
# Prints what it does at every step and asserts the invariants, exiting
# non-zero if any check fails. The temp project is LEFT ON DISK so you can
# open the .qmd files and inspect them afterwards.
#
# Run from the repo root:
#   Rscript scripts/e2e.R

# --- locate and load the package under development ---------------------------

find_pkg_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    script <- normalizePath(sub("^--file=", "", file_arg[1]))
    return(dirname(dirname(script)))  # scripts/e2e.R -> repo root
  }
  normalizePath(".")  # sourced interactively; assume cwd is the repo root
}

pkg_root <- find_pkg_root()

if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(pkg_root, quiet = TRUE)  # test the current source, not an installed copy
} else {
  library(qmdme)
}

# --- tiny test/report helpers ------------------------------------------------

failures <- 0L

section <- function(title) {
  cat("\n", strrep("=", 72), "\n== ", title, "\n", strrep("=", 72), "\n",
      sep = "")
}

check <- function(label, ok) {
  cat(if (isTRUE(ok)) "  ✓ " else "  ✗ ", label, "\n", sep = "")
  if (!isTRUE(ok)) failures <<- failures + 1L
  invisible(ok)
}

show_file <- function(path, root) {
  cat("--- ", as.character(fs::path_rel(path, root)), " ",
      strrep("-", max(0, 60 - nchar(fs::path_rel(path, root)))), "\n", sep = "")
  cat(readLines(path, warn = FALSE), sep = "\n")
  cat("\n")
}

# --- 1. mock project ---------------------------------------------------------

section("Creating a throwaway project with mock sources")

root <- fs::path(tempfile("qmdme-e2e-"))
fs::dir_create(c(fs::path(root, "R"),
                 fs::path(root, "sql"),
                 fs::path(root, "py")))

# Per-file we track the original code token and the post-edit token so the
# assertions can prove the code section was actually refreshed.
sources <- list(
  R   = list(path = fs::path(root, "R", "fit.R"),
             companion = fs::path(root, "qmd", "R", "fit.qmd"),
             lang = "r",
             v1 = c("fit <- function(x) lm(y ~ x)", "coef0 <- 1"),
             v2 = c("fit <- function(x) glm(y ~ x)", "coef0 <- 999"),
             old = "coef0 <- 1", new = "coef0 <- 999"),
  sql = list(path = fs::path(root, "sql", "load.sql"),
             companion = fs::path(root, "qmd", "sql", "load.qmd"),
             lang = "sql",
             v1 = "SELECT * FROM raw;",
             v2 = "SELECT id, value FROM raw WHERE value IS NOT NULL;",
             old = "SELECT * FROM raw;", new = "WHERE value IS NOT NULL"),
  py  = list(path = fs::path(root, "py", "clean.py"),
             companion = fs::path(root, "qmd", "py", "clean.qmd"),
             lang = "python",
             v1 = c("import pandas as pd", "df = pd.DataFrame()"),
             v2 = c("import pandas as pd", "df = pd.read_csv('in.csv')"),
             old = "pd.DataFrame()", new = "pd.read_csv('in.csv')")
)

for (s in sources) writeLines(s$v1, s$path)
cat("Project root:", root, "\n")
cat("Wrote:", paste(vapply(sources, function(s) as.character(fs::path_rel(s$path, root)), ""),
                    collapse = ", "), "\n")

# --- 2. init -----------------------------------------------------------------

section("init() -- scaffold qmd/")
init(root)
check("qmd/ created", fs::dir_exists(fs::path(root, "qmd")))
check("qmd/index.qmd created", fs::file_exists(fs::path(root, "qmd", "index.qmd")))
cat("\n")
show_file(fs::path(root, "qmd", "index.qmd"), root)

# --- 3. first sync -----------------------------------------------------------

section("sync() -- create companions")
out1 <- sync(root = root)
print(out1, row.names = FALSE)

check("3 companions reported", nrow(out1) == 3L)
check("all actions == 'created'", all(out1$action == "created"))
for (s in sources) {
  check(paste0(as.character(fs::path_rel(s$companion, root)), " exists"),
        fs::file_exists(s$companion))
}
for (s in sources) {
  txt <- paste(readLines(s$companion, warn = FALSE), collapse = "\n")
  check(paste0(s$lang, " chunk is eval=FALSE"),
        grepl(paste0("{", s$lang, ", eval=FALSE}"), txt, fixed = TRUE))
  check(paste0("original code present in ", fs::path_file(s$companion)),
        grepl(s$old, txt, fixed = TRUE))
}

cat("\nA freshly created companion (note YAML + ## Notes + sentinel + chunk):\n\n")
show_file(sources$R$companion, root)

# --- 4. mutate: add prose above the sentinel, and edit each source -----------

section("Editing companions (prose) and sources (code)")

inject_prose <- function(companion, marker) {
  lines <- readLines(companion, warn = FALSE)
  notes_idx <- which(lines == "## Notes")[1]
  stopifnot(!is.na(notes_idx))
  prose <- c("", paste0("My note: ", marker, "."))
  writeLines(append(lines, prose, after = notes_idx), companion)
}

for (nm in names(sources)) {
  s <- sources[[nm]]
  marker <- paste0("PROSE-", nm)
  sources[[nm]]$marker <- marker
  inject_prose(s$companion, marker)        # user-authored prose, above the sentinel
  writeLines(s$v2, s$path)                  # change the source code
  cat("  edited", as.character(fs::path_rel(s$path, root)),
      "and added prose to", as.character(fs::path_rel(s$companion, root)), "\n")
}

cat("\nfit.qmd BEFORE re-sync (prose added, code still v1):\n\n")
show_file(sources$R$companion, root)

# --- 5. second sync ----------------------------------------------------------

section("sync() again -- code refreshed, prose preserved")
out2 <- sync(root = root)
print(out2, row.names = FALSE)

check("all actions == 'updated'", all(out2$action == "updated"))
for (nm in names(sources)) {
  s <- sources[[nm]]
  txt <- paste(readLines(s$companion, warn = FALSE), collapse = "\n")
  f <- fs::path_file(s$companion)
  check(paste0("prose preserved in ", f), grepl(s$marker, txt, fixed = TRUE))
  check(paste0("new code present in ", f), grepl(s$new, txt, fixed = TRUE))
  check(paste0("old code gone from ", f), !grepl(s$old, txt, fixed = TRUE))
}

cat("\nfit.qmd AFTER re-sync (prose survived, code is now v2):\n\n")
show_file(sources$R$companion, root)

# --- summary -----------------------------------------------------------------

section("Summary")
cat("Temp project left on disk for inspection:\n  ", root, "\n", sep = "")
cat("  e.g. less ", as.character(sources$R$companion), "\n\n", sep = "")
if (failures == 0L) {
  cat("All checks passed.\n")
  quit(status = 0)
} else {
  cat(failures, "check(s) FAILED.\n")
  quit(status = 1)
}
