# wire() is a DOER: it edits the root _quarto.yml so the qmd/ companions are
# wired into the site. It only edits when an edit is actually needed (an
# explicit sidebar `contents:` list or a `project: render:` allowlist that
# excludes qmd); when the site already surfaces qmd automatically it reports so
# and changes nothing. It backs the file up before writing.

test_that("wire() adds qmd to an explicit sidebar contents list", {
  root <- withr::local_tempdir()
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - index.qmd",
    "      - about.qmd"
  ), fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_equal(res$type, "quarto")
  expect_true(res$changed)
  yml <- yaml::read_yaml(fs::path(root, "_quarto.yml"))
  expect_true("qmd" %in% unlist(yml$website$sidebar$contents))
})

test_that("wire() backs up the config before editing (backup = TRUE)", {
  root <- withr::local_tempdir()
  original <- c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - index.qmd"
  )
  writeLines(original, fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_true(res$changed)
  bak <- fs::path(root, "_quarto.yml.bak")
  expect_true(fs::file_exists(bak))
  # The backup is the verbatim pre-edit file.
  expect_equal(readLines(bak), original)
})

test_that("wire(backup = FALSE) edits without writing a .bak", {
  root <- withr::local_tempdir()
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - index.qmd"
  ), fs::path(root, "_quarto.yml"))

  suppressMessages(wire(root, backup = FALSE))

  expect_false(fs::file_exists(fs::path(root, "_quarto.yml.bak")))
  yml <- yaml::read_yaml(fs::path(root, "_quarto.yml"))
  expect_true("qmd" %in% unlist(yml$website$sidebar$contents))
})

test_that("wire() is idempotent: re-running makes no further change", {
  root <- withr::local_tempdir()
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - index.qmd"
  ), fs::path(root, "_quarto.yml"))

  suppressMessages(wire(root))
  res2 <- suppressMessages(wire(root))

  expect_false(res2$changed)
  expect_message(wire(root), "already")
  yml <- yaml::read_yaml(fs::path(root, "_quarto.yml"))
  expect_equal(sum(unlist(yml$website$sidebar$contents) == "qmd"), 1L)
})

test_that("wire() adds qmd to an explicit project render allowlist", {
  root <- withr::local_tempdir()
  writeLines(c(
    "project:",
    "  type: website",
    "  render:",
    "    - index.qmd",
    "    - about.qmd"
  ), fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_true(res$changed)
  yml <- yaml::read_yaml(fs::path(root, "_quarto.yml"))
  expect_true(any(grepl("qmd", unlist(yml$project$render))))
})

test_that("wire() makes no edit when the site already surfaces qmd automatically", {
  root <- withr::local_tempdir()
  # Minimal site: auto sidebar, no render allowlist -> qmd appears on its own.
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents: auto"
  ), fs::path(root, "_quarto.yml"))
  before <- readLines(fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_false(res$changed)
  expect_equal(readLines(fs::path(root, "_quarto.yml")), before)
  expect_false(fs::file_exists(fs::path(root, "_quarto.yml.bak")))
  expect_message(wire(root), "automatically")
})

test_that("wire() makes no edit when qmd is already in the contents list", {
  root <- withr::local_tempdir()
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - index.qmd",
    "      - qmd"
  ), fs::path(root, "_quarto.yml"))
  before <- readLines(fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_false(res$changed)
  expect_equal(readLines(fs::path(root, "_quarto.yml")), before)
  expect_message(wire(root), "already")
})

test_that("wire() does not edit; it guides, when there is no root Quarto site", {
  root <- withr::local_tempdir()
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "none")
  expect_false(res$changed)
  expect_message(wire(root), "scope = \"website\"", fixed = TRUE)
})

test_that("wire() guides (no edit) for a standalone qmd/ website", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "qmd"))
  writeLines(c("project:", "  type: website"),
             fs::path(root, "qmd", "_quarto.yml"))
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "qmd_website")
  expect_false(res$changed)
  expect_message(wire(root), "quarto render qmd", fixed = TRUE)
})

test_that("wire() guides (no edit) for a pkgdown site", {
  root <- withr::local_tempdir()
  writeLines("url: https://example.org", fs::path(root, "_pkgdown.yml"))
  res <- suppressMessages(wire(root))
  expect_equal(res$type, "pkgdown")
  expect_false(res$changed)
  expect_message(wire(root), "website", fixed = TRUE)
})

test_that("wire() returns its result invisibly", {
  root <- withr::local_tempdir()
  expect_invisible(suppressMessages(wire(root)))
  res <- suppressMessages(wire(root))
  expect_type(res, "list")
  expect_true(all(c("type", "file", "changed") %in% names(res)))
})

test_that("wire() leaves an unrecognized config untouched and guides", {
  root <- withr::local_tempdir()
  # A sidebar whose contents is a nested section structure we don't rewrite.
  writeLines(c(
    "project:",
    "  type: website",
    "website:",
    "  sidebar:",
    "    contents:",
    "      - section: Reference",
    "        contents:",
    "          - index.qmd"
  ), fs::path(root, "_quarto.yml"))
  before <- readLines(fs::path(root, "_quarto.yml"))

  res <- suppressMessages(wire(root))

  expect_false(res$changed)
  expect_equal(readLines(fs::path(root, "_quarto.yml")), before)
})
