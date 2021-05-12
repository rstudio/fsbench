# Represents a set of fsbench results, incorporating multiple runs and tasks
FSBenchResults <- R6::R6Class("FSBenchResults",
  private = list(
    results = "data.frame",
    runs = factor(),
    tasks = factor()
  ),
  public = list(
    initialize = function(results, runs) {
      private$results <- results
      private$runs <- runs
      private$tasks <- unique(results$task)
    },
    # Retrieve the results for the specified tasks, and prevents them from
    # being returned from future calls to self$remaining()
    take = function(tasks, run_names = NULL) {
      df <- self$peek(tasks, run_names = run_names)
      private$tasks <- setdiff(private$tasks, tasks)
      df
    },
    # Like self$take(), but doesn't affect self$remaining()
    peek = function(tasks, run_names = NULL) {
      df <- private$results
      df <- df[df$task %in% tasks,]
      if (length(run_names) > 0) {
        df <- df[df$run_name %in% run_names,]
        unseen_run_names <- setdiff(run_names, df$run_name)
        warning(
          "Run name(s) requested but not found: ",
          paste(unseen_run_names, collapse = ", ")
        )
      }
      df
    },
    # Returns tasks that have not yet been returned by take()
    remaining = function() {
      df <- private$results
      df[df$task %in% private$tasks,]
    }
  )
)

fsbench_report_init <- function(params) {
  files_to_read <- lapply(params, Sys.glob)
  bad_glob <- which(vapply(files_to_read, length, integer(1)) == 0)
  if (length(bad_glob) > 0) {
    stop(sprintf("Bad params value '%s': no files found that matched '%s'", names(params)[bad_glob[1]], params[bad_glob[1]]))
  }

  results <- do.call(rbind,
    mapply(read_runs, names(params), files_to_read, SIMPLIFY = FALSE, USE.NAMES = FALSE)
  )
  runs <- unique(names(params))

  FSBenchResults$new(results, runs)
}

fsbench_plot <- function(df, scales = c("fixed", "free"), ncol = length(unique(df$task)), nrow = 1) {
  scales <- match.arg(scales)

  p <- ggplot(df, aes(run_name, elapsed, fill = run_name))

  if (all(df$parallelism == 1)) {
    p <- p + geom_bar(stat = "identity", show.legend = FALSE) +
      xlab("Configuration")

    # If too many runs, turn the x-axis labels 90 degrees so they fit
    if (length(unique(df$run_name)) > 5) {
      p <- p + theme(axis.text.x = element_text(angle = 90))
    }
  } else {
    p <- p + geom_line(aes(x = parallelism, group = run_name, color = run_name)) +
      geom_point(aes(x = parallelism, color = run_name)) +
      xlab("Parallelism") +
      theme(legend.title = element_blank())
  }

  p <- p +
    facet_wrap(~ task, ncol = ncol, nrow = nrow, scales = scales) +
    ylab("Elasped (seconds)") +
    ylim(0, NA)
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
