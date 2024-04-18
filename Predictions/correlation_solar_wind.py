import pandas as pd
import numpy as np
import scipy.stats as stats
import matplotlib.pyplot as plt

# The data that we want to analyse
column_name1 = 'DE_wind_generation_actual'
column_name2 = 'DE_solar_generation_actual'

# Load the data
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
solar_generation = whole_data[column_name2].interpolate(method='linear')
wind_generation = whole_data[column_name1].interpolate(method='linear')


# Remove infinite values
solar_generation = solar_generation.replace([np.inf, -np.inf], np.nan)
wind_generation = wind_generation.replace([np.inf, -np.inf], np.nan)

df = pd.concat([solar_generation, wind_generation], axis=1, keys=['solar_generation', 'wind_generation'])

# Supprimez les lignes contenant des valeurs NaN dans n'importe quelle série
df_cleaned = df.dropna()

# Séparez à nouveau les séries nettoyées
solar_generation = df_cleaned['solar_generation']
wind_generation = df_cleaned['wind_generation']

# Calculez la matrice de corrélation
correlation_matrix = np.corrcoef(wind_generation, solar_generation)

# L'élément en haut à droite de la matrice de corrélation (corrélation entre x et y) est ce qui vous intéresse
correlation_xy = correlation_matrix[0, 1]

print("Correlation between solar and wind energy production:", correlation_xy)

# Correlation between solar and wind energy production: -0.1749495944282806