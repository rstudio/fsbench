# fsbench

A set of R-centric benchmarks that evaluate filesystem performance for a number of common tasks. Currently for Linux and macOS only.

**Work in progress**

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

## Configuring

Two environment variables can be used to configure fsbench:

* `TARGET_DIR` defaults to `../fsbench.work` and controls where data will be written to/read from. This should be a directory path located on the filesystem you want to test, and needs to be set for both `make setup` and `make`. fsbench will attempt to create the directory if it does not exist. This directory must NOT be a subdirectory of the fsbench directory, otherwise the package installation benchmarks will throw confusing errors.

* `OUTPUT_FILE` defaults to `./results-<date>-<time>.csv` and indicates the path where the benchmark results should be recorded, as CSV data. (The same results are always printed to the screen, in tabular form.)

