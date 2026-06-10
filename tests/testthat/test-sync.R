# These tests exercise sync()'s file mechanics, not site wiring, so silence the
# "not connected to a site" warning for the whole file. The warning has its own
# coverage in test-detect.R.
withr::local_options(qmdme.warn_no_site = FALSE, .local_envir = teardown_env())

# Stable per-file content hash used by the idempotency test.
digest_file <- function(path) {
  paste(tools::md5sum(path), collapse = "")
}

make_project_with_sources <- function(envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = envir)
  fs::dir_create(fs::path(root, "R"))
  fs::dir_create(fs::path(root, "sql"))
  writeLines("x <- 1", fs::path(root, "R", "fit.R"))
  writeLines("SELECT 1", fs::path(root, "sql", "x.sql"))
  root
}

test_that("sync creates qmd companions for all source files when target is missing", {
  root <- make_project_with_sources()
  out <- sync(root = root)
  expect_true(fs::file_exists(fs::path(root, "qmd", "R", "fit.qmd")))
  expect_true(fs::file_exists(fs::path(root, "qmd", "sql", "x.qmd")))
  fit <- paste(readLines(fs::path(root, "qmd", "R", "fit.qmd")), collapse = "\n")
  expect_match(fit, "x <- 1", fixed = TRUE)
  expect_match(fit, "```\\{r, eval=FALSE\\}")
  expect_setequal(out$action, c("created", "created"))
})

test_that("sync updates only the code section, preserving user prose", {
  root <- make_project_with_sources()
  sync(root = root)  # initial create
  fit_path <- fs::path(root, "qmd", "R", "fit.qmd")
  contents <- readLines(fit_path)
  # Inject user prose
  notes_idx <- which(contents == "## Notes")
  contents <- append(contents, "User-written: this file is the model fitter.",
                     after = notes_idx + 1)
  writeLines(contents, fit_path)
  # Change source
  writeLines("x <- 999", fs::path(root, "R", "fit.R"))

  out <- sync(root = root)
  fit <- paste(readLines(fit_path), collapse = "\n")
  expect_match(fit, "User-written: this file is the model fitter.", fixed = TRUE)
  expect_match(fit, "x <- 999", fixed = TRUE)
  expect_false(grepl("x <- 1", fit, fixed = TRUE))
  expect_true("updated" %in% out$action)
})

test_that("sync re-appends code section and warns when sentinel is missing", {
  root <- make_project_with_sources()
  fs::dir_create(fs::path(root, "qmd", "R"))
  fit_path <- fs::path(root, "qmd", "R", "fit.qmd")
  writeLines(c("---", "title: \"fit.R\"", "---", "",
               "## Notes", "", "User prose without sentinel."),
             fit_path)

  out <- NULL
  expect_warning(
    out <- sync(root = root),
    "no sentinel"
  )
  fit <- paste(readLines(fit_path), collapse = "\n")
  expect_match(fit, "User prose without sentinel.", fixed = TRUE)
  expect_match(fit, "<!-- qmdme:code-below", fixed = TRUE)
  expect_match(fit, "x <- 1", fixed = TRUE)
  expect_true("recovered" %in% out$action)
})

test_that("sync narrows scope with paths arg", {
  root <- make_project_with_sources()
  out <- sync(root = root, paths = "R")
  expect_true(fs::file_exists(fs::path(root, "qmd", "R", "fit.qmd")))
  expect_false(fs::file_exists(fs::path(root, "qmd", "sql", "x.qmd")))
  expect_equal(nrow(out), 1)
})

# --- regression tests for audit findings -------------------------------------

test_that("sync treats sentinel mid-line in user prose as recovered (audit #1)", {
  root <- make_project_with_sources()
  fs::dir_create(fs::path(root, "qmd", "R"))
  fit_path <- fs::path(root, "qmd", "R", "fit.qmd")
  # Sentinel string appears inline in user prose, but no line *starts* with it.
  writeLines(c("---", "title: \"fit.R\"", "---", "",
               "## Notes", "",
               "I mention <!-- qmdme:code-below inline in my prose."),
             fit_path)
  out <- NULL
  expect_warning(out <- sync(root = root), "no sentinel")
  expect_true("recovered" %in% out$action)
  fit <- paste(readLines(fit_path), collapse = "\n")
  expect_match(fit, "I mention <!-- qmdme:code-below inline", fixed = TRUE)
})

test_that("sync still finds sources when project is nested under an ignore-named ancestor (audit #2)", {
  outer <- withr::local_tempdir()
  # The project root is literally `outer/qmd/proj`; without proper anchoring
  # the IGNORE_DIRS `qmd` rule would filter out every source file.
  root <- fs::path(outer, "qmd", "proj")
  fs::dir_create(fs::path(root, "R"))
  writeLines("x <- 1", fs::path(root, "R", "fit.R"))
  out <- sync(root = root)
  expect_equal(nrow(out), 1)
  expect_true(fs::file_exists(fs::path(root, "qmd", "R", "fit.qmd")))
})

test_that("sync is byte-idempotent across consecutive runs (audit #3)", {
  root <- make_project_with_sources()
  sync(root = root)
  files <- list.files(fs::path(root, "qmd"), recursive = TRUE, full.names = TRUE)
  before <- vapply(files, function(f) digest_file(f), character(1))
  sync(root = root)
  after <- vapply(files, function(f) digest_file(f), character(1))
  expect_equal(before, after)
})

test_that("sync handles source files containing triple-backtick fences (audit #4)", {
  root <- make_project_with_sources()
  writeLines(c("x <- 1", "```", "sneaky", "```"),
             fs::path(root, "R", "fit.R"))
  sync(root = root)
  fit <- paste(readLines(fs::path(root, "qmd", "R", "fit.qmd")), collapse = "\n")
  # Outer fence must be longer than the inner triple-backtick line.
  expect_match(fit, "````\\{r, eval=FALSE\\}", perl = TRUE)
  # All original lines are preserved verbatim inside the chunk.
  expect_match(fit, "sneaky", fixed = TRUE)
})

test_that("sync accepts custom extensions with regex metacharacters (audit #7)", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "src"))
  writeLines("int main() { return 0; }", fs::path(root, "src", "main.c++"))
  out <- sync(root = root, extensions = c("c++" = "cpp"))
  expect_equal(nrow(out), 1)
  expect_true(fs::file_exists(fs::path(root, "qmd", "src", "main.qmd")))
})

test_that("sync warns and skips when paths entry is not a directory (audit #8)", {
  root <- make_project_with_sources()
  expect_warning(
    out <- sync(root = root, paths = "Rr"),
    "not directories"
  )
  expect_equal(nrow(out), 0)
})

test_that("sync warns and skips when paths entry escapes root (audit #5)", {
  root <- make_project_with_sources()
  expect_warning(
    out <- sync(root = root, paths = "../etc"),
    "outside root"
  )
  expect_equal(nrow(out), 0)
})

test_that("sync warns and skips sources whose target would escape qmd/ (audit #6)", {
  # The write-side guard: simulate a source path that, when reflected into
  # qmd/, would resolve outside the qmd/ tree. We exercise this by passing
  # a source file *outside* root and calling sync_one() directly (the public
  # walker would never produce such input after the #5 fix, but the guard
  # should still hold defensively).
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  outside <- fs::path(fs::path_dir(root), "rogue.R")
  writeLines("x <- 1", outside)
  on.exit(unlink(outside), add = TRUE)
  expect_warning(
    res <- sync_one(outside, qmdme_default_extensions(), root = root),
    "escapes qmd"
  )
  expect_null(res)
})
