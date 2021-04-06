library(ggplot2)
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
colnames(final_data_frame)[2] <- sprintf("%s", attributes(results)[[1]][1])

if (num_fs > 1) {
  for (i in 2:num_fs) {
    filesystem_name <- attributes(results)[[1]][i]

    df <- results[[filesystem_name]]
    sub_df <- df[,c("task", "average")]
    colnames(sub_df)[2] <- sprintf("%s", filesystem_name)

    final_data_frame <- merge(final_data_frame, sub_df, all.x = TRUE, by.x = "task", by.y = "task")
  }
}

observations <- c()
groupings <- c()
filesystems <- c()
for (i in 2:ncol(final_data_frame)) {
  observations <- append(observations, final_data_frame[[i]])
  groupings <- append(groupings, final_data_frame[[1]])
  groupings <- sapply(groupings, function(val) {
    # make the titles shorter width wise by inserting newlines every X characters
    val <- paste(strwrap(val, width = 30), collapse="\n")
  })
  filesystems <- append(filesystems, rep(colnames(final_data_frame)[i], nrow(final_data_frame)))
}

final_data_frame <- data.frame(observation = observations,
                               grouping = groupings,
                               filesystem = filesystems)

plot <- ggplot(data=final_data_frame, aes(filesystem, observation, fill=filesystem)) +
  geom_bar(stat="identity") +
  labs(x="File System", y="Seconds") +
  theme(axis.text.x=element_blank(), strip.text.x = element_text(size = 7)) +
  facet_wrap(grouping ~ ., scales="free")

plot_filename <- Sys.getenv("PLOT_FILE", "")
if (!nzchar(plot_filename)) {
  plot_filename <- "plot-results.png"
  message("No PLOT_FILE env var; writing plot results to ", plot_filename)
}

ggsave(plot_filename, plot=plot)
cat("Plot saved to ", plot_filename)
