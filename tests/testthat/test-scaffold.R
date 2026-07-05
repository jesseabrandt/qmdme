# scaffold.R holds the init_files() builders for init()'s two scopes. The
# website _quarto.yml carries a load-bearing contract -- `execute: enabled:
# false` -- so `quarto render` never boots a language kernel for the
# `{python}`/`{sql}` companion chunks (they are all eval=FALSE anyway). These
# tests pin that contract and the scope -> files mapping directly, rather than
# only through init()'s file-writing side effects.

test_that("init_files() maps each scope to the right set of qmd/ files", {
  expect_setequal(names(init_files("website")),
                  c("_quarto.yml", "index.qmd", "about.qmd"))
  expect_named(init_files("embed"), "index.qmd")
})

test_that("website _quarto.yml disables execution site-wide (no kernel on render)", {
  yml <- build_site_quarto_yml()
  parsed <- yaml::yaml.load(paste(yml, collapse = "\n"))
  # The critical bit: execution off, so a render starts no Jupyter/other kernel
  # even though companions carry {python}/{sql} chunks.
  expect_false(parsed$execute$enabled)
})

test_that("website _quarto.yml is a valid website config with an auto sidebar", {
  parsed <- yaml::yaml.load(paste(build_site_quarto_yml(), collapse = "\n"))
  expect_equal(parsed$project$type, "website")
  # An `auto` sidebar means synced companions appear in the nav without the
  # user hand-editing contents -- the whole point of the standalone scope.
  expect_equal(parsed$website$sidebar$contents, "auto")
})

test_that("embed and website landing pages are distinct, both valid front matter", {
  embed <- build_embed_index()
  site  <- build_site_index()
  expect_false(identical(embed, site))
  # Both begin a YAML front-matter block.
  expect_equal(embed[1], "---")
  expect_equal(site[1], "---")
  # The historical embed stub keeps its terse description.
  expect_match(paste(embed, collapse = "\n"), "Code companions", fixed = TRUE)
})

test_that("website about page names the sentinel contract it documents", {
  about <- paste(build_site_about(), collapse = "\n")
  expect_match(about, "qmdme:code-below", fixed = TRUE)
})
