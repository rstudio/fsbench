library(ggplot2)
library(stringr)

save_plot <- function(plot, filename) {
  ggsave(filename, plot=plot)
  cat("Plot saved to ", filename)
}

# Compare multiple benchmark runs, generating graphs for each unique filesystem
# Multiple runs for the same filesystem are averaged together

#args = commandArgs(trailingOnly = TRUE)
args = c("ssd=*ssd.csv", "efs=*efs.csv")

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
  aggregate_data_frame <- data.frame(matrix(ncol = 5))
  colnames(aggregate_data_frame) <- c("task", "user", "system", "elapsed", "parallelism")
  for (file in files) {
    data_frame <- read.csv(file)
    aggregate_data_frame <- merge(data_frame, aggregate_data_frame, all.x = TRUE, by.x = c("task", "parallelism"), by.y = c("task", "parallelism"))
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
final_data_frame <- final_data_frame[,c("task", "parallelism", "average")]
colnames(final_data_frame)[3] <- sprintf("%s", attributes(results)[[1]][1])

if (num_fs > 1) {
  for (i in 2:num_fs) {
    filesystem_name <- attributes(results)[[1]][i]

    df <- results[[filesystem_name]]
    sub_df <- df[,c("task", "parallelism", "average")]
    colnames(sub_df)[3] <- sprintf("%s", filesystem_name)

    final_data_frame <- merge(final_data_frame, sub_df, all.x = TRUE, by.x = c("task", "parallelism"), by.y = c("task", "parallelism"))
  }
}

observations <- c()
groupings <- c()
parallelisms <- c()
filesystems <- c()
for (i in 3:ncol(final_data_frame)) {
  groupings <- append(groupings, final_data_frame[[1]])
  parallelisms <- append(parallelisms, final_data_frame[[2]])
  observations <- append(observations, final_data_frame[[i]])
  filesystems <- append(filesystems, rep(colnames(final_data_frame)[i], nrow(final_data_frame)))
}

final_data_frame <- data.frame(observation = observations,
                               grouping = groupings,
                               filesystem = filesystems,
                               parallelism = parallelisms)

# break the data frame into two for separate plots - one for synchronous tests and one for parallel
sync_data_frame <- subset(final_data_frame, parallelism %in% c(NA))
parallel_data_frame <- final_data_frame[!(final_data_frame$observation %in% sync_data_frame$observation),]

sync_plot <- ggplot(data=sync_data_frame, aes(filesystem, observation, fill=filesystem)) +
  geom_bar(stat="identity") +
  labs(x="", y="Seconds") +
  theme(strip.text.x = element_text(size = 7)) +
  facet_wrap(grouping ~ ., scales="free")

parallel_plot <- ggplot(data=parallel_data_frame, aes(as.factor(parallelism), observation, fill=filesystem)) +
  geom_bar(stat="identity", position=position_dodge()) +
  labs(x="Concurrency", y="Seconds") +
  theme(strip.text.x = element_text(size = 7)) +
  facet_wrap(grouping ~ ., scales="free")

save_plot(sync_plot, "synchronous-plot-results.png")
save_plot(parallel_plot, "parallel-plot-results.png")
