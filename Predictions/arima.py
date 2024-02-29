import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf

# The data that we want to analyse
column_name = 'DE_wind_generation_actual'

# Générer un exemple de série temporelle aléatoire (remplacez cette partie par le chargement de votre propre série temporelle)
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
solar_generation = whole_data[column_name]
solar_generation = solar_generation.interpolate(method='linear')

# Tracer la série temporelle
plt.figure(figsize=(12, 6))
plt.plot(solar_generation.index, solar_generation, color='blue')
plt.title('Production d\'énergie solaire')
plt.xlabel('Date')
plt.ylabel('Production solaire')
plt.grid(True)
plt.show()


# Analyse de la série temporelle
# Tracer la fonction d'autocorrélation (ACF) et la fonction d'autocorrélation partielle (PACF)
# plot_acf(solar_generation, lags=100)
# plt.title('Autocorrelation Function (ACF)')
# plt.show()

# plot_pacf(solar_generation, lags=100)
# plt.title('Partial Autocorrelation Function (PACF)')
# plt.show()

# Déterminer les ordres (p, d, q) pour ARIMA
# Choisissez les ordres en fonction des graphiques ACF et PACF ainsi que des tests statistiques
p = 1  # Ordre de la partie autorégressive
d = 1  # Ordre de la différenciation
q = 1  # Ordre de la moyenne mobile

# Créer et ajuster le modèle ARIMA
model = ARIMA(solar_generation, order=(p, d, q))
arima_results = model.fit()

# Résumé des résultats du modèle
print(arima_results.summary())

start_index = 500
end_index = 600

actual_data = solar_generation.iloc[start_index:end_index]
arima_predictions = arima_results.predict(start=start_index, end=end_index-1)

# Tracer la série temporelle originale et la série temporelle prédite par le modèle ARIMA
plt.figure(figsize=(12, 6))
plt.plot(actual_data.index, actual_data, color='blue', label='Observed')
plt.plot(actual_data.index, arima_predictions, color='red', label='ARIMA Model')
plt.title('Actual Data vs ARIMA Predictions')
plt.xlabel('Date')
plt.ylabel('Production éolienne')
plt.legend()
plt.grid(True)
plt.show()