library(ggplot2)

# Compare multiple benchmark runs, generating graphs for each unique filesystem
# Multiple runs for the same filesystem are averaged together

save_plot <- function(plot, filename) {
  ggsave(filename, plot=plot)
  cat("Plot saved to ", filename)
}

args = commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  msg <- "No arguments specified.
Must specify one or more filesystem runs to display in the form <file system name>=<benchmark files glob>
Example: Rscript compare.R ssd=*ssd.csv efs=*efs.csv"
  stop(msg)
}

parsed_args <- regmatches(args, regexec("^(.+?)=(.+)$", args))
bad_args <- which(vapply(parsed_args, length, integer(1)) == 0)
if (length(bad_args) > 0) {
  stop(sprintf("Invalid argument '%s' specified. Must be of the form <file system name>=<benchmark files glob>", args[[bad_args[1]]]))
}

arg_matrix <- do.call(rbind, parsed_args)
files_to_read <- setNames(lapply(arg_matrix[,3], Sys.glob), arg_matrix[,2])
bad_glob <- which(vapply(files_to_read, length, integer(1)) == 0)
if (length(bad_glob) > 0) {
  stop(sprintf("No files found for glob argument '%s'", files_to_read[[bad_glob[1]]]))
}

final_data_frame <- do.call(rbind, mapply(names(files_to_read), files_to_read, FUN = function(fs, files) {
  # Read each file into a separate data frame, using read.csv(stringsAsFactors=FALSE)
  data_frames <- lapply(files, read.csv, stringsAsFactors = FALSE)
  # Combine all data frames into a single data frame
  data_frame_all <- do.call(rbind, data_frames)
  # Fix-up NAs for parallelism - set them to 1 as parallel tests never have a parallelization factor of 1
  # This makes sure that all of the aggregation functions work correctly
  data_frame_all$parallelism <- sapply(data_frame_all$parallelism, function(val){if (is.na(val)){ val <- 1};val})
  # This factor() call is necessary to prevent aggregate() from reordering
  # by task, alphabetically
  data_frame_all$task <- factor(data_frame_all$task, unique(data_frame_all$task))
  # Break data frame into groups of rows based on `task` and `parallelism`, then calculate
  # mean(elapsed), and return the result as a data frame
  data_frame_mean <- aggregate(elapsed ~ task+parallelism, data_frame_all, mean)
  # Return the data in the shape that we ultimately want
  data.frame(
    filesystem = fs,
    grouping = data_frame_mean$task,
    observation = data_frame_mean$elapsed,
    parallelism = data_frame_mean$parallelism
  )
}, SIMPLIFY = FALSE, USE.NAMES = FALSE))

# Rewrap group; this results in a list, each element of which is a character
# vector of length >= 1
final_data_frame$grouping <- lapply(final_data_frame$grouping, strwrap, width = 30)
# Join each character vector's elements, using \n
final_data_frame$grouping <- vapply(final_data_frame$grouping, paste, character(1), collapse = "\n")
# Again, need to use factor() to prevent ggplot2 from reordering
final_data_frame$grouping <- factor(final_data_frame$grouping, unique(final_data_frame$grouping))

# break the data frame into two for separate plots - one for serial tests and one for parallel
sync_data_frame <- subset(final_data_frame, parallelism %in% c(1))
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

save_plot(sync_plot, "serial-plot-results.png")
save_plot(parallel_plot, "parallel-plot-results.png")
