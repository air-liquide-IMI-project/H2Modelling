#install.packages("RSQLite")
library(RSQLite)
setwd("C:/Users/33782/OneDrive/Documents/ProjetIMI")
conn <- dbConnect(RSQLite::SQLite(), "time_series_energy_60min.sqlite3")
#
dbListTables(conn)
time_series_60min <- dbGetQuery(conn, "SELECT * FROM  time_series_60min_singleindex")
# summary(time_series_60min)
dbDisconnect(conn)
# install.packages("zoo")
library(zoo)
#install.packages("pracma")
library(pracma)
#install.packages("ggplot2")
library(ggplot2)
#install.packages("reshape2")
#install.packages("tseries")
#install.packages("forecast")
#install.packages("pastecs")
#install.packages("spgs")
library(spgs)
library(pastecs)
library(reshape2)
library(stats)
library(tseries)
library(forecast)
# head(time_series_60min)
selected_columns <- time_series_60min[,
                                endsWith(colnames(time_series_60min), "capacity") | endsWith(colnames(time_series_60min), "profile") ]
# d2 <- cbind(time_series_60min[, 1:2], selected_columns)
# selected_columns_2 <- time_series_60min[, grepl("price_day", names(time_series_60min))]
# column_names <- names(selected_columns_2)
# first_two_letters <- substr(column_names, 1, 2)
# first_two_letters
# countries_with_price <- time_series_60min[, grepl(paste(first_two_letters, collapse = "|"), names(time_series_60min))]


testtest <- 7

df_test<-time_series_60min
df_test$utc_timestamp <- as.POSIXct(time_series_60min$utc_timestamp, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
filtered_times_series_60_min <- df_test[df_test$utc_timestamp > as.POSIXct("2017-09-30T23:00:00Z"), ]
filtered_times_series_60_min<- filtered_times_series_60_min[, -2]  # Delete the second column
test_time <-read.zoo(filtered_times_series_60_min)
selected_columns_3 <- filtered_times_series_60_min[,
                                                   endsWith(colnames(filtered_times_series_60_min), "actual")]
selected_columns_2 <- time_series_60min[, grepl("price_day", names(time_series_60min)) ]

Country_name <- c("FR", "DE", "GB", "DK", "NO", "SE", "IT")


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
# time_series_zoo_reg <- zooreg(Mix_date_generation_price, frequency = 24)
time_series_zoo_reg<- 0
plot(time_series_zoo_mix[,1])
plot(time_series_zoo_reg[,13:19], main = "price_day_ahead", xlab = "time period", ylab = "in €")
time_series_zoo_reg[,2]
my_subset <- window(time_series_zoo_mix, start = as.POSIXct("2017-10-02 07:00:00"), end = as.POSIXct("2018-10-02 07:00:00"))

plot(my_subset[,1:6], main = "DE_DK_FR_renewable_generation_actual", xlab = "time period", ylab = "in MW")

moving_avg <- rollmean(my_subset[,1], k = 24, fill = NA)

# Plot raw data and moving average
plot(my_subset[,1], main = "DE_solar_generation_actual with moving average", xlab = "time period", ylab = "in MW")
lines(moving_avg, col = "red")

exponential_moving_average <-movavg(my_subset[,2], 24, type = "e")
my_sma <- filter(my_subset[,2], rep(1/24, 24), sides = 2)

# test <-fortify(my_subset[,2])
test_2 <- as.data.frame(exponential_moving_average)
test_3 <- as.data.frame(my_sma)

ggplot() +
  geom_line(data = my_subset, aes(x = index(my_subset), y = my_subset[,2]), color = "blue", size = 1) +
  geom_line(data = test_3, aes(x = index(my_subset), y = my_sma), color = "red", size = 1) +
  labs(x = "Date", y = "DE_wind_generation_actual in MW", title = "Time Series with Symmetric Moving Average (24)") +
  theme_minimal()
s<-2e+07
s-13392
my_acf <- acf(my_subset[,1], lag.max = 24*30*18)
acz <- acf(my_subset[,1],lag.max = 13392, plot = FALSE)
ci <- qnorm((1 + 0.95) / 2) / sqrt(sum(!is.na(my_subset[,1])))
# Convert ACF results to a data frame
acd <- data.frame(lag = acz$lag, acf = acz$acf)

# Create the ACF plot with ggplot and customize the title
ggplot(acd, aes(lag, acf)) +
  geom_area(fill = "grey") +
  geom_hline(yintercept = c(ci, -ci), linetype = "dashed") +
  labs(title = "DE_solar_generation_actual ACF plot") +  # Change the title here
  theme_bw()

pacz <- pacf(my_subset[,1], lag.max = 24*31*18, plot = FALSE)

# Convert PACF results to a data frame
pacd <- data.frame(lag = pacz$lag, pacf = pacz$acf)
ci <- qnorm((1 + 0.95) / 2) / sqrt(sum(!is.na(my_subset[,1])))
# Create the PACF plot with ggplot
ggplot(pacd, aes(lag, pacf)) +
  geom_area(fill = "grey") +
  geom_hline(yintercept = c(ci, -ci), linetype = "dashed") +
  labs(title = "DE_solar_generation_actual PACF plot") +  # Change the title here
  theme_bw()


adf_result <- adf.test(my_subset[,1])
adf_result




# Fit an ARIMA model and automatically determine the optimal differences
DE_solar_generation_actual_2017_2018 <-my_subset[,1]

arima_model <- auto.arima(DE_solar_generation_actual_2017_2018)
arima_model <- auto.arima(my_subset[,1], seasonal = TRUE, frequency = 24)

# Get the optimal differencing order
optimal_differences <- arima_model$arma[2]

cat("Optimal differencing order:", optimal_differences, "\n")
arima_model
plot(arima_model)
summary(arima_model)

# Residual diagnostics
checkresiduals(arima_model)

# Ljung-Box test
Box.test(arima_model$residuals, lag = 20, type = "Ljung-Box")

# Histogram of residuals
hist(arima_model$residuals, main = "Residual Histogram")

# Q-Q plot of residuals
qqnorm(arima_model$residuals)
qqline(arima_model$residuals)

sarima_model <- Arima(DE_solar_generation_actual_2017_2018, order = c(1,1,1), seasonal = list(order = c(1,1,1), period = 24))
summary(sarima_model)
checkresiduals(sarima_model)


# Forecast using ARIMA model
arima_forecast <- forecast(arima_model, h = 24)

# Forecast using SARIMA model
sarima_forecast <- forecast(sarima_model, h = 24)

# Compare accuracy metrics (e.g., MAE, RMSE, MAPE)
accuracy(arima_forecast)
accuracy(sarima_forecast)

plot(arima_model, main = "ARIMA Model")

# Plot SARIMA model
plot(sarima_model, main = "SARIMA Model")




# Assuming 'sub_model' is your time series data
result <- turnpoints(my_subset[,13])

# Print summary or plot the results (optional)
summary(result)
plot(result)

DE_price_ahead_2017_2020<-my_subset[,13]
test_result <- turningpoint.test(DE_price_ahead_2017_2020)
my_subset[,13]
# Print the test result
print(test_result)

adf_result <- adf.test(my_subset[,13])
adf_result

kpss_result <- kpss.test(my_subset[,13], null = "Trend")

# Print the results
print(kpss_result)


arima_model <- auto.arima(DE_price_ahead_2017_2020)
optimal_differences <- arima_model$arma[2]
optimal_differences
plot(arima_model, main = "ARIMA Model")
summary(arima_model)

diff_DE_price_day_ahead <- diff(my_subset[,13])
adf.test(DE_price_ahead_2017_2020)
kpss.test(DE_price_ahead_2017_2020)


test_result <- turningpoint.test(diff_DE_price_day_ahead)
summary(test_result)
print(test_result)

plot(DE_solar_generation_actual_2017_2018)
DE_solar_generation_actual_2017_2018<-my_subset[,1]
adf.test(DE_solar_generation_actual_2017_2018)
kpss.test(DE_solar_generation_actual_2017_2018)

con <- dbConnect(RSQLite::SQLite(), dbname = "Mix_date_generation_price.sqlite")


# Write the dataframe to the database
dbWriteTable(con, "Mix_date_generation_price", Mix_date_generation_price)

# Close the connection
dbDisconnect(con)
