fsbench_results <- NULL
fsbench_runs <- character(0)
fsbench_tasks <- character(0)

fsbench_report_init <- function(params) {
  files_to_read <- lapply(params, Sys.glob)
  bad_glob <- which(vapply(files_to_read, length, integer(1)) == 0)
  if (length(bad_glob) > 0) {
    stop(sprintf("Bad params value '%s': no files found that matched '%s'", names(params)[bad_glob[1]], params[bad_glob[1]]))
  }

  fsbench_results <<- do.call(rbind,
    mapply(read_runs, names(params), files_to_read, SIMPLIFY = FALSE, USE.NAMES = FALSE)
  )
  fsbench_runs <<- unique(names(params))
  fsbench_tasks <<- unique(fsbench_results$task)
}

fsbench_take_results <- function(tasks) {
  matches <- fsbench_results$task %in% tasks
  fsbench_tasks <<- setdiff(fsbench_tasks, tasks)
  df <- fsbench_results[matches,]
  df
}

fsbench_plot <- function(df, scales = c("fixed", "free")) {
  scales <- match.arg(scales)

  p <- ggplot(df, aes(run_name, elapsed, fill = run_name))

  if (all(df$parallelism == 1)) {
    p <- p + geom_bar(stat = "identity", show.legend = FALSE) +
      xlab("Configuration")
  } else {
    p <- p + geom_line(aes(x = parallelism, group = run_name, color = run_name)) +
      geom_point(aes(x = parallelism, color = run_name)) +
      xlab("Parallelism")
  }

  p <- p +
    facet_wrap(~ task, ncol = length(unique(df$task)), scales = scales) +
    ylab("Elasped (seconds)")
  p
}

fsbench_table <- function(df) {
  df <- df[order(df$task, df$run_name), c("task", "run_name", "elapsed", "parallelism")]
  if (all(df$parallelism == 1)) {
    df$parallelism <- NULL
    df <- tidyr::pivot_wider(df, id_cols = task, names_from = run_name, values_from = elapsed)
  } else {
    df <- tidyr::pivot_wider(df, id_cols = c(task, parallelism), names_from = run_name, values_from = elapsed)
  }
  knitr::kable(df, row.names = FALSE)
}

read_runs <- function(run_name, files) {
  # Read each file into a separate data frame, using read.csv(stringsAsFactors=FALSE)
  data_frames <- lapply(files, read.csv, stringsAsFactors = FALSE)
  # Combine all data frames into a single data frame
  data_frame_all <- do.call(rbind, data_frames)
  # Fix-up NAs for parallelism - set them to 1 as parallel tests never have a parallelization factor of 1
  # This makes sure that all of the aggregation functions work correctly
  data_frame_all$parallelism <- ifelse(is.na(data_frame_all$parallelism), 1, data_frame_all$parallelism)
  # This factor() call is necessary to prevent aggregate() from reordering
  # by task, alphabetically
  data_frame_all$task <- factor(data_frame_all$task, unique(data_frame_all$task))
  # Break data frame into groups of rows based on `task` and `parallelism`, then calculate
  # mean(elapsed), and return the result as a data frame
  data_frame_mean <- aggregate(elapsed ~ task+parallelism, data_frame_all, mean)
  # Return the data in the shape that we ultimately want
  data.frame(
    run_name = factor(run_name, levels = unique(run_name)),
    task = factor(data_frame_mean$task, levels = unique(data_frame_mean$task)),
    elapsed = data_frame_mean$elapsed,
    parallelism = data_frame_mean$parallelism
  )
}
