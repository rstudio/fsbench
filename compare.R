library(ggplot2)
library(ggpubr)
library(stringr)

# Compare multiple benchmark runs, generating graphs for each unique filesystem
# Multiple runs for the same filesystem are averaged together

args = commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  msg <- "No arguments specified.
Must specify one or more filesystem runs to display in the form <file system name>=<benchmark files glob>
Example: Rscript compare.R ssd=*ssd.csv efs=*efs.csv"
  stop(msg)
}

files_to_read <- list()
for (arg in args) {
  arg_pieces <- str_split(arg, fixed("="), 2)
  if (is.na(arg_pieces[[1]][2])) {
    stop(sprintf("Invalid argument %s specified. Must be of the form <file system name>=<benchmark files glob>", arg))
  }

  filesystem_name <- arg_pieces[[1]][1]
  glob <- arg_pieces[[1]][2]

  files <- Sys.glob(glob)
  if (length(files) == 0) {
    stop(sprintf("No files found for glob argument %s", glob))
  }

  files_to_read[[filesystem_name]] = files
}

results <- list()
for (filesystem_name in attributes(files_to_read)[[1]]) {
  files <- files_to_read[[filesystem_name]]

  # combine each of the runs for this particular filesystem
  aggregate_data_frame <- data.frame(matrix(ncol = 4))
  colnames(aggregate_data_frame) <- c("task", "user", "system", "elapsed")
  for (file in files) {
    data_frame <- read.csv(file)
    aggregate_data_frame <- merge(data_frame, aggregate_data_frame, all.x = TRUE, by.x = "task", by.y = "task")
  }

  # average each of the elapsed columns together
  col_names <- c()
  for (column in colnames(aggregate_data_frame)) {
    if (startsWith(column, "elapsed")) {
      col_names <- append(col_names, c(column))
    }
  }

  data_frame_subset <- aggregate_data_frame[, col_names]
  aggregate_data_frame["average"] = rowMeans(data_frame_subset, na.rm = TRUE)

  results[[filesystem_name]] = aggregate_data_frame
}

# combine all filesystem data frames into one final clean data frame
final_data_frame <- data.frame()
num_fs <- length(attributes(results)[[1]])
final_data_frame <- results[[1]]
final_data_frame <- final_data_frame[,c("task", "average")]
colnames(final_data_frame)[2] <- sprintf("average_%s", attributes(results)[[1]][1])

if (num_fs > 1) {
  for (i in 2:num_fs) {
    filesystem_name <- attributes(results)[[1]][i]

    df <- results[[filesystem_name]]
    sub_df <- df[,c("task", "average")]
    colnames(sub_df)[2] <- sprintf("average_%s", filesystem_name)

    final_data_frame <- merge(final_data_frame, sub_df, all.x = TRUE, by.x = "task", by.y = "task")
  }
}

# plot the data row by row, one plot per row in the data frame
plots <- list()
for (i in 1:nrow(final_data_frame)) {
  row <- final_data_frame[i, ]
  task <- row[[1]]

  # constrain the width of the title by inserting line breaks
  task <- paste(strwrap(task, width = 30), collapse="\n")

  x_vals <- c()
  y_vals <- c()
  for (j in 2:ncol(row)) {
    fs <- str_split(colnames(row)[j], fixed("_"), 2)[[1]][2]
    x_vals <- append(x_vals, fs)
    y_vals <- append(y_vals, row[[j]])
  }

  plot_data <- data.frame(x_vals, y_vals)
  plot <- ggplot(data=plot_data, aes(x=x_vals, y=y_vals, fill=x_vals)) +
          geom_bar(stat="identity") +
          labs(title=task, x="File System", y="Seconds") +
          theme(plot.title=element_text(size=7, face="bold"))

  plots[[i]] = plot
}

final_plot <- ggarrange(plotlist=plots, ncol=3, nrow=ceiling(length(plots)/3))
ggsave("plot-results.png", plot=final_plot)

cat("Plot saved to plot-results.png")
