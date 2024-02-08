x <- 6
install.packages("RSQLite")
library(RSQLite)
setwd("C:/Users/bapti/Downloads")
conn <- dbConnect(RSQLite::SQLite(), "time_series.sqlite")

dbListTables(conn)
gamma_data <- dbGetQuery(conn, "SELECT * FROM time_series_60min_singleindex")
