library(zoo)

library(RSQLite)


setwd("C:/Users/33782/OneDrive/Documents/ProjetIMI")
conn <- dbConnect(RSQLite::SQLite(), "time_series_energy_60min.sqlite3")
#
dbListTables(conn)
time_series_60min <- dbGetQuery(conn, "SELECT * FROM  time_series_60min_singleindex")
# summary(time_series_60min)
dbDisconnect(conn)



DE_solar_profile = time_series_60min$DE_solar_profile
DE_solar_capacity = time_series_60min$DE_solar_capacity

DE_wind_profile = time_series_60min$DE_wind_profile
DE_wind_capacity = time_series_60min$DE_wind_capacity

DE_solar_generation_product <- DE_solar_capacity*DE_solar_profile
DE_wind_generation_product <- DE_wind_capacity*DE_wind_profile

DE_solar_actual_consumption <- time_series_60min$DE_solar_generation_actual
DE_wind_actual_consumption <- time_series_60min$DE_wind_generation_actual

par(mfrow=c(2,2))

relative_error_solar <- abs(DE_solar_generation_product -DE_solar_actual_consumption)/DE_solar_actual_consumption
zeros_index_solar <- which(DE_solar_generation_product -DE_solar_actual_consumption==0)
relative_error_solar[zeros_index_solar] <- relative_error_solar[zeros_index_solar]*0

relative_error_wind <- abs(DE_wind_generation_product -DE_wind_actual_consumption)/DE_wind_actual_consumption
zeros_index_wind <- which(DE_wind_generation_product -DE_wind_actual_consumption==0)
relative_error_wind[zeros_index_wind] <- relative_error_wind[zeros_index_wind]*0


hist(relative_error_solar)
hist(relative_error_wind)

n_one <- which(relative_error==1)
n_two <- which(DE_solar_actual_consumption==0)


hist(abs(DE_solar_generation_product -DE_solar_actual_consumption)/DE_solar_actual_consumption)

DE_averaged_solar_capacity <- mean(DE_solar_capacity,na.rm = TRUE)
DE_averaged_wind_capacity  <- mean(DE_wind_capacity,na.rm = TRUE)



DE_solar_generation_product_fixed <- DE_averaged_solar_capacity*DE_solar_profile
relative_error_fixed_solar <-abs(DE_solar_generation_product_fixed -DE_solar_actual_consumption)/DE_solar_actual_consumption
zeros_index_fixed_solar = which(DE_solar_generation_product_fixed -DE_solar_actual_consumption==0)
relative_error_fixed_solar[zeros_index_fixed_solar] = relative_error_fixed_solar[zeros_index_fixed_solar]*0

DE_wind_generation_product_fixed <- DE_averaged_wind_capacity*DE_wind_profile
relative_error_fixed_wind <-abs(DE_wind_generation_product_fixed -DE_wind_actual_consumption)/DE_wind_actual_consumption
zeros_index_fixed_wind = which(DE_wind_generation_product_fixed -DE_wind_actual_consumption==0)
relative_error_fixed_wind[zeros_index_fixed_wind] = relative_error_fixed_wind[zeros_index_fixed_wind]*0

hist(relative_error_fixed_solar)
hist(relative_error_fixed_wind)


plot(DE_solar_capacity)
plot(DE_wind_capacity)
plot(DE_solar_profile)
plot(DE_wind_profile)




mean_solar_capacity = mean(DE_solar_capacity,na.rm = TRUE)
mean_wind_capacity = mean(DE_wind_capacity,na.rm = TRUE)

DE_solar_generation_product = mean_solar_capacity*DE_solar_profile
DE_wind_generation_product = mean_wind_capacity*DE_wind_profile

plot(DE_solar_generation_product)
plot(DE_wind_generation_product)


df_test<-time_series_60min
df_test$utc_timestamp <- as.POSIXct(time_series_60min$utc_timestamp, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
df_test$week_index <- format(df_test$utc_timestamp, "%U")


test_time <-read.zoo(df_test)

test_time$week_index <- as.numeric(test_time$week_index)


plot(test_time$week_index,type = "o", ylim = c(0,57), main="Week index distribution over time")



#Here we do the transformation of the price column of Germany


na_indices_DE_Price <- which(is.na(df$DE_LU_price_day_ahead[1:43800]))
test_time$DE_LU_price_day_ahead[na_indices_DE_Price]<- test_time$AT_price_day_ahead[na_indices_DE_Price]

DE_price_mix <- df$DE_LU_price_day_ahead
DE_price_mix[na_indices_DE_Price]<- df$AT_price_day_ahead[na_indices_DE_Price]
#Now to know which week present missing values:

na_indices_DE_Price_after_mix <- which(is.na(test_time$DE_LU_price_day_ahead))
na_indices_DE_solar_profile <- which(is.na(test_time$DE_solar_profile))
na_indices_DE_wind_profile <- which(is.na(test_time$DE_wind_profile))


na_indices_DE
na_indices_DE <- unique(c(na_indices_DE_Price_after_mix, na_indices_DE_solar_profile, na_indices_DE_wind_profile))

plot(na_indices_DE, main="index of raws with missing values")
lines(na_indices_DE_Price_after_mix, col ="blue")
lines(na_indices_DE_solar_profile, col ="green")
lines(na_indices_DE_wind_profile, col ="red")
legend(x = "right", legend = c("DE_price", "DE_solar_profile","DE_wind_profile" ), lty = c(1, 1,1), col = c("blue", "green", "red"), lwd = 2)



test_time <- test_time[1:43800]

na_indices_DE_Price_after_mix_2 <- which(is.na(test_time$DE_LU_price_day_ahead))
na_indices_DE_solar_profile_2 <- which(is.na(test_time$DE_solar_profile))
na_indices_DE_wind_profile_2 <- which(is.na(test_time$DE_wind_profile))

na_indices_DE_2 <- unique(c(na_indices_DE_Price_after_mix_2, na_indices_DE_solar_profile_2, na_indices_DE_wind_profile_2))


solar_test <- match(na_indices_DE_solar_profile_2, na_indices_DE_2)
wind_test <- match(na_indices_DE_wind_profile_2, na_indices_DE_2)

plot(na_indices_DE_2, main="index of raws with missing values restricted period")
lines(na_indices_DE_Price_after_mix_2, col ="blue")
lines(x= solar_test, y = na_indices_DE_solar_profile_2, col ="green",lwd = 2)
lines(x = wind_test, y = na_indices_DE_wind_profile_2, col ="red")
legend(x = "topright", legend = c("DE_price", "DE_solar_profile","DE_wind_profile" ), lty = c(1, 1,1), col = c("blue", "green", "red"), lwd = 2)

test_time$DE_LU_price_day_ahead

test_week <-unique(test_time$week_index[na_indices_DE_2])
test_week <-sort(as.numeric(test_week))

band_colors <- c("red", "green", "orange", "purple", "cyan", "yellow")
band_colors <-c(band_colors,band_colors)

plot(test_week,type="o", col="blue", xlab="Index", ylab="week index", main="Space between weeks without NA")

x<- seq(1:5000)

for (i in 1:(length(na_indices_DE_2)-1)) {
  rect(min(x), test_week[i], max(x), test_week[i+1], col=band_colors[i], border=NA, alpha=0.2)
}

axis(2, at=test_week, labels=test_week)


testtest <-diff(test_week)
testtest <- testtest-1
tegt <- sort(testtest)
plot(tegt)
axis(2, at=tegt, labels=tegt)
tegt




#Interpolation of the missing values



df_test$MonthDayHour <- format(df_test$utc_timestamp, format = "%m-%dT%H:%M:%S", tz = "UTC")

date_solar_profile_NA <- df_test$MonthDayHour[na_indices_DE_solar_profile_2]
DE_solar_profile <- df$DE_solar_profile[1:43800]
for (i in 1:length(date_solar_profile_NA)){
  date <- date_solar_profile_NA[i]
  index_date <- which(df_test$MonthDayHour == date)
  solar_value <- DE_solar_profile[index_date]
  test_time$DE_solar_profile[na_indices_DE_solar_profile_2[i]] <- mean(solar_value,na.rm = TRUE)
}

date_wind_profile_NA <- df_test$MonthDayHour[na_indices_DE_wind_profile_2]
DE_wind_profile <- df$DE_wind_profile[1:43800]
for (i in 1:length(date_wind_profile_NA)){
  date <- date_wind_profile_NA[i]
  index_date <- which(df_test$MonthDayHour == date)
  wind_value <- DE_wind_profile[index_date]
  test_time$DE_wind_profile[na_indices_DE_wind_profile_2[i]] <- mean(wind_value,na.rm = TRUE)
}
  
date_price_NA <- df_test$MonthDayHour[na_indices_DE_Price_after_mix_2]
DE_price <- DE_price #see above
for (i in 1:length(date_price_NA)){
  date <- date_price_NA[i]
  index_date <- which(df_test$MonthDayHour == date)
  price_value <- DE_price[index_date]
  test_time$DE_LU_price_day_ahead[na_indices_DE_Price_after_mix_2[i]] <- mean(price_value,na.rm = TRUE)
}

which(is.na(test_time$DE_LU_price_day_ahead))
which(is.na(test_time$DE_wind_profile))
which(is.na(test_time$DE_solar_profile))


DE_price <- as.numeric(as.data.frame(test_time$DE_LU_price_day_ahead)$"test_time$DE_LU_price_day_ahead")
DE_wind_profile <- as.numeric(as.data.frame(test_time$DE_wind_profile)$"test_time$DE_wind_profile")
DE_solar_profile <- as.numeric(as.data.frame(test_time$DE_solar_profile)$"test_time$DE_solar_profile")
DE_week_index <- as.numeric(df$week_index[1:43800])
DE_price_with_NA <- as.numeric(DE_price_mix[1:43800])
DE_wind_profile_with_NA <- as.numeric(df$DE_wind_profile[1:43800])
DE_solar_profile_with_NA <- as.numeric(df$DE_solar_profile[1:43800])


DE_data <- cbind(utc_timestamp = time_series_60min$utc_timestamp[1:43800], DE_week_index = DE_week_index, DE_price = DE_price, DE_solar_profile = DE_solar_profile, DE_wind_profile =DE_wind_profile, DE_price_with_NA =DE_price_with_NA, DE_solar_profile_with_NA = DE_solar_profile_with_NA, DE_wind_profile_with_NA = DE_wind_profile_with_NA)

con <- dbConnect(RSQLite::SQLite(), dbname = "DE_data.sqlite")

DE_data <- as.data.frame(DE_data)

# Write the dataframe to the database
dbWriteTable(con, "DE_data", DE_data)

# Close the connection
dbDisconnect(con)


