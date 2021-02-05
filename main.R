source("_functions.R")

times <- list()

times$"Install BH" <- time_install("BH")

times$"base::write.csv, 1GB" <- local({
  fct <- 29.1268
  df <- data.frame(x1 = runif(1e6 * fct), x2 = runif(1e6 * fct))
  message("Data generated")
  system.time({
    write.csv(df, file = "1gb.csv", row.names = FALSE)
  })
})

times$"base::read.csv, 1GB" <- local({
  system.time({
    read.csv("1gb.csv")
  })
})

unlink("1gb.csv")

print(times)
