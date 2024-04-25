import pandas as pd
import numpy as np
import scipy.stats as stats
import matplotlib.pyplot as plt

# The data that we want to analyse
column_name = 'DE_wind_generation_actual'

# Load the data
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
wind_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
wind_generation = wind_generation.replace([np.inf, -np.inf], np.nan).dropna()

# Réorganiser les données en un tableau 2D où chaque ligne représente une semaine de données (7 jours)
donnees_2d = np.array(wind_generation).reshape(-1, 4*7 * 24)  

# Calculer la moyenne le long de l'axe des colonnes (axis=1)
moyenne_par_semaine = np.mean(donnees_2d, axis=1)

# Tracé des tirages successifs
plt.figure(figsize=(10, 6))
plt.plot(list(range(len(moyenne_par_semaine))), moyenne_par_semaine)

plt.title('Moyenne mensuelle des valeurs de DE_wind_generation_actual')
plt.xlabel('Numéro de mois')
plt.ylabel('Moyenne de la production d\'énergie')
plt.legend()
plt.grid(True)
plt.show()