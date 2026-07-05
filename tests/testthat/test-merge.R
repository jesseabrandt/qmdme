test_that("merge_with_sentinel preserves prose above sentinel", {
  existing <- paste0(
    "---\ntitle: \"fit.R\"\n---\n\n",
    "## Notes\n\n",
    "These are my notes. They explain the file.\n\n",
    "<!-- qmdme:code-below -- do not edit below this line -->\n\n",
    "```{r, eval=FALSE}\nold_code <- 1\n```\n"
  )
  new_section <- "<!-- qmdme:code-below new -->\n\n```{r, eval=FALSE}\nnew_code <- 2\n```\n"

  out <- merge_with_sentinel(existing, new_section)
  expect_true(out$had_sentinel)
  expect_match(out$contents, "These are my notes. They explain the file.",
               fixed = TRUE)
  expect_match(out$contents, "new_code <- 2", fixed = TRUE)
  expect_false(grepl("old_code", out$contents, fixed = TRUE))
})

test_that("merge_with_sentinel appends new section when sentinel is missing", {
  existing <- "---\ntitle: \"fit.R\"\n---\n\n## Notes\n\nUser prose, no sentinel."
  new_section <- "<!-- qmdme:code-below new -->\n\n```{r, eval=FALSE}\nx <- 1\n```\n"
  out <- merge_with_sentinel(existing, new_section)
  expect_false(out$had_sentinel)
  expect_match(out$contents, "User prose, no sentinel.", fixed = TRUE)
  expect_match(out$contents, "<!-- qmdme:code-below new -->", fixed = TRUE)
  expect_match(out$contents, "x <- 1", fixed = TRUE)
  # Original prose stays before the appended section.
  expect_lt(regexpr("User prose", out$contents, fixed = TRUE),
            regexpr("qmdme:code-below", out$contents, fixed = TRUE))
})

test_that("merge_with_sentinel handles empty existing content", {
  new_section <- "<!-- qmdme:code-below new -->\n\n```{r, eval=FALSE}\nx <- 1\n```\n"
  out <- merge_with_sentinel("", new_section)
  expect_false(out$had_sentinel)
  expect_equal(out$contents, new_section)
})

test_that("merge_with_sentinel handles sentinel as first line", {
  existing <- "<!-- qmdme:code-below old -->\n```{r}\nold\n```\n"
  new_section <- "<!-- qmdme:code-below new -->\n```{r}\nnew\n```\n"
  out <- merge_with_sentinel(existing, new_section)
  expect_true(out$had_sentinel)
  expect_match(out$contents, "new", fixed = TRUE)
  expect_false(grepl("old", out$contents, fixed = TRUE))
})

test_that("merge_with_sentinel splices at the FIRST sentinel when several exist", {
  # A file can accrue a second sentinel (e.g. an earlier 'recovered' append
  # below prose that itself contained one). The splice must keep only prose
  # above the first sentinel and drop everything at/after it, including the
  # later sentinel -- so re-sync converges instead of accumulating sections.
  existing <- paste(c("prose above",
                      "<!-- qmdme:code-below one -->", "stale one",
                      "<!-- qmdme:code-below two -->", "stale two"),
                    collapse = "\n")
  new_section <- "<!-- qmdme:code-below new -->\nfresh\n"
  out <- merge_with_sentinel(existing, new_section)
  expect_true(out$had_sentinel)
  expect_match(out$contents, "prose above", fixed = TRUE)
  expect_match(out$contents, "fresh", fixed = TRUE)
  expect_false(grepl("stale one", out$contents, fixed = TRUE))
  expect_false(grepl("stale two", out$contents, fixed = TRUE))
})

test_that("merge_with_sentinel reports had_sentinel=FALSE when prefix appears only mid-line", {
  # User prose contains the sentinel string inline, but no line *starts* with
  # it -- the splice/append decision must be driven by line-prefix match.
  existing <- paste0(
    "---\ntitle: \"x\"\n---\n\n",
    "## Notes\n\n",
    "I mention <!-- qmdme:code-below in my prose.\n",
    "More notes here.\n"
  )
  new_section <- "<!-- qmdme:code-below new -->\n```{r}\nx <- 1\n```\n"
  out <- merge_with_sentinel(existing, new_section)
  expect_false(out$had_sentinel)
  expect_match(out$contents, "I mention <!-- qmdme:code-below in my prose.",
               fixed = TRUE)
})
