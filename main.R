library(data.table)
library(R.utils) # needed for fread to read .gz files
library(vroom)

source("_functions.R")

benchmark_begin()

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

benchmark("Read 14 days of CRAN logs with fread", system.time({
  for (file in sort(dir(target("cranlogs"), full.names = TRUE))) {
    message(basename(file))
    fread_df <- data.table::fread(file, showProgress = FALSE)
    table(fread_df$country)
  }
}))

benchmark("Sample 5000 rows from each of 14 CRAN logs with vroom", system.time({
  for (file in sort(dir(target("cranlogs"), full.names = TRUE))) {
    message(basename(file))
    vroom_df <- vroom(file, progress = FALSE, col_types = "Dtdccccccd",
      col_names = c("date","time","size","r_version","r_arch","r_os","package","version","country","ip_id")
    )
    sample(vroom_df$country, 5000)
  }
}))

benchmark_end()
