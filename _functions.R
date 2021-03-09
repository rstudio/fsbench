target_dir <- Sys.getenv("TARGET_DIR", "../fsbench.work")
target <- function(...) {
  file.path(target_dir, ...)
}

times <- list()

benchmark_begin <- function() {
  times <<- list()
}

benchmark <- function(name, task) {
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
    times[[name]] <<- task
  }
}

benchmark_end <- function() {
  df <- do.call(rbind, unname(lapply(times, function(proc_time) {
    pt <- summary(proc_time)
    data.frame(user = pt[[1]], system = pt[[2]], elapsed = pt[[3]])
  })))
  df <- cbind(data.frame(task = names(times), stringsAsFactors = FALSE), df)
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

  pkgfile <- paste0(pkgname, "_", pkgs$Version, ".tar.gz")
  url <- file.path(pkgs$Repository, pkgfile)

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

dump_cache <- function() {
  if (Sys.info()["sysname"] %in% c("Darwin", "Linux")) {
    system("tools/purge")
  } else {
    warning("Clearing disk cache is not possible on this platform, benchmark results are unreliable!")
  }
}
