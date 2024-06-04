# fsbench

A set of R-centric benchmarks that evaluate filesystem performance for a number of common tasks. Currently for Linux and macOS only.

## Preparation

```
make setup
```

This will install required R packages, compile a small binary executable, and download some large data files to run the benchmarks against.

Running `make setup` will execute a command under `sudo`. This is necessary to create the `tools/purge` executable, which is invoked before each benchmark. The `purge` executable dumps the operating system's disk cache, which is a privileged operation, so the setuid flag to be set.

## Running

```
make
```

This will run for several minutes and then dump some timing information to the screen.

### Run Configuration

Two environment variables can be used to configure fsbench:

* `TARGET_DIR` defaults to `../fsbench.work` and controls where data will be written to/read from. This should be a directory path located on the filesystem you want to test, and needs to be set for both `make setup` and `make`. fsbench will attempt to create the directory if it does not exist. This directory must NOT be a subdirectory of the fsbench directory, otherwise the package installation benchmarks will throw confusing errors.

* `OUTPUT_FILE` defaults to `./results-<date>-<time>.csv` and indicates the path where the benchmark results should be recorded, as CSV data. (The same results are always printed to the screen, in tabular form.)

### Shortened Run

```shell
make short
```
This command runs the load test in a shortened form to allow for the quick assessment of a filesystem. It's not as comprehensive and doesn't load down the storage as heavily as the full run.


## Comparing results

Once you have one or more results files from running the benchmarks, you can use the comparison tool to compare multiple runs across several filesystems. The comparison tool will average multiple runs for each distinct filesystem tested, and produce bar charts to compare performance between the different filesystems.

To run the comparison tool:

```
Rscript compare.R <filesystem name>=<results file glob> ...
```

For example, to compare several runs against an SSD to several runs against an EFS volume:

```
Rscript compare.R ssd=*ssd.csv efs=*efs.csv
```

This will cause all `*ssd.csv` files containing `ssd` results to be loaded and averaged together and graphed against all of the (averaged) `efs` runs within the `*efs.csv` files. After the comparison has run, two image files will be generated:

* `serial-plot-results.png` shows all of the serial tests that have no parallelization, one plot for each test benchmark
* `parallel-plot-results.png` shows all of the parallel tests, one plot for each test benchmark

## License

fsbench is public domain ([CC0](https://creativecommons.org/publicdomain/zero/1.0/)).
