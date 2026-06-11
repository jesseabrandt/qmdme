# detect_site() classifies the site at the project root; init() turns that
# classification into next-step instructions, and sync() turns it into a
# suppressible "not connected to a site" warning.

test_that("detect_site() classifies the common site types", {
  quarto <- withr::local_tempdir()
  writeLines(c("project:", "  type: website"),
             fs::path(quarto, "_quarto.yml"))
  expect_equal(detect_site(quarto)$type, "quarto")

  wired <- withr::local_tempdir()
  writeLines(c("project:", "  type: website",
               "website:", "  sidebar:", "    contents:", "      - qmd"),
             fs::path(wired, "_quarto.yml"))
  ds <- detect_site(wired)
  expect_equal(ds$type, "quarto")
  expect_true(ds$wired)

  standalone <- withr::local_tempdir()
  fs::dir_create(fs::path(standalone, "qmd"))
  writeLines(c("project:", "  type: website"),
             fs::path(standalone, "qmd", "_quarto.yml"))
  expect_equal(detect_site(standalone)$type, "qmd_website")

  pkg <- withr::local_tempdir()
  writeLines("url: https://example.org", fs::path(pkg, "_pkgdown.yml"))
  expect_equal(detect_site(pkg)$type, "pkgdown")

  bare <- withr::local_tempdir()
  expect_equal(detect_site(bare)$type, "none")
})

test_that("detect_site() is not fooled by qmd appearing in a comment", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website",
               "website:", "  sidebar:", "    contents:",
               "      - index.qmd", "      # - qmd  (add this later)"),
             fs::path(root, "_quarto.yml"))
  expect_false(detect_site(root)$wired)
})

test_that("detect_site() is not fooled by a hyphenated name with a qmd segment", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website", "  render:",
               "    - analysis-qmd-v2.R"),
             fs::path(root, "_quarto.yml"))
  expect_false(detect_site(root)$wired)
})

test_that("detect_site() is not fooled by qmd as a mapping value (output-dir)", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website", "  output-dir: qmd"),
             fs::path(root, "_quarto.yml"))
  expect_false(detect_site(root)$wired)
})

test_that("detect_site() still recognizes a genuine qmd reference", {
  # bare list item
  block <- withr::local_tempdir()
  writeLines(c("website:", "  sidebar:", "    contents:", "      - qmd"),
             fs::path(block, "_quarto.yml"))
  expect_true(detect_site(block)$wired)

  # qmd/ path glob in a render allowlist
  glob <- withr::local_tempdir()
  writeLines(c("project:", "  render:", "    - index.qmd", "    - qmd/*.qmd"),
             fs::path(glob, "_quarto.yml"))
  expect_true(detect_site(glob)$wired)

  # inline flow sequence
  flow <- withr::local_tempdir()
  writeLines(c("website:", "  sidebar:", "    contents: [index.qmd, qmd]"),
             fs::path(flow, "_quarto.yml"))
  expect_true(detect_site(flow)$wired)
})

test_that("detect_site() does not treat index.qmd alone as wired", {
  root <- withr::local_tempdir()
  writeLines(c("website:", "  sidebar:", "    contents:", "      - index.qmd"),
             fs::path(root, "_quarto.yml"))
  expect_false(detect_site(root)$wired)
})

test_that("init() embed mode points at wire() when an unwired Quarto site exists", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website"),
             fs::path(root, "_quarto.yml"))
  expect_message(init(root), "wire", fixed = TRUE)
  expect_message(init(root), "_quarto.yml", fixed = TRUE)
})

test_that("init() embed mode reports when qmd is already referenced", {
  root <- withr::local_tempdir()
  writeLines(c("project:", "  type: website",
               "website:", "  sidebar:", "    contents:", "      - qmd"),
             fs::path(root, "_quarto.yml"))
  expect_message(init(root), "already")
})

test_that("init() embed mode points at website scope when there is no site", {
  root <- withr::local_tempdir()
  expect_message(init(root), "scope = \"website\"", fixed = TRUE)
})

test_that("init(scope = 'website') keeps its standalone-site message", {
  root <- withr::local_tempdir()
  expect_message(init(root, scope = "website"), "quarto render qmd", fixed = TRUE)
})

test_that("sync() warns when companions are not connected to a site", {
  root <- withr::local_tempdir()
  writeLines("x <- 1", fs::path(root, "a.R"))
  expect_warning(sync(root = root), "wire|website")
})

test_that("sync() does not warn when warn_no_site = FALSE", {
  root <- withr::local_tempdir()
  writeLines("x <- 1", fs::path(root, "a.R"))
  expect_no_warning(sync(root = root, warn_no_site = FALSE))
})

test_that("sync() warning honors the qmdme.warn_no_site option", {
  root <- withr::local_tempdir()
  writeLines("x <- 1", fs::path(root, "a.R"))
  withr::local_options(qmdme.warn_no_site = FALSE)
  expect_no_warning(sync(root = root))
})

test_that("sync() does not warn when the site already references qmd", {
  root <- withr::local_tempdir()
  writeLines("x <- 1", fs::path(root, "a.R"))
  writeLines(c("project:", "  type: website",
               "website:", "  sidebar:", "    contents:", "      - qmd"),
             fs::path(root, "_quarto.yml"))
  expect_no_warning(sync(root = root))
})

test_that("sync() does not warn for a standalone qmd/ website", {
  root <- withr::local_tempdir()
  writeLines("x <- 1", fs::path(root, "a.R"))
  fs::dir_create(fs::path(root, "qmd"))
  writeLines(c("project:", "  type: website"),
             fs::path(root, "qmd", "_quarto.yml"))
  expect_no_warning(sync(root = root))
})

test_that("sync() does not warn when it wrote no companions", {
  root <- withr::local_tempdir()
  expect_no_warning(sync(root = root))
})
