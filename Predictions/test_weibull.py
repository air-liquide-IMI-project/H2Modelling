import pandas as pd
import numpy as np
import scipy.stats as stats
import matplotlib.pyplot as plt

# The data that we want to analyse
column_name = 'DE_wind_generation_actual'

# Load the data
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
solar_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
solar_generation = solar_generation.replace([np.inf, -np.inf], np.nan).dropna()

# Tracer la fonction de répartition
sorted_data = np.sort(solar_generation)
cdf = np.arange(1, len(sorted_data) + 1) / len(sorted_data)
plt.figure(figsize=(10, 6))
plt.plot(sorted_data, cdf, marker='.', linestyle='none', color='blue')
plt.title('Fonction de Répartition Empirique')
plt.xlabel('Valeurs de la Série Temporelle')
plt.ylabel('Probabilité Cumulative')
plt.grid(True)
plt.show()

# Define the number of weeks to include in the model
# num_weeks = 1  # You can adjust this as needed

# Split data into training and testing sets
# solar_generation = solar_generation.iloc[:-7*24*num_weeks]

# Transformation logarithmique
solar_generation_log = np.log(solar_generation)

# Ajustement de la distribution de Weibull
shape, loc, scale = stats.weibull_min.fit(solar_generation_log)

# Test de Kolmogorov-Smirnov pour évaluer l'ajustement
ks_statistic, p_value = stats.kstest(solar_generation_log, 'weibull_min', args=(shape, loc, scale))
print("Test de Kolmogorov-Smirnov : Statistique =", ks_statistic, ", p-valeur =", p_value)