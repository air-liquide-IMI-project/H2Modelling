# install.packages("RSQLite")
library(RSQLite)
setwd("C:/Users/bapti/Downloads")
conn <- dbConnect(RSQLite::SQLite(), "time_series.sqlite")
#
dbListTables(conn)
time_series_60min <- dbGetQuery(conn, "SELECT * FROM  time_series_60min_singleindex")
# summary(time_series_60min)
dbDisconnect(conn)
# install.packages("zoo")
library(zoo)

# head(time_series_60min)
# selected_columns <- time_series_60min[,
#                                 endsWith(colnames(time_series_60min), "capacity")]
# d2 <- cbind(time_series_60min[, 1:2], selected_columns)
# selected_columns_2 <- time_series_60min[, grepl("price_day", names(time_series_60min))]
# column_names <- names(selected_columns_2)
# first_two_letters <- substr(column_names, 1, 2)
# first_two_letters
# countries_with_price <- time_series_60min[, grepl(paste(first_two_letters, collapse = "|"), names(time_series_60min))]


df_test<-time_series_60min
df_test$utc_timestamp <- as.POSIXct(time_series_60min$utc_timestamp, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
filtered_times_series_60_min <- df_test[df_test$utc_timestamp > as.POSIXct("2017-09-30T23:00:00Z"), ]
filtered_times_series_60_min<- filtered_times_series_60_min[, -2]  # Delete the second column
test_time <-read.zoo(filtered_times_series_60_min)
selected_columns_3 <- filtered_times_series_60_min[,
                                      endsWith(colnames(filtered_times_series_60_min), "actual")]
selected_columns_2 <- time_series_60min[, grepl("price_day", names(time_series_60min)) ]

Country_name <- c("FR", "DE", "GB", "DK", "NO", "SE", "IT")
# df_test<-0
# time_series_60min <-0
# test_time<-0

selected_countries <- filtered_times_series_60_min[, grepl(paste(Country_name, collapse = "|"), colnames(filtered_times_series_60_min))]

selected_countries_actual <- selected_countries[, grepl(paste("generation_actual", collapse = "|"), colnames(selected_countries))]

selected_countries_price <- selected_countries[, grepl(paste("price", collapse = "|"), colnames(selected_countries))]

selected_countries_price$DE_LU_price_day_ahead[1:8784] <- time_series_60min$AT_price_day_ahead[24073:32856]



stock_selected_column_actual<-selected_countries_actual$DE_solar_generation_actual

new_col1 <- selected_countries_actual$DE_wind_generation_actual 
new_col2 <- selected_countries_actual$DK_solar_generation_actual 

df_new <- cbind(DE_solar_generation_actual = selected_countries_actual$DE_solar_generation_actual, DE_wind_generation_actual  = new_col1, DK_solar_generation_actual  = new_col2)

df_new<-cbind(df_new ,DK_wind_generation_actual = selected_countries_actual$DK_wind_generation_actual )
df_new<-cbind(df_new ,FR_solar_generation_actual = selected_countries_actual$FR_solar_generation_actual )
df_new<-cbind(df_new ,FR_wind_generation_actual = selected_countries_actual$FR_wind_onshore_generation_actual )
df_new<-cbind(df_new ,GB_GBN_solar_generation_actual = selected_countries_actual$GB_GBN_solar_generation_actual )
df_new<-cbind(df_new ,GB_GBN_wind_generation_actual = selected_countries_actual$GB_GBN_wind_generation_actual )
df_new<-cbind(df_new ,IT_solar_generation_actual = selected_countries_actual$IT_solar_generation_actual )
df_new<-cbind(df_new ,IT_wind_generation_actual = selected_countries_actual$IT_wind_onshore_generation_actual )
df_new<-cbind(df_new ,NO_wind_generation_actual = selected_countries_actual$NO_wind_onshore_generation_actual )
df_new<-cbind(df_new ,SE_wind_generation_actual = selected_countries_actual$SE_wind_onshore_generation_actual )


df_new_price <- cbind(DE_price_day_ahead = selected_countries_price$DE_LU_price_day_ahead, DK_price_day_ahead = selected_countries_price$DK_1_price_day_ahead)
df_new_price <- cbind(df_new_price, FR_price_day_ahead = selected_countries_price$IT_NORD_price_day_ahead)
df_new_price <- cbind(df_new_price, GB_GBN_price_day_ahead = selected_countries_price$GB_GBN_price_day_ahead)
df_new_price <- cbind(df_new_price, IT_price_day_ahead = selected_countries_price$IT_NORD_price_day_ahead)
df_new_price <- cbind(df_new_price, NO_price_day_ahead = selected_countries_price$NO_1_price_day_ahead)
df_new_price <- cbind(df_new_price, SE_price_day_ahead = selected_countries_price$SE_1_price_day_ahead)

ff_actual <-head(df_new, -1)
df <- head(df_new_price, -1) #allows to delete the last row

mix_df_actual_price <- cbind( ff_actual,df)
# mix_df_actual_price$utc_timestamp<-filtered_times_series_60_min$utc_timestamp[1:26328]

filtered_times_series_60_min$utc_timestamp[1:26328]
plot(test_time[,1:2], main = "My Time Series", xlab = "Time", ylab = "Values")


selected_countries <-0
selected_columns_3 <-0
ghy <-0
time_series_60min <- 0
df_test <-0
df<-0
filtered_times_series_60_min <-0
df_new<- 0
ff_actual <- 0
data.female <- 0
mix_df_actual_price <-0
df_new_price <- 0
HJU <- 0
test_time <-0
mix_df_actual_price <- 0

vect_date <- filtered_times_series_60_min$utc_timestamp[1:26328]
time_df <- data.frame(timestamp = vect_date)
Mix_date_generation_price<-cbind(utc_timestamp = time_df, mix_df_actual_price)
df_no_na <- Mix_date_generation_price[complete.cases(Mix_date_generation_price), ]

# indices_na <- which(is.na(Mix_date_generation_price), arr.ind=TRUE)[,1]
# indices_na
for (col in colnames(Mix_date_generation_price)) {
  Mix_date_generation_price[, col] <- replace(Mix_date_generation_price[, col], is.na(Mix_date_generation_price[, col]), mean(Mix_date_generation_price[, col], na.rm = TRUE))
}


Mix_date_generation_price$timestamp <- as.POSIXct(Mix_date_generation_price$timestamp, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
time_series_zoo_mix <-test_time <-read.zoo(Mix_date_generation_price)
index(time_series_zoo_mix)
# plot(time_series_zoo_mix, col = rainbow(ncol(time_series_zoo_mix)))
plot(time_series_zoo_mix)





