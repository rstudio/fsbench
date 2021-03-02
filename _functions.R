target_dir <- Sys.getenv("TARGET_DIR", "../fsbench.work")
target <- function(...) {
  file.path(target_dir, ...)
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
