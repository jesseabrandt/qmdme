test_that("qmdme_default_extensions returns named char vector with R, sql, py", {
  ext <- qmdme_default_extensions()
  expect_type(ext, "character")
  expect_named(ext)
  expect_setequal(names(ext), c("R", "sql", "py"))
  expect_equal(ext[["R"]], "r")
  expect_equal(ext[["sql"]], "sql")
  expect_equal(ext[["py"]], "python")
})

test_that("chunk_lang returns the chunk language for a known extension", {
  ext <- c(R = "r", sql = "sql", py = "python")
  expect_equal(chunk_lang("R", ext), "r")
  expect_equal(chunk_lang("sql", ext), "sql")
  expect_equal(chunk_lang("py", ext), "python")
})

test_that("chunk_lang is case-insensitive on the extension", {
  ext <- c(R = "r", sql = "sql")
  expect_equal(chunk_lang("r", ext), "r")
  expect_equal(chunk_lang("SQL", ext), "sql")
})

test_that("chunk_lang errors for unknown extension", {
  ext <- c(R = "r")
  expect_error(chunk_lang("xyz", ext), "No chunk-language mapping")
})
