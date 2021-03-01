source("_functions.R")

dir.create(target(), recursive = TRUE, showWarnings = FALSE)

# --- Download CRAN logs from 2020-01-01 to 2020-03-31 ----
local({
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
    download.file(
      sprintf("http://cran-logs.rstudio.com/2020/%s.csv.gz", date_chunk),
      target(sprintf("cranlogs/%s.csv.gz", date_chunk)),
      method = "libcurl",
      quiet = TRUE
    )
  }
})
