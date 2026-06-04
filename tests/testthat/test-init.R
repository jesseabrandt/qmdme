test_that("init creates qmd/ and qmd/index.qmd in a fresh project", {
  root <- withr::local_tempdir()
  out <- init(root)
  expect_true(fs::dir_exists(fs::path(root, "qmd")))
  expect_true(fs::file_exists(fs::path(root, "qmd", "index.qmd")))
  expect_equal(as.character(out), as.character(fs::path(root, "qmd")))
})

test_that("init does not clobber an existing qmd/index.qmd", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  writeLines(c("---", "title: \"my hand-rolled index\"", "---", "Hello!"),
             fs::path(root, "qmd", "index.qmd"))
  init(root)
  contents <- readLines(fs::path(root, "qmd", "index.qmd"))
  expect_match(paste(contents, collapse = "\n"), "my hand-rolled index",
               fixed = TRUE)
})

test_that("init reports skipped items via message", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  writeLines("existing", fs::path(root, "qmd", "index.qmd"))
  expect_message(init(root), "Skipped existing")
})

test_that("init defaults to embed scope: no _quarto.yml is written", {
  root <- withr::local_tempdir()
  init(root)
  expect_true(fs::file_exists(fs::path(root, "qmd", "index.qmd")))
  expect_false(fs::file_exists(fs::path(root, "qmd", "_quarto.yml")))
  expect_false(fs::file_exists(fs::path(root, "qmd", "about.qmd")))
})

test_that("init(scope = 'website') scaffolds a standalone Quarto website", {
  root <- withr::local_tempdir()
  out <- init(root, scope = "website")
  expect_true(fs::file_exists(fs::path(root, "qmd", "_quarto.yml")))
  expect_true(fs::file_exists(fs::path(root, "qmd", "index.qmd")))
  expect_true(fs::file_exists(fs::path(root, "qmd", "about.qmd")))
  expect_equal(as.character(out), as.character(fs::path(root, "qmd")))

  yml <- paste(readLines(fs::path(root, "qmd", "_quarto.yml")), collapse = "\n")
  expect_match(yml, "type: website", fixed = TRUE)
  expect_match(yml, "navbar", fixed = TRUE)
  expect_match(yml, "sidebar", fixed = TRUE)
})

test_that("init(scope = 'website') is non-destructive", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  writeLines("my: own-config", fs::path(root, "qmd", "_quarto.yml"))
  init(root, scope = "website")
  yml <- paste(readLines(fs::path(root, "qmd", "_quarto.yml")), collapse = "\n")
  expect_match(yml, "own-config", fixed = TRUE)
})

test_that("init(scope = 'website') reports the render hint", {
  root <- withr::local_tempdir()
  expect_message(init(root, scope = "website"), "quarto render")
})

test_that("init rejects an unknown scope", {
  root <- withr::local_tempdir()
  expect_error(init(root, scope = "bogus"))
})
