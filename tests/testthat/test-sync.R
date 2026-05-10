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
  expect_false(grepl("x <- 1\\n", fit))
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
