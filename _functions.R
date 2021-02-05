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
    install.packages(pkgfile, repos = NULL, type = type, ...)
  })
  remove.packages(pkgname)

  res
}
