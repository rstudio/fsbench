target_dir <- Sys.getenv("TARGET_DIR", "../fsbench.work")
target <- function(...) {
  file.path(target_dir, ...)
}

times <- list()

# construct a static 100MB dataframe
static_df_rows <- 0.0291268 * 100*1024*1024
static_df <- data.frame(x1 = runif(static_df_rows), x2 = runif(static_df_rows))

benchmark_begin <- function() {
  times <<- list()
}

benchmark <- function(name, task, parallelism = NA) {
  if (!is.na(parallelism)) {
    name <- sprintf("%s(%d)", name, parallelism)
  }
  message("
# ================================================
# Task: ", name, "
# ================================================
")
  dump_cache()
  force(task)
  if (!inherits(task, "proc_time")) {
    warning("Task '", name, "' returned wrong object type. Expected 'proc_time', got '", class(task)[1], "'")
  } else {
    times[[name]] <<- list(time=task, parallelism=parallelism)
  }
}

aggregate_benchmark <- function(name, iterations, task) {
  dump_cache()

  # perform the timer on the entire set of iterations instead of timing each
  # iteration individually - we need to do this because the overhead of using
  # system.time is HUGE! calling this in a loop is disastrous for performance,
  # and thus causes very inaccurate benchmarks. as a result, each iteration
  # should strive to minimize calls unrelated to the actual filesystem being tested
  aggregate_time = system.time({
    for (i in 1:iterations) {
      task(i)
    }
  })

  times[[name]] <<- list(time=aggregate_time, parallelism=NA)
}

benchmark_end <- function() {
  df <- do.call(rbind, unname(lapply(times, function(list) {
    proc_time <- list[[1]]
    parallelism <- as.integer(list[[2]])
    pt <- summary(proc_time)
    data.frame(user = pt[[1]], system = pt[[2]], elapsed = pt[[3]], parallelism = parallelism)
  })))
  # strip off the added parallelism in the name when creating the final data frame
  df <- cbind(data.frame(task = sub("(.*)\\(([\\d]+)\\)$", "\\1", names(times), perl=TRUE), stringsAsFactors = FALSE), df)
  df <- tibble::as_tibble(df)
  results_filename <- Sys.getenv("OUTPUT_FILE", "")
  if (!nzchar(results_filename)) {
    results_filename <- paste0("results-", format(Sys.time(), format = "%Y%m%d-%H%M%S"), ".csv")
    message("No OUTPUT_FILE env var; writing to ", results_filename)
  }
  write.csv(df, results_filename, row.names = FALSE)
  print(df)
}

time_install <- function(pkgname, type = "source", ...) {
  pkgs <- as.data.frame(available.packages(repos = "https://cloud.r-project.org"), stringsAsFactors = FALSE)
  # https://cran.r-project.org/src/contrib/BH_1.75.0-0.tar.gz
  pkgs <- pkgs[pkgs$Package == pkgname,]
  if (nrow(pkgs) == 0) {
    stop("Unknown package '", pkgname, "'")
  }
  stopifnot(nrow(pkgs) == 1)

  pkgfile <- target(paste0(pkgname, "_", pkgs$Version, ".tar.gz"))
  url <- file.path(pkgs$Repository, basename(pkgfile))

  download.file(url, pkgfile)
  on.exit(if (file.exists(pkgfile)) unlink(pkgfile))

  res <- system.time({
    utils::install.packages(pkgfile, repos = NULL, type = type, ...)
  })

  res
}

write_random_csv <- function(path, bytes) {
  rows <- 0.0291268 * bytes

  df <- data.frame(x1 = runif(rows), x2 = runif(rows))
  system.time({
    data.table::fwrite(df, file = path, row.names = FALSE, col.names = FALSE)
  })
}

write_static_csv <- function(path, num_files, num_iter) {
  num_rows <- as.integer(static_df_rows / num_files)
  start <- (num_iter - 1) * num_rows
  end <- start + num_rows
  sub_df <- static_df[start:end, ]
  data.table::fwrite(sub_df, file = path, row.names = FALSE, col.names = FALSE)
}

dump_cache <- function() {
  if (Sys.info()["sysname"] %in% c("Darwin", "Linux")) {
    system("/usr/local/sbin/purge-disk-cache")
  } else {
    warning("Clearing disk cache is not possible on this platform, benchmark results are unreliable!")
  }
}
