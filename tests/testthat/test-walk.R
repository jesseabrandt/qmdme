make_fake_project <- function(envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = envir)
  fs::dir_create(fs::path(root, "R"))
  fs::dir_create(fs::path(root, "sql", "queries"))
  fs::dir_create(fs::path(root, "py"))
  fs::dir_create(fs::path(root, ".git"))
  fs::dir_create(fs::path(root, "renv", "library"))
  fs::dir_create(fs::path(root, "qmd"))
  writeLines("x <- 1", fs::path(root, "R", "fit.R"))
  writeLines("y <- 2", fs::path(root, "R", "helpers.R"))
  writeLines("SELECT 1", fs::path(root, "sql", "queries", "x.sql"))
  writeLines("z = 3", fs::path(root, "py", "utils.py"))
  writeLines("ignored", fs::path(root, ".git", "config"))
  writeLines("ignored", fs::path(root, "renv", "library", "stub.R"))
  writeLines("ignored", fs::path(root, "qmd", "fit.qmd"))
  root
}

test_that("walk_sources finds all source files when paths is NULL", {
  root <- make_fake_project()
  files <- walk_sources(root, NULL, qmdme_default_extensions())
  rel <- fs::path_rel(files, root)
  expect_setequal(as.character(rel),
                  c("R/fit.R", "R/helpers.R", "sql/queries/x.sql", "py/utils.py"))
})

test_that("walk_sources narrows scope when paths is given", {
  root <- make_fake_project()
  files <- walk_sources(root, "R", qmdme_default_extensions())
  rel <- fs::path_rel(files, root)
  expect_setequal(as.character(rel), c("R/fit.R", "R/helpers.R"))
})

test_that("walk_sources skips ignore directories", {
  root <- make_fake_project()
  files <- walk_sources(root, NULL, qmdme_default_extensions())
  expect_false(any(grepl("/\\.git/", files)))
  expect_false(any(grepl("/renv/", files)))
  expect_false(any(grepl("/qmd/", files)))
})

test_that("walk_sources returns character(0) for empty dir", {
  root <- withr::local_tempdir()
  files <- walk_sources(root, NULL, qmdme_default_extensions())
  expect_equal(files, character(0))
})
