import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.statespace.sarimax import SARIMAX

# The data that we want to analyse
column_name = 'DE_solar_generation_actual'

# Load the data
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
solar_generation = whole_data[column_name].interpolate(method='linear')

# Define the number of weeks to include in the model
num_weeks = 1  # You can adjust this as needed

# Split data into training and testing sets
train_data = solar_generation.iloc[:-7*24*num_weeks]  # Train on all but last num_weeks
test_data = solar_generation.iloc[-7*24*num_weeks:]   # Test on last num_weeks

# # Fit the ARIMA model
# p = 1  # AR order
# d = 1  # Differencing order
# q = 1  # MA order
# order = (p, d, q)  # ARIMA order
# seasonal_order = (p, d, q, 24*365)  # SARIMA seasonal order for daily seasonality
# # model = ARIMA(train_data, order=order, freq='h')
# model = SARIMAX(solar_generation, order=order, seasonal_order=seasonal_order)
# arima_results = model.fit()

# print(arima_results.summary())

# # Forecast for the next weeks
# forecast_horizon = 7*24*num_weeks  # 7 days * 24 hours per day
# arima_forecast = arima_results.forecast(steps=forecast_horizon)

# Plotting
plt.figure(figsize=(12, 6))
plt.plot(test_data.index, test_data, color='blue', label='Observed')
# plt.plot(test_data.index, arima_forecast, color='red', label='ARIMA Forecast')
plt.title('Example of a weekly solar energy profile')
plt.xlabel('Date')
plt.ylabel('Solar generation')
plt.legend()
plt.grid(True)
plt.show()
