library(data.table)
library(fst)
library(parallel)
library(R.utils) # needed for fread to read .gz files
library(vroom)

source("_functions.R")
short <- FALSE
args <- commandArgs(trailingOnly = TRUE)

if (length(args) >= 1) {
  if (args[1] == "short" {
  short <- TRUE
  }
}

benchmark_begin()

dir.create(target("lib"), recursive = TRUE, showWarnings = FALSE)

# Install common R packages =====================================================================================
benchmark("Install MASS", time_install("MASS", lib = target("lib")))
if (!short) {
benchmark("Install lattice", time_install("lattice", lib = target("lib")))
benchmark("Install BH", time_install("BH", lib = target("lib")))
}

utils::remove.packages(c("MASS"), lib = target("lib"))

if (!short){
utils::remove.packages(c("lattice", "BH"), lib = target("lib"))
}
unlink(target("lib"), recursive = TRUE)
# ===============================================================================================================

# Write, then read, 1GB CSV =====================================================================================
benchmark("Write CSV, 100MB", write_random_csv(target("100mb.csv"), 100*1024*1024))
if (!short) {
benchmark("Write CSV, 10KB", write_random_csv(target("10kb.csv"), 10*1024))
benchmark("Write CSV, 1MB", write_random_csv(target("1mb.csv"), 1024*1024))
benchmark("Write CSV, 1GB", write_random_csv(target("1gb.csv"), 1024*1024*1024))
}

benchmark("Read CSV, 100MB", system.time({ data.table::fread(target("100mb.csv")) }))
if (!short) {
benchmark("Read CSV, 10KB", system.time({ data.table::fread(target("10kb.csv")) }))
benchmark("Read CSV, 1MB", system.time({ data.table::fread(target("1mb.csv")) }))
benchmark("Read CSV, 1GB", system.time({ data.table::fread(target("1gb.csv")) }))
}

unlink(target("100mb.csv"))
if (!short) {
unlink(target("10kb.csv"))
unlink(target("1mb.csv"))
unlink(target("1gb.csv"))
}
# ===============================================================================================================

# Parallel tests with 1GB readers/writers =======================================================================

iters <- 2
if (!short) {
iters <- 4
}

for (i in 1:iters) {
  num_writers <- 2^i
  benchmark("DD write, 1GB", system.time({
    mclapply(1:num_writers, function(id) {
      file <- target(sprintf("parallel_%d.dat", id))
      command <- sprintf("dd if=/dev/zero of=%s bs=1048576 count=1024 conv=sync oflag=nocache", file)
      system(command)
    }, mc.preschedule = FALSE, mc.cores = num_writers)
  }), parallelism = num_writers)
}

for (i in 1:iters) {
  num_readers <- 2^i
  benchmark("DD read, 1GB", system.time({
    mclapply(1:num_readers, function(id) {
      file <- target(sprintf("parallel_%d.dat", id))
      command <- sprintf("dd if=%s of=/dev/null bs=1048576 count=1024 iflag=nocache", file)
      system(command)
    }, mc.preschedule = FALSE, mc.cores = num_readers)
  }), parallelism = num_readers)
}

unlink(target("parallel_*.dat"))
# ===============================================================================================================

# Small files tests =============================================================================================

for (i in 1:iters) {
  num_files <- 10 ^ i
  file_size <- 100*1024*1024 / num_files

  aggregate_benchmark(sprintf("Write CSV, 100MB over %s files", num_files), num_files, function(iter) {
    write_static_csv(target(sprintf("small_%s.csv", iter)), num_files, iter)
  })

  aggregate_benchmark(sprintf("Read CSV, 100MB over %s files", num_files), num_files, function(iter) {
    data.table::fread(target(sprintf("small_%s.csv", iter)))
  })

  for (j in 1:num_files) {
    unlink(target(sprintf("small_%s.csv", j)))
  }
}
# ===============================================================================================================

# Parallel small file tests =====================================================================================
for (i in 1:iters) {
  num_writers <- 2^i
  benchmark("DD write, 10MB over 1000 files", system.time({
    mclapply(1:num_writers, function(id) {
      for (j in 1:1000) {
        file <- target(sprintf("small-parallel_%d_%d.dat", id, j))
        command <- sprintf("dd if=/dev/zero of=%s bs=1024 count=10 conv=sync oflag=nocache", file)
        system(command, ignore.stdout = TRUE, ignore.stderr = TRUE)
      }
    }, mc.preschedule = FALSE, mc.cores = num_writers)
  }), parallelism = num_writers)
}

for (i in 1:iters) {
  num_readers <- 2^i
  benchmark("DD read, 10MB over 1000 files", system.time({
    mclapply(1:num_readers, function(id) {
      for (j in 1:1000) {
        file <- target(sprintf("small-parallel_%d_%d.dat", id, j))
        command <- sprintf("dd if=%s of=/dev/null bs=1024 count=10 iflag=nocache", file)
        system(command, ignore.stdout = TRUE, ignore.stderr = TRUE)
      }
    }, mc.preschedule = FALSE, mc.cores = num_readers)
  }), parallelism = num_readers)
}

unlink(target("small-parallel_*.dat"))
# ===============================================================================================================

# FST tests =====================================================================================================
# Generate a random data frame (approximately 1GB of data), save it to disk,
# then perform random read tests of different lengths on the file
size_100mb <- 100*1024*1024
num_rows <- 0.0625 * size_100mb
size_per_row <- size_100mb / num_rows
fst_frame <- data.frame(x1 = runif(num_rows), x2 = runif(num_rows))
write.fst(fst_frame, target("dataset.fst"))

if (!short) {
num_read <- 0
benchmark("FST random reads, 100MB over 10*10MB reads", system.time({
  rows_to_read <- (10*1024*1024) / size_per_row
  while (num_read < size_100mb) {
    from <- runif(1, 0, num_rows - rows_to_read)
    to <- from + rows_to_read
    fst_subset <- read.fst(target("dataset.fst"), NULL, from, to)
    num_read <- num_read + object.size(fst_subset)
  }
}))
}

num_read <- 0
benchmark("FST random reads, 100MB over 100*1MB reads", system.time({
  rows_to_read <- (1*1024*1024) / size_per_row
  while (num_read < size_100mb) {
    from <- runif(1, 0, num_rows - rows_to_read)
    to <- from + rows_to_read
    fst_subset <- read.fst(target("dataset.fst"), NULL, from, to)
    num_read <- num_read + object.size(fst_subset)
  }
}))

if (!short) {
num_read <- 0
benchmark("FST random reads, 100MB over 1000*100KB reads", system.time({
  rows_to_read <- (100*1024) / size_per_row
  while (num_read < size_100mb) {
    from <- runif(1, 0, num_rows - rows_to_read)
    to <- from + rows_to_read
    fst_subset <- read.fst(target("dataset.fst"), NULL, from, to)
    num_read <- num_read + object.size(fst_subset)
  }
}))
}
if (!short) {
num_read <- 0
benchmark("FST random reads, 100MB over 10000*10KB reads", system.time({
  rows_to_read <- (10*1024) / size_per_row
  while (num_read < size_100mb) {
    from <- runif(1, 0, num_rows - rows_to_read)
    to <- from + rows_to_read
    fst_subset <- read.fst(target("dataset.fst"), NULL, from, to)
    num_read <- num_read + object.size(fst_subset)
  }
}))
}
unlink(target("dataset.fst"))
#================================================================================================================

# Read CRAN logs ================================================================================================
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
# ===============================================================================================================

benchmark_end()
