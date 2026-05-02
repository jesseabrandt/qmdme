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
