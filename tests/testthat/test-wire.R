# wire() detects an existing site and tells the user exactly how to connect
# qmd/ to it, or points at website mode when there is no site. It is read-only:
# it never edits or creates files (creation is init(scope = "website")'s job).

test_that("wire() detects a root _quarto.yml and names the file", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website"),
             fs::path(root, "_quarto.yml"))
  expect_message(wire(root), "_quarto.yml", fixed = TRUE)
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "quarto")
  expect_false(res$wired)
  expect_equal(as.character(fs::path_file(res$file)), "_quarto.yml")
})

test_that("wire() guidance names a concrete key to add qmd under", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website"),
             fs::path(root, "_quarto.yml"))
  # The instruction must be actionable: it should mention 'qmd' and a YAML key
  # the user adds it under (contents/sidebar/render), not a vague "wire it in".
  expect_message(wire(root), "qmd", fixed = TRUE)
  expect_message(wire(root), "contents|sidebar|render")
})

test_that("wire() recognizes when qmd is already referenced", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website",
               "website:", "  sidebar:", "    contents:", "      - qmd"),
             fs::path(root, "_quarto.yml"))
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "quarto")
  expect_true(res$wired)
  expect_message(wire(root), "already")
})

test_that("wire() recognizes an existing standalone qmd/ website", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  writeLines(c("project:", "  type: website"),
             fs::path(root, "qmd", "_quarto.yml"))
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "qmd_website")
  expect_message(wire(root), "quarto render qmd")
})

test_that("wire() recognizes a pkgdown site and points elsewhere", {
  root <- withr::local_tempdir()
  writeLines("url: https://example.org", fs::path(root, "_pkgdown.yml"))
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "pkgdown")
  expect_message(wire(root), "website", fixed = TRUE)
})

test_that("wire() points at website mode when no site is found", {
  root <- withr::local_tempdir()
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "none")
  expect_message(wire(root), "scope = \"website\"", fixed = TRUE)
})

test_that("wire() returns its detection result invisibly", {
  root <- withr::local_tempdir()
  expect_invisible(suppressMessages(wire(root)))
  res <- suppressMessages(wire(root))
  expect_type(res, "list")
  expect_true(all(c("type", "file", "wired") %in% names(res)))
})

test_that("wire() does not create or modify any files", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website"),
             fs::path(root, "_quarto.yml"))
  before <- fs::dir_ls(root, recurse = TRUE)
  before_yml <- readLines(fs::path(root, "_quarto.yml"))
  suppressMessages(wire(root))
  after <- fs::dir_ls(root, recurse = TRUE)
  after_yml <- readLines(fs::path(root, "_quarto.yml"))
  expect_equal(as.character(after), as.character(before))
  expect_equal(after_yml, before_yml)
})

test_that("init() embed mode points the user at wire()", {
  root <- withr::local_tempdir()
  expect_message(init(root), "wire", fixed = TRUE)
})
