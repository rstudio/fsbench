library(data.table)

source("_functions.R")

times <- list()

dir.create(target("lib"), recursive = TRUE, showWarnings = FALSE)
times$"Install MASS" <- time_install("MASS", lib = target("lib"))
times$"Install lattice" <- time_install("lattice", lib = target("lib"))
times$"Install BH" <- time_install("BH", lib = target("lib"))
utils::remove.packages(c("MASS", "lattice", "BH"), lib = target("lib"))
unlink(target("lib"), recursive = TRUE)

# Write, then read, 1GB CSV =========

fct <- 29.1268
times$"base::write.csv, 1GB" <- local({
  df <- data.frame(x1 = runif(1e6 * fct), x2 = runif(1e6 * fct))
  message("Data generated")
  system.time({
    data.table::fwrite(df, file = target("1gb.csv"), row.names = FALSE)
  })
})

if (Sys.info()["sysname"] == "Darwin") {
  message("Please clear the cache using `sync && sudo purge`, then press Enter to continue...")
} else if (Sys.info()["sysname"] == "Linux") {
  message("Please clear the cache using `sync && echo 3 > /proc/sys/vm/drop_caches`, then press Enter to continue...")
} else {
  message("Please clear the OS disk cache if possible, then press Enter to continue...")
}
readline(prompt = "")

times$"base::read.csv, 1GB" <- local({
  system.time({
    data.table::fread(target("1gb.csv"))
  })
})

unlink(target("1gb.csv"))


# Read CRAN logs =========

# times$"Read CRAN logs" <- local({
# })

print(times)
