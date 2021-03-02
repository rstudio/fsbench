renv::restore()

source("_functions.R")

dir.create(target(), recursive = TRUE, showWarnings = FALSE)

# --- Download CRAN logs from 2020-01-01 to 2020-03-31 ----
local({
  op <- options(timeout = 99999, warn = 2)
  on.exit(options(op), add = TRUE)

  dir.create(target("cranlogs"), recursive = TRUE, showWarnings = FALSE)
  start_date <- as.Date("2020-01-01")
  end_date <- as.Date("2020-03-31")
  chunk_size <- 7 # number of days to download at a time (approx)
  dates <- as.character(seq(start_date, to = end_date, by = "day"))
  date_chunks <- split(dates, as.integer(cut(seq_along(dates), ceiling(length(dates) / chunk_size))))

  # Don't time downloading of logs, too dependent on network
  for (date_chunk in date_chunks) {
    cat(sprintf("%s..%s", head(date_chunk, 1), tail(date_chunk, 1)),
      "\n", sep = "")
    # Named list where names are URLs and elements are destinations
    todo <- setNames(
      target(sprintf("cranlogs/%s.csv.gz", date_chunk)),
      sprintf("http://cran-logs.rstudio.com/2020/%s.csv.gz", date_chunk)
    )
    # Don't download files that already exist
    skipping <- todo[file.exists(todo)]
    todo <- todo[!file.exists(todo)]
    if (length(todo) == 0) {
      next
    }
    tryCatch(
      download.file(names(todo), unname(todo), method = "libcurl", quiet = TRUE),
      error = function(e) {
        unlink(todo, recursive = FALSE)
        stop(e)
      }
    )
  }
})
