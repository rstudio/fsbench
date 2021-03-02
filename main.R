library(data.table)

source("_functions.R")

benchmark_begin()

times <- list()

dir.create(target("lib"), recursive = TRUE, showWarnings = FALSE)

benchmark("Install MASS", time_install("MASS", lib = target("lib")))
benchmark("Install lattice", time_install("lattice", lib = target("lib")))
benchmark("Install BH", time_install("BH", lib = target("lib")))

utils::remove.packages(c("MASS", "lattice", "BH"), lib = target("lib"))
unlink(target("lib"), recursive = TRUE)

# Write, then read, 1GB CSV =========

benchmark("base::write.csv, 10KB", write_random_csv(target("10kb.csv"), 10*1024))
benchmark("base::write.csv, 1MB", write_random_csv(target("1mb.csv"), 1024*1024))
benchmark("base::write.csv, 100MB", write_random_csv(target("100mb.csv"), 100*1024*1024))
benchmark("base::write.csv, 1GB", write_random_csv(target("1gb.csv"), 1024*1024*1024))

benchmark("base::read.csv, 10KB", system.time({ data.table::fread(target("10kb.csv")) }))
benchmark("base::read.csv, 1MB", system.time({ data.table::fread(target("1mb.csv")) }))
benchmark("base::read.csv, 100MB", system.time({ data.table::fread(target("100mb.csv")) }))
benchmark("base::read.csv, 1GB", system.time({ data.table::fread(target("1gb.csv")) }))

unlink(target("10kb.csv"))
unlink(target("1mb.csv"))
unlink(target("100mb.csv"))
unlink(target("1gb.csv"))


# Read CRAN logs =========

# benchmark("Read CRAN logs" <- local({
# })

benchmark_end()
